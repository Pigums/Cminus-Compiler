#include "ast.h"
#ifndef SYM
#define SYM

int mem=0;
void Display();
int Delete();
static int GTEMP=0;  /* Global Temp counter */

int FetchAddr (char *lab);

struct SymbTab
{
     char *name;
     int offset; /* from activation record boundary */
     int mysize;  /* number of words this item is 1 or more */
     int level;  /* the level where we found the variable */
     enum OPERATORS Type;  /* the type of the symbol */
     int IsAFunc;  /* the element is a function */
     ASTnode * fparms; /* pointer to parameters of the function in the AST */

     struct SymbTab *next;
};


struct SymbTab * Insert(char *name, enum OPERATORS Type, int isafunc, int  level, int mysize, int offset, ASTnode * fparms );

struct SymbTab * Search(char name[], int level, int recur );

static struct SymbTab *first=NULL;   /* global pointers into the symbol table */

void PrintSym(struct SymbTab *s);


#endif
