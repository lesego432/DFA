bits 64
global simulateDfa

section .text

; bool simulateDfa(DFA* dfa, const char* input)
simulateDfa:
    ; Null pointers check
    test rdi, rdi
    jz .reject
    test rsi, rsi
    jz .reject

    ; Load DFA struct fields
    mov r8, qword [rdi + 0]     ; r8 = dfa->states pointer
    mov r9, qword [rdi + 8]     ; r9 = dfa->transitions pointer
    mov r10d, dword [rdi + 20]  ; r10d = dfa->numTransitions
    mov eax, dword [rdi + 24]   ; eax = currentState (starts at dfa->startState)

.str_loop:
    movzx ecx, byte [rsi]       ; ecx = current input symbol
    test cl, cl                 ; check for string null terminator '\0'
    jz .check_accepting

    xor edx, edx                ; transition loop index j = 0

.trans_loop:
    cmp edx, r10d
    jge .trans_not_found        ; no transition matching symbol -> reject string

    ; Address of transitions[j] = r9 + (12 * j)
    lea r11, [rdx + rdx*2]       ; r11 = 3 * j
    lea r11, [r9 + r11*4]       ; r11 = r9 + 12 * j

    ; Check if transition.from == currentState
    cmp dword [r11 + 0], eax
    jne .next_trans

    ; Check if transition.symbol == current symbol
    cmp byte [r11 + 8], cl
    jne .next_trans

    ; Valid transition found: update currentState to transition.to
    mov eax, dword [r11 + 4]    ; currentState = transition.to
    inc rsi                     ; advance input string pointer
    jmp .str_loop

.next_trans:
    inc edx
    jmp .trans_loop

.trans_not_found:
    xor eax, eax                ; return false (0)
    ret

.check_accepting:
    mov r10d, dword [rdi + 16]  ; r10d = dfa->numStates
    cmp eax, 0
    jl .reject
    cmp eax, r10d
    jge .reject

    ; Return states[currentState].isAccepting (bool byte at offset 4 of State struct)
    movzx eax, byte [r8 + rax*8 + 4]
    ret

.reject:
    xor eax, eax                ; return false (0)
    ret