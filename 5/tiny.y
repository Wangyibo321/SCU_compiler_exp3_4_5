%{
#include "y.tab.h"
#include "scan.h"

#include <stdio.h>
#include <stdlib.h>
#include <ctype.h>
#include <string.h>

// Define syntax tree nodes
typedef enum {StmtK,ExpK} NodeKind;
typedef enum {IfK,RepeatK,AssignK,ReadK,WriteK} StmtKind;
typedef enum {OpK,ConstK,IdK} ExpKind;
typedef enum {Void,Integer,Boolean} ExpType;

#define MAXCHILDREN 3

typedef struct treeNode
   { struct treeNode * child[MAXCHILDREN];
     struct treeNode * sibling;
     int lineno;
     NodeKind nodekind;
     union { StmtKind stmt; ExpKind exp;} kind;
     union { TokenType op;
             int val;
             char * name; } attr;
     ExpType type; 
   } TreeNode;

#define YYSTYPE TreeNode *

// Function declarations
TreeNode * newStmtNode(StmtKind);
TreeNode * newExpNode(ExpKind);
char * copyString( char * );
TreeNode * parse(void);
void printTree( TreeNode * );

// Global variables
int lineno;

char * savedName; 
int savedLineNo;  
TreeNode * savedTree;
%}

%token IF THEN ELSE END REPEAT UNTIL READ WRITE
%token ID NUM 
%token ASSIGN EQ LT PLUS MINUS TIMES OVER LPAREN RPAREN SEMI
%token ERROR 

%% /* Tiny Grammar Rules */

program     : stmt_sequence
                 { savedTree = $1; } 
            ;

stmt_sequence   : stmt_sequence SEMI statement
                    {YYSTYPE t = $1;
                   if (t != NULL)
                   { while (t->sibling != NULL)
                        t = t->sibling;
                     t->sibling = $3;
                     $$ = $1; }
                     else $$ = $3;
                    }
                | statement {$$ = $1;}
                ;

statement   : if_stmt { $$ = $1; }
            | repeat_stmt { $$ = $1; }
            | assign_stmt { $$ = $1; }
            | read_stmt { $$ = $1; }
            | write_stmt { $$ = $1; }
            ;

if_stmt     : IF exp THEN stmt_sequence END
                 { $$ = newStmtNode(IfK);
                   $$->child[0] = $2;
                   $$->child[1] = $4;
                 }
            | IF exp THEN stmt_sequence ELSE stmt_sequence END
                 { $$ = newStmtNode(IfK);
                   $$->child[0] = $2;
                   $$->child[1] = $4;
                   $$->child[2] = $6;
                 }
            ;

repeat_stmt : REPEAT stmt_sequence UNTIL exp
                 { $$ = newStmtNode(RepeatK);
                   $$->child[0] = $2;
                   $$->child[1] = $4;
                 }
            ;

assign_stmt : ID { savedName = copyString(tokenString);
                   savedLineNo = lineno; }
                ASSIGN exp
                 { $$ = newStmtNode(AssignK);
                   $$->child[0] = $4;
                   $$->attr.name = savedName;
                   $$->lineno = savedLineNo;
                 }
            ;

read_stmt   : READ ID
                 { $$ = newStmtNode(ReadK);
                   $$->attr.name =
                     copyString(tokenString);
                 }
            ;

write_stmt  : WRITE exp
                 { $$ = newStmtNode(WriteK);
                   $$->child[0] = $2;
                 }
            ;

exp         : simple_exp { $$ = $1; }
            | simple_exp comparison_op simple_exp
                {
                    $$ = newExpNode(OpK);
                    $$->attr.op = $2;
                    $$->child[0] = $1;
                    $$->child[1] = $3;
                }
            ;

comparison_op : LT { $$ = LT; }
              | EQ { $$ = EQ; }
              ;

simple_exp  : simple_exp addop term
                {
                    $$ = newExpNode(OpK);
                    $$->attr.op = $2;
                    $$->child[0] = $1;
                    $$->child[1] = $3;
                }
            | term { $$ = $1; }
            ;

addop       : PLUS { $$ = PLUS; }
            | MINUS { $$ = MINUS; }
            ;

term        : term mulop factor
                {
                    $$ = newExpNode(OpK);
                    $$->attr.op = $2;
                    $$->child[0] = $1;
                    $$->child[1] = $3;
                }
            | factor { $$ = $1; }
            ;

mulop       : TIMES {$$ = TIMES;}
            | OVER {$$ = OVER;}
            ;

factor      : LPAREN exp RPAREN
                 { $$ = $2; }
            | NUM
                 { $$ = newExpNode(ConstK);
                   $$->attr.val = atoi(tokenString);
                 }
            | ID { $$ = newExpNode(IdK);
                   $$->attr.name =
                         copyString(tokenString);
                 }
            | error { $$ = NULL; }
            ;

%%

int yyerror(char * message)
{ 
    printf("Syntax error at line %d: %s\n", lineno, message);
    printf("Current token: ");
    printToken(yychar, tokenString);
    return 0;
}



TreeNode * parse(void)
{ 
    yyparse();
    return savedTree;
}

TreeNode * newStmtNode(StmtKind kind)
{ 
    TreeNode * t = (TreeNode *) malloc(sizeof(TreeNode));
    int i;
    if (t == NULL)
        printf("Out of memory error at line %d\n", lineno);
    else {
        for (i = 0; i < MAXCHILDREN; i++) t->child[i] = NULL;
        t->sibling = NULL;
        t->nodekind = StmtK;
        t->kind.stmt = kind;
        t->lineno = lineno;
    }
    return t;
}

TreeNode * newExpNode(ExpKind kind)
{ 
    TreeNode * t = (TreeNode *) malloc(sizeof(TreeNode));
    int i;
    if (t == NULL)
        printf("Out of memory error at line %d\n", lineno);
    else {
        for (i = 0; i < MAXCHILDREN; i++) t->child[i] = NULL;
        t->sibling = NULL;
        t->nodekind = ExpK;
        t->kind.exp = kind;
        t->lineno = lineno;
        t->type = Void;
    }
    return t;
}

char * copyString(char * s)
{ 
    int n;
    char * t;
    if (s == NULL) return NULL;
    n = strlen(s) + 1;
    t = malloc(n);
    if (t == NULL)
        printf("Out of memory error at line %d\n", lineno);
    else strcpy(t, s);
    return t;
}


static indentno = 0;

/* macros to increase/decrease indentation */
#define INDENT indentno+=2
#define UNINDENT indentno-=2

/* printSpaces indents by printing spaces */
static void printSpaces(void)
{ int i;
  for (i=0;i<indentno;i++)
     printf( " ");
}

/* procedure printTree prints a syntax tree to the 
 * listing file using indentation to indicate subtrees
 */
void printTree( TreeNode * tree )
{ 
  int i;
  INDENT;
  while (tree != NULL) {
    printSpaces();
    if (tree->nodekind==StmtK)  /*匹配statement的类型*/
    { 
		switch (tree->kind.stmt) {
        case IfK:
           printf( "If\n");
          break;
        case RepeatK:
           printf( "Repeat\n");
          break;
        case AssignK:
           printf( "Assign to: %s\n",tree->attr.name);
          break;
        case ReadK:
           printf( "Read: %s\n",tree->attr.name);
          break;
        case WriteK:
           printf( "Write\n");
          break;
        default:
           printf( "Unknown ExpNode kind\n");
          break;
      }
    }
    else if (tree->nodekind==ExpK) /*exp*/
    { 
		switch (tree->kind.exp) {
        case OpK:
           printf( "Op: ");
          printToken(tree->attr.op,"\0");
          break;
        case ConstK:
           printf( "Const: %d\n",tree->attr.val);
          break;
        case IdK:
           printf( "Id: %s\n",tree->attr.name);
          break;
        default:
           printf( "Unknown ExpNode kind\n");
          break;
      }
    }
    else  printf( "Unknown node kind\n");
    for (i=0;i<MAXCHILDREN;i++)
         printTree(tree->child[i]);  /*递归打印子节点*/
    tree = tree->sibling;  /*指向下一个结点*/
  }
  UNINDENT;  
}


int main(int argc, char * argv[])
{
    lineno = 0;
    TreeNode * syntaxTree;
    syntaxTree = parse();
    printTree(syntaxTree);
    return 0;
}
