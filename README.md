# DFA
This uses file I/O, parsing, dynamic memory, structs, and control flow together
The DFA file format
A DFA is given in a file with this format:
3,6
0,1,2
0
0,1,a
0,1,b
1,2,a
1,2,b
2,0,a
2,0,b
• The first line gives the number of states and the number of transitions, separated
by a comma.
• The second line lists the state IDs, comma separated. The states are numbered 0
to numStates − 1.
• The third line lists the IDs of the accepting states, comma separated.
• Each remaining line is one transition, in the form from,to,symbol.
• The start state is always 0.
The structs
typedef struct { int id; bool isAccepting; } State;
typedef struct { int from; int to; char symbol; } Transition;
typedef struct {
State* states;
1
Transition* transitions;
int numStates;
int numTransitions;
int startState;
} DFA;
