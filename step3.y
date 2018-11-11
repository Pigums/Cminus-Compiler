%code requires {
	#include <stdio.h>
	#include <ctype.h>
	#include <stdlib.h>
	#include <string.h>
	#include "symtable.c"
	#include "ast.c"
	
	static int level=0;
	static int offset=0;
	static int goffset=0;
	static int maxoffset=0;
	
	
	extern int yylex();
	extern int yyparse();
	extern char *yytext;
	extern FILE *yyin;
	void yyerror(const char* s);
	extern int yylineno;
}
%start program

%union {
	int value;
	char *string;
	ASTnode * node;
	enum OPERATORS op;
}

%left '|'
%right "then" T_ELSE

%token	T_IF T_ELSE T_INT T_RETURN T_VOID T_WHILE 
		T_GREAT T_GREATEQ T_SMALL T_SMALLEQ T_NOTEQ T_COMPARE 
			
%token <value> T_NUM
%token <string> T_ID
%type <node> declaration-list declaration var-declaration fun-declaration params
%type <node> param-list param compound-stmt local-declarations statement-list statement expression-stmt
%type <node> selection-stmt iteration-stmt return-stmt expression
%type <node> var simple-expression additive-expression term factor
%type <node> call args arg-list
%type <op> relop addop mulop type-specifier

%%

program: 
					declaration-list	{ prog = $1; }	
					;
	
declaration-list: 
					declaration-list declaration { $1->left = $2; $$ = $1; } 	
					| declaration	{ $$ = $1; }					
					;
	
declaration: 
					var-declaration		{ $$ = $1; }			
					| fun-declaration 	{ $$ = $1; }			
					;

var-declaration: 
					type-specifier T_ID';'
					{
						/* Search symbol table for the Identifier
						 * If not found => insert then add the pointer from insertion
						 * into the ASTnode to have reference to the symbol table entry */
						if(Search($2,level,0))
						{
							fprintf(stderr,"\n\tThe name %s exists at level %d ",$2,level);
							fprintf(stderr,"already in the symbol table\n");
							fprintf(stderr,"\tDuplicate can.t be inserted(found in search)");
							yyerror(" ");
							exit(1);
						}

						$$ = ASTCreateNode(VARDEC);
						$$->name=$2;
						// we use the op to determine its type while printing
						$$->op=$1;
						$$->symbol=Insert($2,$1,0,level,1,offset,NULL);
						$$->isType=$1;
						offset += 1;
						if(offset > maxoffset)
							maxoffset = offset;
					}
					| type-specifier T_ID'['T_NUM']' ';'
					{   
						// search for symbol, if we find it => error
						if(Search($2,level,0))
						{
							fprintf(stderr,"\n\tThe name %s exists at level %d ",$2,level);
							fprintf(stderr,"already in the symbol table\n");
							fprintf(stderr,"\tDuplicate can.t be inserted(found in search)");
							yyerror(" ");
							exit(1);
						}

						$$=ASTCreateNode(VARDEC);
						$$->name=$2;
						// we use the op to determine its type while printing
						$$->op=$1;
						// value links to the NUM nod to store the dimension
						$$->value=$4;
						$$->symbol=Insert($2,$1,2,level,$4,offset,NULL);
						$$->isType=$1;
						offset += $4;
						if (offset>maxoffset)
							maxoffset = offset;
					}
					;

type-specifier: 	T_INT		{ $$ = INTDEC; }
					| T_VOID	{ $$ = VOIDDEC; }	
					;

fun-declaration: 
					type-specifier T_ID '('
					{   
						if(Search($2,level,0))
						{
							yyerror($2);
							yyerror("Name already used ");
							exit(1);
						}
						Insert($2,$1,1,level,1,0,NULL);
						goffset=offset;
						offset=2;
						if(offset>maxoffset)
							maxoffset = offset;
					}
					params
					{   
						// need the formal params to compare later
						(Search($2,0,0))->fparms = $5;
					}
					')' compound-stmt
					 {
						$$=ASTCreateNode(FUNCTIONDEC);
						$$->name=$2;
						// we use the op to determine its type while printing
						$$->op=$1;
						// s1 links to the params which can be void 
						// or a paramList 
						$$->s1=$5;
						// right links to the compund statement,
						// called a BLOCK in the enumerated type
						$$->right=$8;
						// get the symbtab entry we made earlier
						$$->symbol=Search($2,0,0);
						// Remove symbols put in, in the function call
						offset -=Delete(1);
						level = 0;
						$$->value=maxoffset;
						$$->symbol->mysize = maxoffset;
						// change the offset back to the global offset
						offset=goffset;
						maxoffset=0;
					}
					;

params: 			param-list
					{   
						//params found
						$$ = $1;
					}	
					| T_VOID
					{   
						// no params
						$$ = NULL;
					}
					;

param-list: 
					param-list',' param 
					{   
						// attach the param to the list
						$1->left=$3;
						$$ = $1;
					}
					| param		{ $$ = $1; }				
					;

param: 
					type-specifier T_ID
					 {   
						if(Search($2,level,0))
						{
						   yyerror($2);
						   yyerror("\tDuplicate can.t be inserted(found in search)");
						   exit(1);
						}
						$$ = ASTCreateNode(PARAM);
						$$->name=$2;
						// we use the op to determine its type while printing
						$$->op=$1;
						// if value is 0 it is not an array, used for printing
						$$->value=0;
						// inherit the type
						$$->isType=$1;
						$$->symbol=Insert($2,$1,0,level+1,1,offset,NULL);
						offset+=1;
						if(offset>maxoffset)
							maxoffset = offset;
					}
					| type-specifier T_ID'['']'
					{
						if(Search($2,level,0))
						{
						   yyerror($2);
						   yyerror("\tDuplicate can.t be inserted(found in search)");
						   exit(1);
						}
						$$ = ASTCreateNode(PARAM);
						$$->name=$2;
						// we use the op to determine its type while printing
						$$->op=$1;
						// there was an array param 
						$$->value=1;
						// inherit the type
						$$->isType=$1;
						// 2 is used for IsAFunc to show its an array ref
						$$->symbol=Insert($2,$1,2,level+1,1,offset,NULL);
						offset+=1;
						if(offset>maxoffset)
							maxoffset = offset;
					}
					;
	
compound-stmt: 
					'{' { level++; } local-declarations statement-list '}'
					{
						$$=ASTCreateNode(BLOCK);
						if($3 == NULL) // don't add declarations if null
							$$->right=$4;
						else {
							$$->right=$3;
						}
						/* delete the old symbols from this block so they can
						   be used in a different block later on */
						offset -=Delete(level);
						level--;
					}
					;

local-declarations: 
					local-declarations var-declaration
					{   
						// check for null, if not attach it
						if($1 != NULL){
							$1->left=$2;
							$$=$1;
						}
						else
							$$=$2;
					}
					|	{ $$ = NULL; }
					;
	
statement-list: 	
					statement-list statement
					{   
						// check for null, if not attch it
						if($1 != NULL) {
							$1->left=$2;
							$$=$1;
						}
						else
							$$=$2;
					}
					| 	{ $$ = NULL; }
					;

statement: 			
					expression-stmt
					{ 
						/* everything here is just the simplification to general stmt
						   to be put into a stmtList above */
						$$ = $1;
					}
					| compound-stmt
					{
						$$ = $1;
					}
					| selection-stmt
					{
						$$ = $1;
					}
					| iteration-stmt
					{
						$$ = $1;
					}
					| return-stmt
					{
						$$ = $1;
					}
					;

expression-stmt: 
					expression ';'
					{
						$$=ASTCreateNode(EXPRSTMT);
						$$->right=$1;
						$$->isType=$1->isType;
					}					
					| ';'	{ $$ = NULL; }
					;
					
selection-stmt:
					T_IF '('expression')' statement	%prec "then"
					{
						$$ = ASTCreateNode(IFSTMT);
						// right is the expression to be evaluated
						$$->right=$3;
						// s1 is link to statment (it can be a block)
						$$->s1=$5;
					}
					| T_IF '('expression')' statement T_ELSE statement
					{
						$$ = ASTCreateNode(IFSTMT);
						// right is the expression to be evaluated
						$$->right=$3;
						// s1 is link to statment (it can be a block)
						$$->s1=$5;
						// s2 holds the link to the else statment (can be a block)
						$$->s2=$7;
					}
					;

iteration-stmt: 
					T_WHILE '('expression')' statement
					{
						$$ = ASTCreateNode(ITERSTMT);
						// right holds expression to be evaluated
						$$->right=$3;
						// s1 holds the stmt to execute, can be block
						$$->s1=$5;
					}					
					;
	
return-stmt: 
					T_RETURN ';'	{ $$ = ASTCreateNode(RETURNSTMT); }							
					| T_RETURN expression';'
					{
						$$ = ASTCreateNode(RETURNSTMT);
						// expression to return
						$$->s2=$2;
					}
					;

expression: 
					var '=' expression
					{
						if (($1->isType != $3->isType) || ($1->isType == VOIDDEC))
						{
							yyerror("Type mismatch or void in Assignment");
							exit(1);
						}
						$$=ASTCreateNode(ASSIGN);
						// hold the link to the var node
						$$->right=$1;
						// hold the link to the expression statement
						$$->s1=$3;
						// inherit the type, already check for equivalence
						// so can just use $1
						$$->isType=$1->isType;
						$$->name=CreateTemp();
						$$->symbol=Insert($$->name,$$->isType,0,level,1,offset,NULL);
						offset+=1;
						if(offset>maxoffset)
							maxoffset = offset;
					}
					| simple-expression 	{ $$ = $1; }
					;
	
var: 
					T_ID
					{
						struct SymbTab * p;
						if ((p=Search($1,level,1)) != NULL)
						{
							$$ = ASTCreateNode(IDENT);
							$$->name=$1;
							$$->symbol=p;
							// give the node op Type, based on SymbTab
							$$->isType=p->Type;
							if (p->IsAFunc == 2)
							{
								yyerror($1);
								yyerror("Variable is an array, syntax error");
							}
						}
						else
						{
							yyerror($1);
							yyerror("undeclared variable used");
							exit(1);
						}
					}
					| T_ID '['expression']'
					{
						struct SymbTab * p;
						if ((p=Search($1,level,1)) != NULL)
						{
							$$ = ASTCreateNode(IDENT);
							$$->name=$1;
							// hold expression inside of array reference 
							$$->right=$3;
							$$->symbol=p;
							// capital Type is enum op
							$$->isType=p->Type;
							if (p->IsAFunc != 2)
							{
								yyerror($1);
								yyerror("Variable is not an array, syntax error");
							}
						}
						else
						{
							yyerror($1);
							yyerror("undeclared variable used");
							exit(1);
						}
					}
					;

simple-expression: 
					additive-expression relop additive-expression
					{  
						if (($1->isType != $3->isType) || ($1->isType == VOIDDEC))
						{
							yyerror("Type mismatch or void in simpleExpression");
							exit(1);
						}
						$$ = ASTCreateNode(EXPR);
						$$->op=$2;
						$$->left=$1;
						$$->right=$3;
						/* inherit the type, already check for equivalence
						  so can just use $1 */
						$$->isType=$1->isType;
						$$->name=CreateTemp();
						$$->symbol=Insert($$->name,$$->isType,0,level,1,offset,NULL);
						offset+=1;
						if(offset>maxoffset)
							maxoffset = offset;
					}
					| additive-expression	{$$ = $1;}
					;
	
relop: 
					T_SMALLEQ		{ $$=LESSTHANEQUAL; }
					| T_SMALL		{ $$=LESSTHAN; }
					| T_GREAT		{ $$=GREATERTHAN; }
					| T_GREATEQ	 	{ $$=GREATERTHANEQUAL; }
					| T_COMPARE		{ $$=EQUAL; }
					| T_NOTEQ		{ $$=NOTEQUAL; }
					;

additive-expression: 
					additive-expression addop term
					{   
						/* must ensure it is left recursive, to work properly
						 * we dont have to check both for void because if only one
						 * is void there will be a type mismatch, otherwise they are
						 * the same. So if one is void the other is also */
						if (($1->isType != $3->isType) || ($1->isType == VOIDDEC))
						{
							yyerror("Type mismatch or void in additive exp");
							exit(1);
						}
						$$ = ASTCreateNode(EXPR);
						$$->op=$2;
						$$->left=$1;
						$$->right=$3;
						/* inherit the type, already check for equivalence
						   so can just use $1 */
						$$->isType=$1->isType;
						$$->name=CreateTemp();
						$$->symbol=Insert($$->name,$$->isType,0,level,1,offset,NULL);
						offset+=1;
						if(offset>maxoffset)
							maxoffset = offset;
						}
					| term	{$$ = $1;}						
					;

addop: 				
					'+'		{ $$ = PLUS; }
					| '-'	{ $$ = MINUS; }
					;

term: 
					term mulop factor
					{  
						/* must ensure it is left recursive, to work properly
						 * we dont have to check both for void because if only one
						 * is void there will be a type mismatch, otherwise they are
						 * the same. So if one is void the other is also */
						if (($1->isType != $3->isType) || ($1->isType == VOIDDEC))
						{
							yyerror("Type mismatch or void in term/factor exp");
							exit(1);
						}
						$$ = ASTCreateNode(EXPR);
						$$->op=$2;
						$$->left=$1;
						$$->right=$3;
						/* inherit the type, already check for equivalence
						   so can just use $1*/
						$$->isType=$1->isType;
						$$->name=CreateTemp();
						$$->symbol=Insert($$->name,$$->isType,0,level,1,offset,NULL);
						offset+=1;
						if(offset>maxoffset)
							maxoffset = offset;
					}					
					| factor	{$$ = $1;}					
					;
	
mulop: 
					'*'		{ $$ = TIMES; }
					| '/'	{ $$ = DIVIDE; }
					;

factor: 
					'('expression')'	{$$ = $2;}		
					| var		{ $$ = $1; }			
					| call 		{ $$ = $1; }	
					| T_NUM
					{
						$$=ASTCreateNode(NUMBER);
						$$->value=$1;
						// numbers are always ints here
						$$->isType=INTDEC;
					}
					;

call: 
					T_ID '('args')'
					{
						struct SymbTab * p;
						if ((p=Search($1,0,1)) != NULL)
						{   // make sure symbol is a function
							if(p->IsAFunc != 1)
							{
								yyerror($1);
								yyerror("Is a variable, but was called as function");
								exit(1);
							}
							// have to make sure we are calling with right params
							$$=ASTCreateNode(CALLSTMT);
							// hold the link to args in right
							$$->right=$3;
							$$->name=$1;
							$$->symbol=p;
							$$->isType=p->Type;
						}
						else
						{
							yyerror($1);
							yyerror("Function not defined in symbol table");
							exit(1);
						}
					}
					;
	
args: 
					arg-list	{ $$ = $1; }
					|	{ $$ = NULL; }
					;
	
arg-list: 
					arg-list',' expression
					{  
						/* attach the expressions to the tree in order
						   the use of the argList is handled above */
						$$=ASTCreateNode(ARGLIST);
						$$->left=$3;
						$$->right=$1;
					}
					| expression
					{
						$$=ASTCreateNode(ARGLIST);
						$$->right=$1;
					}
					;
%%

int main(int argc, char *argv[]) {
	char filename[100];
	strcpy(filename, argv[1]);
	if (argc == 2) {
		yyin = fopen(argv[1], "r");
		printf("filename is %s\n", filename);
	}
	else {
		printf("No files - Exit\n");
		exit(1);
	}
    yyparse();
	printf("\nMain symbol table");
    Display();
    printf("the input has been syntactically checked\n");
    printf("starting print\n*\n*\n*\n*\n*\n");
	ASTprint(0, prog);
	return 0;
}

void yyerror(const char* s) {
	//fprintf(stderr, "%s-:%d %s\n", filename, yylineno, s);
	printf("%s On Line: %d\n", s, yylineno);
}