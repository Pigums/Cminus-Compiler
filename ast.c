#include "ast.h"


/* uses malloc to create an ASTnode and passes back the heap address of
the newly created node */
ASTnode *ASTCreateNode(enum ASTtype mytype)
{
    ASTnode * p;
    if (debug)
        fprintf(stderr,"Creating AST Node \n");
    p=(ASTnode *)malloc(sizeof(ASTnode));
    p->type=mytype;
    p->left=NULL;
    p->right=NULL;
    p->s1=NULL;
    p->s2=NULL;
    p->value=0;
    p->name=NULL;
    p->str = NULL;
    p->symbol=NULL;
    p->isType=null;
    return(p);
}

/* attach q to the left most part of p */
void ASTattachleft(ASTnode* p,ASTnode* q)
{
    while (p->left !=NULL)
        p=p->left;
    p->left=q; /*add on the left side of the tree*/
}

void PT(int howmany){
    int i;
    for (i=0; i < howmany; i++)
        printf(" "); /* print tabbing blanks */
}

/*  Print out the abstract syntax tree */
void ASTprint(int level,ASTnode* p) //level, how many spaces 0 is left justified
{
    if (p == NULL ) return;
    else {
        PT(level);
        switch (p->type) {
        case VARDEC :
            printf("Variable  "); //one per ast node type
            if ((p->op) == INTDEC)
                printf("INT ");

            if (p->op == VOIDDEC)
                printf("VOID ");

            printf("%s", p->name);
            if (p->value > 0) //is an array
                printf("[%d]",p->value);

            printf("\n"); //finish with new line
            break;

        case FUNCTIONDEC:
            if (p->op == INTDEC)
                printf("INT ");

            if (p->op == VOIDDEC)
                printf("VOID ");

            printf("FUNCTION %s \n",p->name);
            /*print parameter list*/
            if (p->s1 == NULL) {
                PT(level+2);
                printf( "(VOID)\n" );
            }//end if
            else {
                PT(level+2);
                printf("( \n");
                //recursively print parameters
                ASTprint(level+2,p->s1);
                PT(level+2);
                printf(") \n");
            }//end else
            //recursively print the block statment
            ASTprint(level+2,p->right);
            break;

        case EXPR: printf("EXPR ");
            if (p->name != NULL)
                printf("  %s = ", p->name);

            //switch through the different ops in an expression
            switch (p->op){
                case PLUS: printf("+");
                break;

                case MINUS: printf("-");
                break;

                case TIMES: printf("*");
                break;

                case DIVIDE: printf("/");
                break;

                case LESSTHANEQUAL: printf("<=");
                break;

                case LESSTHAN: printf("<");
                break;

                case GREATERTHAN: printf(">");
                break;

                case GREATERTHANEQUAL: printf(">=");
                break;

                case NOTEQUAL: printf("!=");
                break;

                case EQUAL: printf("==");
                break;

                case INTDEC:
                case VOIDDEC:
                case null:
                //we should never be here since these are not in expression
                break;

           } //end switch (p->op)
           printf("\n");
           //recursively print left and right side of expression
           ASTprint(level+1, p->left);
           ASTprint(level+1, p->right);
           break;//EXPR break

        case  RETURNSTMT:
            printf("Return statement\n");
            //recursively print return expression
            ASTprint(level+1, p->right);
            break;

        case IDENT:
            printf("IDENTIFIER %s\n", p->name);
            if (p->right != NULL) {
                PT(level);
                printf("Array reference [\n");
                //recursively print everything in the array reference
                ASTprint(level+1,p->right);
                PT(level);
                printf("] end array\n");
            } //end if
            break;

        case BLOCK:
            printf("BLOCK STATEMENT\n");
            //recursively print the contents of the block statement
            ASTprint(level+1,p->right);
            break;


        case READSTMT:
            printf("READ STATEMENT\n");
            //recursively print the expression to be read
            ASTprint(level+1,p->right);
            break;

        case WRITESTMT:
            printf("WRITE STATEMENT\n");
            //recursively print the expression to be written
            ASTprint(level+1,p->right);
            break;

        case ASSIGN:
            printf("Assignment STATEMENT\n");
            //recursively print var to be assigned and expression on right
            ASTprint(level+1,p->right);
            ASTprint(level+1,p->s1);
            break;

        case NUMBER:
            printf("NUMBER with value %d\n", p->value);
            break;

        case ITERSTMT:
            printf("WHILE STATEMENT\n");

            //recursively pritn out condition and a newline for seperation
            ASTprint(level+1,p->right);
            printf("\n");

            //recursively print out statment(could be block) and newline
            ASTprint(level+1,p->s1);
            printf("\n");
            break;

        case PARAM:
            printf("PARAMETER ");
            if( p->op == INTDEC )
                printf("INT");

            if( p->op == VOIDDEC )
                printf("VOID");

            printf(" %s ",p->name); //name of the parameter
            if(p->value == -1)
                printf("[]");

            printf("\n");
            break;

        case IFSTMT:
            printf("IF STATEMENT\n");

            //recursively print out condition and newline for seperation
            ASTprint(level+1,p->right);
            printf("\n");

            //recursively print out Statement(can be block) and newline
            ASTprint(level+1,p->s1);
            printf("\n");

            //handle the else Statement
            if(p->s2 != NULL){
                PT(level);
                printf("ELSE \n");
                ASTprint(level+2,p->s2);
            }
            break;

        case CALLSTMT:
            printf("Function Call  %s\n" , p->name);
            if (p->right != NULL){
                //recursively print out args
                ASTprint(level+2, p->right);
                printf("\n");
            }
            //args were void
            else{
                PT(level+2);
                printf("(VOID)\n");
            }
            break;
        case ARGLIST:
            printf("ARG\n");
            //this arg's expression is right, the next arg is at left
            //it gets there from the main control
            ASTprint(level+1, p->right);
            break;

        case EXPRSTMT:
            printf("Expression Statement\n");
            //recursively print out the expression Statement
            ASTprint(level+1, p->right);
            break;

        default: printf("Unknown type in ASTprint\n");
        //if we hit default there was an error
            break;

        } //end switch p->type

        if (p->type != EXPR) //go left for all except expression
            ASTprint(level, p->left);
    }//end else
}//end ASTprint

/*used to compare parms declared to the ones used to call*/
int compareFormals(ASTnode * p, ASTnode * q)
{
    if((p==NULL) && (q==NULL))
        return(1); //they were both void
    else if ((p==NULL) || (q==NULL))
        return (0); //one is void, already checked for both so p!=q
    else if(p->isType == q->right->isType)
        compareFormals(p->left, q->left); //check the next param
    else
    {
        printf ("Comparing p %d and q %d \n",p->isType,q->isType);
        return(0);
    }
    //we shouldn't get here if we did something went wrong
}
