/* A local harness so you can build and test:
     make
     ./dfa dfa1.txt ababab
   The marker uses its own data and its own harness. */
#include <stdio.h>
#include <stdbool.h>
typedef struct { int id; bool isAccepting; } State;
typedef struct { int from; int to; char symbol; } Transition;
typedef struct { State* states; Transition* transitions;
                 int numStates; int numTransitions; int startState; } DFA;
extern DFA* readDfa(const char* filename);
extern bool simulateDfa(DFA* dfa, const char* input);
int main(int argc, char** argv){
  DFA* d = readDfa(argv[1]);
  if(!d){ printf("could not read %s\n", argv[1]); return 1; }
  printf("states=%d transitions=%d start=%d\n",
         d->numStates, d->numTransitions, d->startState);
  printf("accepts \"%s\": %d\n", argv[2], simulateDfa(d, argv[2]));
  return 0;
}
