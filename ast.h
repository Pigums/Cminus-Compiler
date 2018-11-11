
#ifndef ASTH
#define ASTH
#include<stdio.h>
#include<malloc.h>

static int debug;

/* define the enumerated types for the AST.  THis is used to tell us what
sort of production rule we came across */

/* this is a partial list of NODE types for the ASTNode */

enum ASTtype {
   PROGRAM,
   VARDEC,
   ARGLIST,
   IDENT,
   BLOCK,
   NUMBER,
   ASSIGN,
   EXPRSTMT,
   FUNCTIONDEC,
   CALLSTMT,
   EXPR,
   IFSTMT,
   ITERSTMT,
   RETURNSTMT,
   READSTMT,
   WRITESTMT,
   PARAM,
   STRINGNODE
};


enum OPERATORS {
   PLUS,
   MINUS,
   TIMES,
   DIVIDE,
   LESSTHANEQUAL,
   LESSTHAN,
   GREATERTHAN,
   GREATERTHANEQUAL,
   EQUAL,
   NOTEQUAL,
   INTDEC,
   VOIDDEC,
   STRINGDEC,
   null
};

/* define a type AST node which will hold pointers to AST structs that will
   allow us to represent the parsed code
*/

typedef struct ASTnodetype
{
     enum ASTtype type;
     enum OPERATORS op;
     enum OPERATORS isType;
     char * name;
     char * str;
     int value;
     struct SymbTab * symbol;
     struct ASTnodetype *left,*right; /* left is usually the connector for statements */
     struct ASTnodetype *s1,*s2 ; /* used for holding IF and WHILE components -- not very descriptive */
} ASTnode;

ASTnode *prog;

//prototypes
ASTnode *ASTCreateNode(enum ASTtype mytype);

void ASTattachleft(ASTnode *p,ASTnode *q);

void ASTprint(int level,ASTnode *p);

#endif /* of ASTH */
