bits 64
global readDfa
extern fopen, fclose, fgets, malloc, free

section .rodata
    mode_r db "r", 0

section .text

; DFA* readDfa(const char* filename)
readDfa:
    push rbp
    mov rbp, rsp
    push r12                ; Preserve r12 (FILE* fp)
    push r13                ; Preserve r13 (DFA* dfa)
    push r14                ; Preserve r14 (transition index loop counter)
    push r15                ; Preserve r15 (temp register for 'from' state)
    push rbx                ; Preserve rbx (1MB Line Buffer pointer)
    sub rsp, 8              ; Maintain 16-byte stack alignment

    test rdi, rdi
    jz .err_null

    ; Open DFA file in read mode
    lea rsi, [rel mode_r]
    call fopen
    test rax, rax
    jz .err_null
    mov r12, rax            ; r12 = fp

    ; Allocate 1MB line buffer to handle long lines cleanly
    mov rdi, 1048576
    call malloc
    test rax, rax
    jz .err_close_file
    mov rbx, rax            ; rbx = line buffer

    ; Allocate DFA struct (32 bytes)
    mov rdi, 32
    call malloc
    test rax, rax
    jz .err_free_buf
    mov r13, rax            ; r13 = dfa pointer

    ; Read Line 1 (numStates, numTransitions)
    mov rdi, rbx
    mov esi, 1048576
    mov rdx, r12
    call fgets
    test rax, rax
    jz .err_free_dfa

    ; Parse numStates and numTransitions from Line 1
    mov rsi, rbx
    
    xor ecx, ecx
.L1_skip_non_digits1:
    movzx eax, byte [rsi]
    test al, al
    jz .err_free_dfa
    cmp al, '0'
    jl .L1_next1
    cmp al, '9'
    jle .L1_parse_num1
.L1_next1:
    inc rsi
    jmp .L1_skip_non_digits1

.L1_parse_num1:
    movzx eax, byte [rsi]
    cmp al, '0'
    jl .L1_done_num1
    cmp al, '9'
    jg .L1_done_num1
    sub al, '0'
    imul ecx, ecx, 10
    add ecx, eax
    inc rsi
    jmp .L1_parse_num1

.L1_done_num1:
    mov dword [r13 + 16], ecx   ; dfa->numStates = numStates

    xor ecx, ecx
.L1_skip_non_digits2:
    movzx eax, byte [rsi]
    test al, al
    jz .err_free_dfa
    cmp al, '0'
    jl .L1_next2
    cmp al, '9'
    jle .L1_parse_num2
.L1_next2:
    inc rsi
    jmp .L1_skip_non_digits2

.L1_parse_num2:
    movzx eax, byte [rsi]
    cmp al, '0'
    jl .L1_done_num2
    cmp al, '9'
    jg .L1_done_num2
    sub al, '0'
    imul ecx, ecx, 10
    add ecx, eax
    inc rsi
    jmp .L1_parse_num2

.L1_done_num2:
    mov dword [r13 + 20], ecx   ; dfa->numTransitions = numTransitions
    mov dword [r13 + 24], 0     ; dfa->startState = 0

    ; Allocate states array (numStates * 8 bytes)
    mov edi, dword [r13 + 16]
    shl rdi, 3                  ; numStates * sizeof(State) [8]
    call malloc
    test rax, rax
    jz .err_free_dfa
    mov qword [r13 + 0], rax    ; dfa->states = states

    ; Initialize states array
    mov r8, rax
    mov ecx, dword [r13 + 16]
    xor edx, edx
.init_states_loop:
    cmp edx, ecx
    jge .init_states_done
    mov dword [r8 + rdx*8], edx     ; state.id = i
    mov byte [r8 + rdx*8 + 4], 0   ; state.isAccepting = false
    inc edx
    jmp .init_states_loop
.init_states_done:

    ; Allocate transitions array (numTransitions * 12 bytes)
    mov eax, dword [r13 + 20]
    test eax, eax
    jz .skip_trans_alloc
    lea edi, [rax + rax*2]      ; 3 * numTransitions
    shl edi, 2                  ; 12 * numTransitions
    call malloc
    test rax, rax
    jz .err_free_states
    mov qword [r13 + 8], rax    ; dfa->transitions = transitions
    jmp .read_remaining_lines
.skip_trans_alloc:
    mov qword [r13 + 8], 0

.read_remaining_lines:
    ; Read Line 2 (state IDs list)
    mov rdi, rbx
    mov esi, 1048576
    mov rdx, r12
    call fgets
    test rax, rax
    jz .err_free_transitions

    ; Read Line 3 (accepting states)
    mov rdi, rbx
    mov esi, 1048576
    mov rdx, r12
    call fgets
    test rax, rax
    jz .err_free_transitions

    ; Parse accepting state IDs
    mov rsi, rbx
    mov r8, qword [r13 + 0]     ; dfa->states
    mov r9d, dword [r13 + 16]   ; numStates

.parse_accepting_loop:
    movzx eax, byte [rsi]
    test al, al
    jz .parse_accepting_done
    cmp al, 10                  ; '\n'
    je .parse_accepting_done
    cmp al, 13                  ; '\r'
    je .parse_accepting_done

    cmp al, '0'
    jl .next_accepting_char
    cmp al, '9'
    jg .next_accepting_char

    xor ecx, ecx
.acc_num_loop:
    movzx eax, byte [rsi]
    cmp al, '0'
    jl .acc_num_done
    cmp al, '9'
    jg .acc_num_done
    sub al, '0'
    imul ecx, ecx, 10
    add ecx, eax
    inc rsi
    jmp .acc_num_loop

.acc_num_done:
    cmp ecx, 0
    jl .parse_accepting_loop
    cmp ecx, r9d
    jge .parse_accepting_loop
    mov byte [r8 + rcx*8 + 4], 1   ; states[ecx].isAccepting = true
    jmp .parse_accepting_loop

.next_accepting_char:
    inc rsi
    jmp .parse_accepting_loop

.parse_accepting_done:

    ; Read transition lines (numTransitions lines)
    xor r14d, r14d
.read_transitions_loop:
    cmp r14d, dword [r13 + 20]
    jge .read_transitions_done

    mov rdi, rbx
    mov esi, 1048576
    mov rdx, r12
    call fgets
    test rax, rax
    jz .err_free_transitions

    mov rsi, rbx

.t_skip_from:
    movzx eax, byte [rsi]
    test al, al
    jz .next_trans_iter
    cmp al, '0'
    jl .t_inc_from
    cmp al, '9'
    jle .t_parse_from
.t_inc_from:
    inc rsi
    jmp .t_skip_from

.t_parse_from:
    xor ecx, ecx
.t_from_loop:
    movzx eax, byte [rsi]
    cmp al, '0'
    jl .t_from_done
    cmp al, '9'
    jg .t_from_done
    sub al, '0'
    imul ecx, ecx, 10
    add ecx, eax
    inc rsi
    jmp .t_from_loop
.t_from_done:
    mov r15d, ecx               ; r15d = from

.t_skip_comma1:
    movzx eax, byte [rsi]
    test al, al
    jz .next_trans_iter
    cmp al, ','
    je .t_found_comma1
    inc rsi
    jmp .t_skip_comma1
.t_found_comma1:
    inc rsi

.t_parse_to:
    xor ecx, ecx
.t_to_loop:
    movzx eax, byte [rsi]
    cmp al, '0'
    jl .t_to_done
    cmp al, '9'
    jg .t_to_done
    sub al, '0'
    imul ecx, ecx, 10
    add ecx, eax
    inc rsi
    jmp .t_to_loop
.t_to_done:                     ; ecx = to

.t_skip_comma2:
    movzx eax, byte [rsi]
    test al, al
    jz .next_trans_iter
    cmp al, ','
    je .t_found_comma2
    inc rsi
    jmp .t_skip_comma2
.t_found_comma2:
    inc rsi

    movzx eax, byte [rsi]       ; al = symbol

    mov r8, qword [r13 + 8]     ; transitions array pointer
    lea r9, [r14 + r14*2]       ; 3 * r14
    shl r9, 2                   ; 12 * r14
    add r9, r8                  ; address of transitions[r14]

    mov dword [r9 + 0], r15d    ; transition.from
    mov dword [r9 + 4], ecx     ; transition.to
    mov byte [r9 + 8], al       ; transition.symbol

.next_trans_iter:
    inc r14d
    jmp .read_transitions_loop

.read_transitions_done:
    ; Close file and free temp buffer
    mov rdi, r12
    call fclose

    mov rdi, rbx
    call free

    mov rax, r13                ; Return dfa pointer
    add rsp, 8
    pop rbx
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbp
    ret

; Clean up memory on failure
.err_free_transitions:
    mov eax, dword [r13 + 20]
    test eax, eax
    jz .err_free_states
    mov rdi, qword [r13 + 8]
    call free
.err_free_states:
    mov rdi, qword [r13 + 0]
    call free
.err_free_dfa:
    mov rdi, r13
    call free
.err_free_buf:
    mov rdi, rbx
    call free
.err_close_file:
    mov rdi, r12
    call fclose
.err_null:
    xor rax, rax                ; Return NULL
    add rsp, 8
    pop rbx
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbp
    ret