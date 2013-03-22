%{
#include<stdio.h>
#include<string.h>
#include<stdlib.h>
#include "common.h"
#include "Cbrace_stack.h"

#define INFINITY 65535

extern int line_counter; // input program line counter
extern int pre_counter;
int display_lock = 0;
int flag = 0; // check for block entries
int global_index = 0, func_index = 0, symbol_index = 0, par_index = 0, global_func_index = 0, par_func = 0, thread_index = 0, log_index=0, semphr_index = 0, cs_index = 0, thread_log_index = 0, hdr_index = 0, mutex_index = 0; //table index
char data_type[20]; // c data type
char access[20]; // access specifier (static,extern,typedef,etc.)
int in_func_flag = 0,in_func_stmt_flag = 0, ignore_flag = 0, local_found = 0, cs_detect = 0, extern_flag = 0, struct_flag = 0, thread_lib_flag = 0;
global_symbol gsym_tab[100]; // Global variable Entries
func_def func_tab[100]; // user defined function entries
symbol_table sym_tab[100]; // Symbol table Object
parameter par_tab[100]; // parameter table object
thread_info thread_tab[100]; // thread table object
func_def_log log_tab[100]; // log table object
semaphore_def sem_tab[100]; // semaphore table object
critical_section cs_tab[100]; // critical_section table object
thread_log thread_log_tab[100]; // thread log table object
mutex_def mutex_tab[100]; // mutex table object
critical_section_unique cs_tab1[50]; //critical section table object
char *headers[50];
int i;
int par_counter = 0;
void get_symbol(char []); // make entries into global and local variables
void process_header(char []);// finds file name of user-defind headers
void find_join_obj(char []);
void get_parameter(char []);
int release_value = INFINITY; // index of curly brace which should be pop from stack
stack_brace cbr_stack; // Stack for handling equal curly braces

%}

%union
{
 char arg[50];
 char any_arg;
}

//define tokens which will help to match patterns
%token MAIN OPEN_BR CLOSE_BR OPEN_CBR CLOSE_CBR OPEN_SBR CLOSE_SBR STAR COMMA SEMI EQUAL_TO PTHREAD_CREATE ADDRESS SEM_WAIT SEM_POST U_STRUCT POINTER_ACCESS THREAD_LIB MUTEX_LOCK MUTEX_UNLOCK PTHREAD_JOIN
%token <arg>  VAR NUM ACCESS TYPE PREPRO
%token <any_arg> ANYTHING
%type <arg> par_val1 par_val2 thread_creation sem_var mutex_var
%nonassoc high_priority
%%

// Start of Grammar with recursive statement
start:	stmnt start |//{printf("\n corrrect program with multiple statements");}|
	stmnt //{printf("\n Correct program");}
	;

// Process c statements
stmnt:	PREPRO {//printf("In Pre: %s",$1);  
		process_header($1); } |
	user_defination |
	declarative_stmnt SEMI	{
					// Check for local/global variable
					if (flag == 1){} //printf("\n Local Variable");
					else
					{
						//printf("\n Correct Global Declaration");
					}
				} |
	func_stmnt //|
	//thread_lib
	;


// Process user defined strutures like struct, enum, union
user_defination:	user_def_type1 SEMI {struct_flag = 0;} |
			user_def_type1 multi_var SEMI {struct_flag = 0;} |
			user_def_type2 SEMI {struct_flag = 0;} |
			user_def_type2 multi_var SEMI {struct_flag = 0;} |
			U_STRUCT {struct_flag = 1;} block multi_var SEMI {struct_flag = 0;} |
			ACCESS U_STRUCT {struct_flag = 1;} block multi_var SEMI {struct_flag = 0;} //|
			;

// Process : struct/union/enum struct_name {/* declaration */}
user_def_type1 :	u_struct {struct_flag = 1;} block
			;

// Process : typedef struct/union/enum struct_name {/* declaration */}
user_def_type2 :	ACCESS U_STRUCT VAR {struct_flag = 1;} block
			;

// Process : struct/union/enum struct_name
u_struct :              U_STRUCT VAR { strcpy(data_type,$2);}
			;

// Process variable declarations at end of structure block
multi_var:	VAR |
		VAR COMMA multi_var
		;


// pattern match for variable declaration
declarative_stmnt:	type var_list |//{printf("\ncorrect variable declaration...");} |
			utype_declaration |
			THREAD_LIB {thread_lib_flag = 1;} var_list {thread_lib_flag = 0;}
			;

// pattern match for c data type
type:	ACCESS {
		strcpy(access,$1);
		strcpy(data_type," ");
		if ( strcmp(access, "extern") == 0)
			{
				extern_flag = 1;
				release_value = cbr_stack.top;
			}
		} type_def {
				//printf("\n Correct type \t line No. :%d",line_counter);
			   } |
		{strcpy(data_type," ");} type_def {
							strcpy(access,"Default");
							//printf("\n Correct type \t line No. :%d",line_counter);
						   }/* |
		ACCESS {
		strcpy(access,$1);
		strcpy(data_type," ");
		if ( strcmp(access, "extern") == 0)
			{
				extern_flag = 1;
				release_value = cbr_stack.top;
			}
		} VAR {
				strcpy(data_type,$3);
				printf("\n Correct type \t line No. :%d",line_counter);
			   }|
		VAR {
			strcpy(access,"Default");
			strcpy(data_type,$1);
			printf("\n Correct type \t line No. :%d",line_counter);
		    }*/
	;

//pattern match for combinations of data types
type_def:	TYPE {strcat(data_type,$1); strcat(data_type," ");} type_def |
		TYPE {strcat(data_type,$1); strcat(data_type," ");} pointer |
		TYPE {strcat(data_type,$1); strcat(data_type," ");} array |
		//TYPE {strcat(data_type,$1); strcat(data_type," ");} type_def array |
		TYPE {strcat(data_type,$1);}
		;

// pattern match for pointer
pointer: STAR pointer|
	 STAR
	 ;

// pattern match for array
array:	array_type1 |
	array_type1 array |
	array_type2 |
	array_type2 array
	;

// process: [ VAR/NUM ]
array_type1:	OPEN_SBR operand CLOSE_SBR
		;

// process: [ ]
array_type2:	OPEN_SBR CLOSE_SBR
		;

// process Numbers or symbols
operand:	NUM | VAR
		;

// pattern match for one or more varibles
var_list:	variable COMMA var_list |
		variable
		;

// process structure declarations
utype_declaration:	u_struct var_list |
			ACCESS u_struct {
						strcpy(access,$1);
						//strcpy(data_type," ");
						//strcpy(data_type,$3);
						if ( strcmp(access, "extern") == 0)
						{
							extern_flag = 1;
							release_value = cbr_stack.top;
						}
					} var_list
			;


// make entry of variable based on block entries or global entries
variable:	VAR { get_symbol($1); } |
		//VAR { get_symbol($1); } EQUAL_TO NUM |
		variable_type1 assign_expr |
		variable_type2 assign_expr |
		variable_type1 |
		variable_type2 |
		VAR array { get_symbol($1); } |
		array VAR { get_symbol($2); } EQUAL_TO assign_expr |
		//array VAR { get_symbol($2); } EQUAL_TO block |
		pointer VAR { get_symbol($2); } EQUAL_TO assign_expr |
		pointer VAR { get_symbol($2); }
		;

// process var_name =
variable_type1:	VAR { get_symbol($1); }	 EQUAL_TO
		;

// process var_name [] =
variable_type2:	VAR array EQUAL_TO { get_symbol($1); }
		;

// process assignment operation
assign_expr:	OPEN_CBR assign_expr | CLOSE_CBR assign_expr |  CLOSE_CBR |
		any_expr assign_expr |
		any_expr
		;

// pattern match for function statement
func_stmnt:	func_prototype SEMI {par_index = par_index - par_counter;} |//printf("\n Correct Function prototype Declaration");} |
		func_prototype {

				// Make entry function into func_table
				//printf("\n Correct Function Declaration");

				func_tab[global_func_index].index = global_func_index;
				func_tab[global_func_index].line_number = line_counter;
				func_tab[global_func_index].no_of_parameter = par_counter;

				global_func_index++;

			    } block
	;


// pattern match for function prototype
func_prototype: type VAR {
				// pattern match return type and function name
				strcpy(func_tab[global_func_index].return_type,data_type);
				strcpy(func_tab[global_func_index].func_name,$2);
				//printf("\n Correct Function prototype");
				par_counter = 0;
		} bracket //{printf("\n Correct Function prototype");}
		;

// process function parameters
bracket:	OPEN_BR  par CLOSE_BR |
		OPEN_BR CLOSE_BR
		;


// pattern match for function parameters
par:	parameter COMMA par|
	parameter
	;

// pattern match for parameter entry
parameter:	parameter_type1 |
		parameter_type1 array |
		utype_par
		//{strcpy(data_type,"");} type
		;

// process: data_type var_name
parameter_type1:	parameter_type2 VAR	{
							get_parameter($2);
						} |
			parameter_type2
			;

// process built in data types
parameter_type2:	{strcpy(data_type,"");} type
	;

// process structure parameters to the function
utype_par:      utype_par_type1 |
		utype_par_type1 array |
		u_struct array VAR {get_parameter($3);} |
		u_struct pointer VAR {get_parameter($3);}
		;

// process struct/union/enum struct_name var_name
utype_par_type1:	u_struct VAR {get_parameter($2);}
			;

// pattern match for block entry
block:	OPEN_CBR
		{
			push_cbr(&cbr_stack);
			if (flag)
			{
				in_func_flag = 1;
				par_func = func_index;

			}
			func_index = global_func_index;
			flag = 1;
		}
	code CLOSE_CBR
		{
			if (release_value == cbr_stack.top)
			{
				extern_flag = 0;
				release_value = INFINITY;
			}
			pop_cbr(&cbr_stack);
			if (!in_func_flag)
				flag = 0;
			else
			{
				in_func_flag = 0;
				func_index = par_func;
			}
		}|
	OPEN_CBR CLOSE_CBR
	;

// pattern match for other c code
code:	block | block code |
	stmnt | stmnt code |  any code |
	any
	;

// process any code that will appear in function blocks
any:
	NUM |
	VAR {
		local_found = 0;
		for(i = 0;i < symbol_index; i++)
		{
			if (sym_tab[i].func_index == global_func_index - 1 && strcmp(sym_tab[i].sym_name,$1) == 0 && (!extern_flag))
			{
				local_found = 1;
				log_tab[log_index].index = log_index;
				log_tab[log_index].line_number = line_counter;
				log_tab[log_index].func_index = global_func_index - 1;
				strcpy(log_tab[log_index].sym_name,$1);
				strcpy(log_tab[log_index].type,"Local");
				//printf("\nGlobal_func_index :%d",global_func_index-1);
				//printf("\n\t %5d %15s %15s %15s %15d",log_index,func_tab[log_tab[log_index].func_index].func_name,log_tab[log_index].sym_name,log_tab[log_index].type,log_tab[log_index].line_number);
				log_index++;
			}
		}

		if (!local_found)
		{
			for(i = 0;i < global_index; i++)
			{
				if (strcmp(gsym_tab[i].sym_name,$1) == 0)
				{
					log_tab[log_index].index = log_index;
					log_tab[log_index].line_number = line_counter;
					log_tab[log_index].func_index = global_func_index - 1;
					strcpy(log_tab[log_index].sym_name,$1);
					strcpy(log_tab[log_index].type,"Global");
					//printf("\nGlobal_func_index :%d",global_func_index-1);
					//printf("\n\t %5d %15s %15s %15s %15d",log_index,func_tab[log_tab[log_index].func_index].func_name,log_tab[log_index].sym_name,log_tab[log_index].type,log_tab[log_index].line_number);
					log_index++;
				}
			}
		}
		//printf("\n Variable: %s:",$1);
	    }|
	OPEN_BR |
	CLOSE_BR|
	OPEN_SBR|
	CLOSE_SBR|
	OPEN_BR type CLOSE_BR |
	OPEN_BR u_struct pointer CLOSE_BR |
	STAR |
	COMMA |
	SEMI |
	POINTER_ACCESS |
	EQUAL_TO |
	thread_creation |
	thread_join |
	ADDRESS |
	SEM_WAIT OPEN_BR sem_var {	sem_tab[semphr_index].index = semphr_index;
					sem_tab[semphr_index].sem_wait_point = line_counter;
					strcpy(sem_tab[semphr_index].sem_obj,$3);
					semphr_index++;
				} CLOSE_BR SEMI |
	SEM_POST OPEN_BR sem_var {
					for(i = 0; i < semphr_index; i++)
						if (strcmp(sem_tab[i].sem_obj,$3) == 0)
							sem_tab[i].sem_post_point = line_counter;
				} CLOSE_BR SEMI  |
	MUTEX_LOCK OPEN_BR mutex_var	{
						mutex_tab[mutex_index].index = mutex_index;
						mutex_tab[mutex_index].mutex_lock_point = line_counter;
						strcpy(mutex_tab[mutex_index].mutex_obj,$3);
						mutex_index++;
					} CLOSE_BR SEMI |
	MUTEX_UNLOCK OPEN_BR mutex_var	{
						for (i = 0; i < mutex_index; i++)
							if (strcmp(mutex_tab[i].mutex_obj,$3) == 0)
								mutex_tab[i].mutex_unlock_point = line_counter;
					} CLOSE_BR SEMI
	;


// process any code that will appear in assignment expression
any_expr:
	NUM |
	VAR {
		local_found = 0;
		for(i = 0;i < symbol_index; i++)
		{
			if (sym_tab[i].func_index == global_func_index - 1 && strcmp(sym_tab[i].sym_name,$1) == 0 && (!extern_flag))
			{
				local_found = 1;
				log_tab[log_index].index = log_index;
				log_tab[log_index].line_number = line_counter;
				log_tab[log_index].func_index = global_func_index - 1;
				strcpy(log_tab[log_index].sym_name,$1);
				strcpy(log_tab[log_index].type,"Local");
				//printf("\nGlobal_func_index :%d",global_func_index-1);
				//printf("\n\t %5d %15s %15s %15s %15d",log_index,func_tab[log_tab[log_index].func_index].func_name,log_tab[log_index].sym_name,log_tab[log_index].type,log_tab[log_index].line_number);
				log_index++;
			}
		}

		if (!local_found)
		{
			for(i = 0;i < global_index; i++)
			{
				if (strcmp(gsym_tab[i].sym_name,$1) == 0)
				{
					log_tab[log_index].index = log_index;
					log_tab[log_index].line_number = line_counter;
					log_tab[log_index].func_index = global_func_index - 1;
					strcpy(log_tab[log_index].sym_name,$1);
					strcpy(log_tab[log_index].type,"Global");
					//printf("\nGlobal_func_index :%d",global_func_index-1);
					//printf("\n\t %5d %15s %15s %15s %15d",log_index,func_tab[log_tab[log_index].func_index].func_name,log_tab[log_index].sym_name,log_tab[log_index].type,log_tab[log_index].line_number);
					log_index++;
				}
			}
		}
    //printf("\n Variable: %s:",$1);
	    }|
	//block |
	OPEN_BR |
	CLOSE_BR|
	OPEN_SBR|
	CLOSE_SBR|
	STAR |
	COMMA |
	TYPE |
	U_STRUCT |
	POINTER_ACCESS |
	EQUAL_TO |
	thread_creation |
	thread_join |
	ADDRESS |
	SEM_WAIT OPEN_BR sem_var {	sem_tab[semphr_index].index = semphr_index;
					sem_tab[semphr_index].sem_wait_point = line_counter;
					strcpy(sem_tab[semphr_index].sem_obj,$3);
					semphr_index++;
				} CLOSE_BR SEMI |
	SEM_POST OPEN_BR sem_var {
					for(i = 0; i < semphr_index; i++)
						if (strcmp(sem_tab[i].sem_obj,$3) == 0)
							sem_tab[i].sem_post_point = line_counter;
				} CLOSE_BR SEMI |
	MUTEX_LOCK OPEN_BR mutex_var	{
						mutex_tab[mutex_index].index = mutex_index;
						mutex_tab[mutex_index].mutex_lock_point = line_counter;
						strcpy(mutex_tab[mutex_index].mutex_obj,$3);
						mutex_index++;
					} CLOSE_BR SEMI |
	MUTEX_UNLOCK OPEN_BR mutex_var	{
						for (i = 0; i < mutex_index; i++)
							if (strcmp(mutex_tab[i].mutex_obj,$3) == 0)
								mutex_tab[i].mutex_unlock_point = line_counter;
					} CLOSE_BR SEMI
	;

// process semaphore parameters
sem_var:	ADDRESS	VAR { strcpy($$,$2); } |
		VAR { strcpy($$,$1); }
// |
//		ADDRESS VAR { strcpy($$,$2); } OPEN_SBR VAR CLOSE_SBR
		;

// process mutex parameters
mutex_var:	ADDRESS	VAR { strcpy($$,$2); } |
		VAR { strcpy($$,$1); }
		;

// pattern match for pthread_create
thread_creation : thread_creation_type1 COMMA par_val1 COMMA VAR { 		//printf(" pointing to function %s",$5);
										thread_tab[thread_index].index = thread_index;

										strcpy(thread_tab[thread_index].func_name,$5);
										strcpy(thread_tab[thread_index].parent_thread,func_tab[func_index-1].func_name);

									} COMMA  par_val2 CLOSE_BR  {//printf("\ncorrect thread...."); 
													thread_index++;} |
		thread_creation_type1 array COMMA par_val1 COMMA VAR { //printf(" pointing to function %s",$6);
										thread_tab[thread_index].index = thread_index;

										strcpy(thread_tab[thread_index].func_name,$6);
										strcpy(thread_tab[thread_index].parent_thread,func_tab[func_index-1].func_name);

									} COMMA  par_val2 CLOSE_BR  {//printf("\ncorrect thread...."); 
													thread_index++;}
		;

thread_join:	thread_join_type1 VAR CLOSE_BR |
		thread_join_type1 ADDRESS VAR CLOSE_BR
		;

thread_join_type1:	PTHREAD_JOIN OPEN_BR VAR COMMA { find_join_obj($3); }
			;

// process: pthread_create ( & thread_object )
thread_creation_type1:	PTHREAD_CREATE OPEN_BR ADDRESS VAR	{
									//printf("\n thread object %s ",$4);
									strcpy(thread_tab[thread_index].thread_obj, $4);
									thread_tab[thread_index].line_number = line_counter;
								}
			;

par_val1:	ADDRESS VAR	{
					//printf("\n Thread attribute: %s",$2);
					strcpy(thread_tab[thread_index].thread_attr,$2);
				} |
		VAR { strcpy(thread_tab[thread_index].thread_attr,$1); }
		;

par_val2:	VAR {//printf("\n Thread function parameter : %s",$1); 
			strcpy(thread_tab[thread_index].func_arg,$1);} |
		par_val2_type1 VAR {//printf("\n Thread function parameter : %s",$2); 
					strcpy(thread_tab[thread_index].func_arg,$2);} |
		par_val2_type1 ADDRESS VAR {//printf("\n Thread function parameter : %s",$3); 
						strcpy(thread_tab[thread_index].func_arg,$3);}
		;

par_val2_type1:	OPEN_BR type CLOSE_BR
		;
/*
thread_lib:	THREAD_T thread_var_list |
		THREAD_T thread_var_list
		;

thread_var_list:	thread_variable COMMA thread_var_list |
			thread_variable
			;

thread_variable:	VAR |
			//VAR { get_symbol($1); } EQUAL_TO NUM |
			thread_variable_type1 assign_expr |
			thread_variable_type2 assign_expr |
			VAR array |
			array VAR EQUAL_TO assign_expr |
			//array VAR { get_symbol($2); } EQUAL_TO block |
			pointer VAR EQUAL_TO assign_expr |
			pointer VAR
			;

// process var_name =
thread_variable_type1:	VAR EQUAL_TO
			;

// process var_name [] =
thread_variable_type2:	VAR array EQUAL_TO
			;
*/
%%

extern FILE *yyin;

void get_parameter(char var_name[])
{
	par_tab[par_index].func_index = global_func_index;
	strcpy(par_tab[par_index].type,data_type);
	strcpy(par_tab[par_index].par_name,var_name);
	//printf("\n\t\t %s \t %s \t %d",par_tab[par_index].par_name,par_tab[par_index].type,par_tab[par_index].func_index);
	par_index++;
	par_counter++;
}

void process_header(char header_text[])
{
	char *hdr_file, substr[5] = "\"";
	int len;

	if ((hdr_file = strstr(header_text,substr)))
	{
		len = strlen(hdr_file);
		hdr_file++;
		hdr_file[len-2] = '\0';
		headers[hdr_index] =  (char *)malloc(50 * sizeof(char));
		strcpy(headers[hdr_index],hdr_file);
		//printf("\n Header file name:%s\n ",headers[hdr_index]);
		hdr_index++;

	}
}

void extract_archieve(char *file_name)
{
	char *source_path = NULL;
	int i,path_length;

	source_path = (char *)malloc(50 * sizeof(char));
	path_length = strlen(file_name);
	for (i = path_length; i >= 0; i--)
	{
		if (*(file_name + i) == '/')
		{
			*(file_name + i + 1) = '\0';
			break;
		}
	}

	//printf("\n\n Source path:%s",file_name);

}


void get_symbol(char var[])
{
	if (struct_flag || thread_lib_flag)
		return;
    if(flag == 0 || (flag == 1 && extern_flag == 1)) // Global variable entry
	{
	    if (!extern_flag)
	    {
		gsym_tab[global_index].line_number = line_counter;
		gsym_tab[global_index].index = global_index;
		strcpy(gsym_tab[global_index].sym_name,var);
		strcpy(gsym_tab[global_index].access,access);
		strcpy(gsym_tab[global_index].type,data_type);
		//printf("\n Access of %s is %s \n line number: %d \nData type:%s",gsym_tab[global_index].sym_name,gsym_tab[global_index].access,gsym_tab[global_index].line_number,gsym_tab[global_index].type);
		global_index++;
	    //extern_flag = 0;
	   }
	}
    else // Local variable entry
	{

	    sym_tab[symbol_index].func_index = func_index-1;
	    sym_tab[symbol_index].index = symbol_index;
	    strcpy(sym_tab[symbol_index].access,access);
	    strcpy(sym_tab[symbol_index].sym_name,var);
	    strcpy(sym_tab[symbol_index].type,data_type);
	    sym_tab[symbol_index].line_number = line_counter;

	    symbol_index++;
	}

}

void find_join_obj(char thread_obj[])
{
	int i;

	for (i = 0; i < thread_index; i++)
	{
		if (strcmp(thread_tab[i].thread_obj, thread_obj) == 0)
		{
			thread_tab[i].pthread_join = line_counter;
			break;
		}
	}
}
void update_log_tab(int copy_log_index[], int copy_index, int thread_id)
{
	int i;
	for (i = 0; i < copy_index; i++)
	{
		log_tab[log_index] = log_tab[copy_log_index[i]];
		log_tab[log_index].thread_index = thread_id;
		log_index++;
	}
}

void find_log_entries(int func_index, int thread_id)
{
	int i;
	int copy_log_index[50], copy_index = 0;


	for(i = 0; i < log_index; i++)
	{
		if (log_tab[i].func_index == func_index)
		{
			copy_log_index[copy_index] = i;
			copy_index++;
		}
	}
	update_log_tab(copy_log_index,copy_index, thread_id);
}

void check_threads()
{
	int i, j;
	for (i = 0; i < thread_index; i++)
	{
		for(j = 0; j < thread_log_index; j++)
		{
			if (thread_log_tab[j].func_index == thread_tab[i].func_index)
				break;
		}
		if (j == thread_log_index)
		{
			thread_log_tab[thread_log_index].func_index = thread_tab[i].func_index;
			thread_log_index++;
		}
		else
			find_log_entries(thread_tab[i].func_index, thread_tab[i].index );
	}
}


void assign_func_index()
{
	int i, j;

	if (thread_index == 0)
	{
		printf("\n\n NO THREAD FUNCTIONS FOUND!!!");
		exit(0);
	}
	for (i = 0; i < thread_index; i++)
		for (j = 0; j < global_func_index; j++)
			if (strcmp(thread_tab[i].func_name,func_tab[j].func_name) == 0)
			{
				thread_tab[i].func_index = func_tab[j].index;
				break;
			}
}


void check_thread_entry()
{
	int i, j;

	for (i = 0; i < log_index; i++)
	{
		for(j = 0; j < thread_index; j++)
		{
			if (log_tab[i].func_index == thread_tab[j].func_index)
				{
					log_tab[i].thread_func = 1;
					log_tab[i].thread_index = thread_tab[j].index;
					break;
				}
		}
		if(j == thread_index)
		{
			log_tab[i].thread_func = 0;
			log_tab[i].thread_index = -1;
		}
	}
}


void create_main_thread()
{
	int i;

	for (i = 0; i < global_func_index; i++)
		if (strcmp(func_tab[i].func_name,"main") == 0)
		{
			thread_tab[thread_index].index = thread_index;
			strcpy(thread_tab[thread_index].thread_obj,"main");
			strcpy(thread_tab[thread_index].func_name,"main");
			thread_tab[thread_index].func_index = i;
			strcpy(thread_tab[thread_index].thread_attr,"NULL");
			strcpy(thread_tab[thread_index].func_arg,"NULL");
			strcpy(thread_tab[thread_index].parent_thread,"main");
			thread_index++;
		}
}


int check_synchro_join(int log_index)
{
	int i;

	for (i = 0; i < thread_index; i++)
	{
		if (thread_tab[i].pthread_join == 0)
			break;
		if (thread_tab[i].pthread_join > log_tab[log_index].line_number)
			break;

	}
	if (i == thread_index)
		return 1;

	return 0;
}

// Function detects critical region
void cs_check()
{
    int i, j, k, l;
    int detect_join;

	for (i = 0; i < log_index; i++)
	{
	    //	printf("but now here..");//shala
		cs_detect = 0;
		if (!log_tab[i].thread_func)
			continue;
		/* check for main thread. Shared object used in main thread
		   creates no race if used before thread creation or after
		   thread join. */
		/*	if (strcmp(thread_tab[log_tab[i].thread_index].func_name,"main") == 0)
		{
			for (k = 0; k < thread_index; k++)
			{

				printf("\n Thread index:%d\nShared object Line no.:%d",k,log_tab[i].line_number);
				if (thread_tab[k].index == log_tab[i].thread_index)
					continue;
				printf("\nThread Creation Line No:%d\n Thread Join Line No.:%d",thread_tab[k].line_number,thread_tab[k].pthread_join);
				if (thread_tab[k].line_number < log_tab[i].line_number && thread_tab[k].pthread_join > log_tab[i].line_number)
					break;
			}
			//detect_join = check_synchro_join(i);

			printf("\nthred_index %d and k %d",thread_index,k);  ///shala....
			if (k == thread_index)
				cs_detect = 1;
		}

		if (cs_detect)
		{
			printf("I was here...");//shala
			continue;
		}

		printf("oooopssssss...");//shala
		*/cs_detect = 0;
		// loop used to handle proper locks
		for (k = 0; k < semphr_index; k++)
		    if (sem_tab[k].sem_wait_point <= log_tab[i].line_number && sem_tab[k].sem_post_point >= log_tab[i].line_number)
			    break;

		for (l = 0; l < mutex_index; l++)
			if (mutex_tab[l].mutex_lock_point <= log_tab[j].line_number && mutex_tab[l].mutex_unlock_point >= log_tab[j].line_number)
			    break;

		if (k != semphr_index)
			continue;

		if (l != mutex_index)
			continue;


		if ( (log_tab[i].thread_func) && strcmp(log_tab[i].type,"Global") == 0)
		{
			for (j= i + 1; j < log_index; j++)
			{
				if ( (log_tab[j].thread_func) && log_tab[i].thread_index != log_tab[j].thread_index  && strcmp(log_tab[j].type,"Global") == 0 && strcmp(log_tab[i].sym_name,log_tab[j].sym_name) == 0)
				{
				    for (k = 0; k < semphr_index; k++)
					if (sem_tab[k].sem_wait_point <= log_tab[j].line_number && sem_tab[k].sem_post_point >= log_tab[j].line_number)
					    break;

				    for (l = 0; l < mutex_index; l++)
					if (mutex_tab[l].mutex_lock_point <= log_tab[j].line_number && mutex_tab[l].mutex_unlock_point >= log_tab[j].line_number)
					    break;

				    if (k != semphr_index)
					continue;

				    if (l != mutex_index)
					continue;

				    cs_detect = 1;
					// code for inserting shared object in critical section
					for (k = 0; k < cs_index; k++)
					{
						if (log_tab[i].line_number == cs_tab[k].critical_location && strcmp(log_tab[i].sym_name,cs_tab[k].critical_obj) == 0)
							break;
					}
					if (k == cs_index)
					{
						cs_tab[cs_index].index = cs_index;
						strcpy(cs_tab[cs_index].critical_obj, log_tab[i].sym_name);
						cs_tab[cs_index].thread_func_index = log_tab[i].func_index;
						cs_tab[cs_index].critical_location = log_tab[i].line_number;
						cs_index++;
					}

				    for (k = 0;k < cs_index; k++)
					{
					    if (log_tab[j].line_number == cs_tab[k].critical_location && strcmp(log_tab[j].sym_name,cs_tab[k].critical_obj) == 0)
						break;
					}
				    if (k == cs_index)
					{

					    cs_tab[cs_index].index = cs_index;
					    strcpy(cs_tab[cs_index].critical_obj, log_tab[j].sym_name);
					    cs_tab[cs_index].thread_func_index = log_tab[j].func_index;
					    cs_tab[cs_index].critical_location = log_tab[j].line_number;
					    cs_index++;
					}

				}
			}
			if (cs_detect)
			{

			}
		}
	}

}


void display_global_variables()
{
        int i;
        if (global_index != 0)
        {
                printf("\n\n\t\t\t    = = = GLOBAL SYMBOL's TABLE = = =\n");
                // printf("\t_________________________________________________________________________");
                printf("\n\t %5s %15s %15s %15s %15s","INDEX","ACCESS","NAME","TYPE","LINE\n");
                printf("\t_________________________________________________________________________\n\n");
                for(i = 0; i < global_index; i++)
                        printf("\t %5d %15s %15s %15s %15d\n",gsym_tab[i].index,gsym_tab[i].access,gsym_tab[i].sym_name,gsym_tab[i].type,gsym_tab[i].line_number);
                printf("\t_________________________________________________________________________\n");
        }

}

void display_function()
{
        int i;
        if (global_func_index != 0)
        {
                printf("\n\n\t\t\t   = = = USER DEFINED FUNCTIONS = = = \n");
                // printf("\t_________________________________________________________________________\n");
                printf("\n\t %5s %15s %15s %15s %15s","INDEX","LINE","NAME","RET_TYPE","PARMTRS\n");
                printf("\t_________________________________________________________________________\n\n");
                for(i = 0; i < global_func_index; i++)
                        printf("\t %5d %15d %15s %15s %15d\n ",func_tab[i].index,func_tab[i].line_number,func_tab[i].func_name,func_tab[i].return_type,func_tab[i].no_of_parameter);
                printf("\t_________________________________________________________________________\n");
        }
}

void display_local_variables()
{
        int i;				 

        if (symbol_index != 0)
        {
                printf("\n\n\t\t\t\t  = = = LOCAL SYMBOL's TABLE = = = \n");
                printf("\n\t %5s %15s %15s %15s %15s %15s","INDEX","ACCESS","NAME","TYPE","FUNC_INDEX","LINE\n");
                printf("\t___________________________________________________________________________________________\n\n");
                for(i = 0;i < symbol_index; i++)
                        printf("\t %5d %15s %15s %15s %15d %15d\n",i,sym_tab[i].access,sym_tab[i].sym_name,sym_tab[i].type,sym_tab[i].func_index,sym_tab[i].line_number);
                printf("\t___________________________________________________________________________________________\n");

        }
}

void display_func_paramtr()
{
        int i;
        if(par_index != 0)
        {
                printf("\n\n\t\t\t  = = = FUNCTION's PARAMETER TABLE = = = \n");
                printf("\n\t %5s %15s %15s %15s","INDEX","NAME","TYPE","\tFUNC_INDEX\n");
                printf("\t_________________________________________________________________________\n\n");
                for(i = 0;i < par_index; i++)
                        printf("\t %5d %15s %15s %15d\n",i,par_tab[i].par_name,par_tab[i].type,par_tab[i].func_index);
                printf("\t_________________________________________________________________________\n");
        }
}

void display_thread()
{
        int i;
        if (thread_index != 0)
        {
                printf("\n\n\t\t\t\t\t     = = = THREAD TABLE = = = \n");
                printf("\n\t %5s %15s %15s %15s %15s %15s %15s","INDEX","THREAD_OBJ","FUNCTION_NAME","FUNC_INDEX","THREAD_ATTR","FUNC_ARG","PARENT_THREAD\n");
                printf("\t____________________________________________________________________________________________________________\n\n");
                for(i = 0;i < thread_index; i++)
                        printf("\t %5d %15s %15s %15d %15s %15s %15s\n",i,thread_tab[i].thread_obj,thread_tab[i].func_name,thread_tab[i].func_index,thread_tab[i].thread_attr,thread_tab[i].func_arg,thread_tab[i].parent_thread);
                printf("\t____________________________________________________________________________________________________________\n");
        }
}

void display_log()
{
        int i;
        if (log_index != 0)
        {
                printf("\n\n\t\t\t\t\t\t= = = LOG TABLE = = = \n");
                printf("\n\t %5s %15s %15s %15s %15s %15s %15s","INDEX","FUNCTION_NAME","SYMBOL","TYPE","LINE_NUMBER","THREAD_FUNC","THREAD_INDEX\n");
                printf("\t____________________________________________________________________________________________________________\n\n");
                for(i = 0;i < log_index; i++)
                        printf("\t %5d %15s %15s %15s %15d %15d %15d\n",i,func_tab[log_tab[i].func_index].func_name,log_tab[i].sym_name,log_tab[i].type,log_tab[i].line_number, log_tab[i].thread_func, log_tab[i].thread_index);
                printf("\t____________________________________________________________________________________________________________\n");
        }
}

void display_semaphr()
{
        int i;
        if (semphr_index != 0)
        {
                printf("\n\n\t\t\t = = = Semaphore Table = = = \n");
                printf("\n\t %5s %15s %15s %15s","INDEX","SEM_OBJECT","WAIT_POINT","POST_POINT\n");
                printf("\t_________________________________________________________________________\n\n");
                for(i = 0;i < semphr_index; i++)
                        printf("\t %5d %15s %15d %15d\n",i,sem_tab[i].sem_obj,sem_tab[i].sem_wait_point,sem_tab[i].sem_post_point);
                printf("\t_________________________________________________________________________\n");
        }
}

void display_mutex()
{
        int i;
        if (mutex_index != 0)
        {
                printf("\n\n\t\t\t = = = Mutex Table = = = \n");
                printf("\n\t %5s %15s %15s %15s","INDEX","MUTEX_OBJECT","MUTEX_LOCK_POINT","MUTEX_UNLOCK_POINT\n");
                printf("\t_________________________________________________________________________\n\n");
                for(i = 0;i < mutex_index; i++)
                        printf("\t %5d %15s %15d %15d\n",i,mutex_tab[i].mutex_obj,mutex_tab[i].mutex_lock_point,mutex_tab[i].mutex_unlock_point);
                printf("\t_________________________________________________________________________\n");
        }
	else
		printf("\n\n No MUTEX entry found for given input");
}

int display_critical_section()
{
  //int i;
        int i, j, k = 0 ,flag = 0 ,l = 0 ;
        int similar[10];
        critical_section_unique cs_tab1[10];
        if (cs_index != 0)
        {
               /* printf("\n\n\t\t\t = = = SUSPECTED CRITICAL SECTION = = = \n");
                printf("\t_________________________________________________________________________\n");
                //	printf("\n\t %5s %15s %15s %15s","INDEX","CRITICAL_OBJECT","THREAD_FUNC_INDEX","CRITICAL_LOCATION");
                for(i = 0;i < cs_index; i++)
                    printf("\n\t\t INDEX: %20d \n\t\t Shared Object: %16s \n\t\t Thread Function Index:  %3d \n\t\t Thread Function: %26s \n\t\t Critical Location:  %8d \n\n\t\t________________________________________________\n",i,cs_tab[i].critical_obj,cs_tab[i].thread_func_index,thread_tab[cs_tab[i].thread_func_index].func_name,cs_tab[i].critical_location);
                printf("\t_________________________________________________________________________\n");
				*/
				return 1;
		        }
        else
                printf("\n\n NO CRITICAL SECTION DETECTED");
		return 0;
}
        

void create_cs_log()
{
         int i, j = 0, k = 0, flag = 0, l = 0, min=0, m=0, flag1=1 ;
         int similar[10],min_line , max_line ;

        if ( cs_index == 0 )
          printf("\n\nNO CRITICAL SECTION FOUND!!!\n\n");
        else
        {
           /* printf("\n\t\t\t\t\t= = = CRITICAL SECTION LOG = = =\n\n\t  INDEX     SHARED OBJECT    THREAD FUNCION INDEX   LOCATION(MIN)    LOCATION(MAX)     THREAD FUNCTION");
          printf("\n\t________________________________________________________________________________________________________\n\n");
          */
          cs_tab1[k].min_critical_location = cs_tab1[k].max_critical_location = cs_tab[j].critical_location ;

	 for(i=0; i < cs_index-1; i++)
          {
	    flag1=1;
            
            for(j= i + 1 ; j < cs_index; j++)
            {
              if( cs_tab[i].thread_func_index == cs_tab[j].thread_func_index &&
                  strcmp ( cs_tab[i].critical_obj, cs_tab[j].critical_obj ) == 0 &&
                  strcmp ( thread_tab [cs_tab[i].thread_func_index].func_name, thread_tab[cs_tab[j].thread_func_index].func_name ) ==0 )
              {
                flag = 1 ;
		flag1 = 0;
                min = j ;
		/*for(m=0; m < k; m++)
                if(cs_tab1[m].thread_func_index == cs_tab[j].thread_func_index && strcmp( cs_tab1[m].critical_obj, cs_tab[j].critical_obj) == 0 && strcmp ( thread_tab [cs_tab1[m].thread_func_index].func_name, thread_tab[cs_tab[j].thread_func_index].func_name ) == 0 )
                        flag=0;    */        
	     }
	     for(m=0; m < k; m++)
                if(cs_tab1[m].thread_func_index == cs_tab[i].thread_func_index && strcmp( cs_tab1[m].critical_obj, cs_tab[i].critical_obj) == 0 && strcmp ( thread_tab [cs_tab1[m].thread_func_index].func_name, thread_tab[cs_tab[i].thread_func_index].func_name ) == 0 )
		{
                        flag1=0;  
			flag=0;
		}	
           }
	   
	  if(flag1 == 1 && j == cs_index)
		{
			cs_tab1[k].index = k ;
             strcpy( cs_tab1[k].critical_obj, cs_tab[i].critical_obj ) ;
             cs_tab1[k].thread_func_index = cs_tab[i].thread_func_index ;
             cs_tab1[k].min_critical_location = cs_tab[i].critical_location;
             cs_tab1[k].max_critical_location = cs_tab[i].critical_location;
             k++ ;
		flag1=0;
		}
           if(flag == 1)
           {
             cs_tab1[k].index = k ;
             strcpy( cs_tab1[k].critical_obj, cs_tab[min].critical_obj ) ;
             cs_tab1[k].thread_func_index = cs_tab[min].thread_func_index ;
             cs_tab1[k].min_critical_location = cs_tab[i].critical_location;
             cs_tab1[k].max_critical_location = cs_tab[min].critical_location;
             k++ ;
	     flag = 0;
           }
	} //for i
	 
          
   /*       for(i=0; i<k; i++)
                printf("\t    %d\t\t    %s\t\t%d\t\t    %d\t\t\t%d\t\t\t%s\n",cs_tab1[i].index, cs_tab1[i].critical_obj, cs_tab1[i].thread_func_index, cs_tab1[i].min_critical_location, cs_tab1[i].max_critical_location, thread_tab[cs_tab1[i].thread_func_index].func_name );
          printf("\t_________________________________________________________________________________________________________\n");
        */
        } //ELSE
}
/*ADDING LOCKS AND UNLOCKS*/
void add_lock_unlock(char *source_file_name,int preprocess_counter )
{
    char s[50], ch, dest_file_name[30]="cscheck_program.c";
    int index_count = 1,flag = 0;
	char sem_waitp[] = "\t //*** Insert synchronization mechanism here (by cs_check tool)";
	char sem_postp[] = "\t //*** Insert synchronization mechanism here (by cs_check tool)";
	FILE * output_file,*add_lock;
	int cs_tab_count = 0;
	char * line;
	ssize_t read;
	size_t len = 0;
	//printf("\n In add_lock %s source file name ",source_file_name);
	getchar();
	output_file = fopen( source_file_name, "r" );
		if(output_file == NULL)
		{
			printf("\n Error in reading input source file '%s'",source_file_name);
			return -1;

		}
		else
		{
			add_lock = fopen("temp_cs.c","w");
				if(add_lock == NULL) {
					printf("\nCan't Create output file ");
					return -1;
				}
				else {
							//printf("\n Pre counter %d \n cs_tab %d",preprocess_counter,cs_tab1[1].min_critical_location);
							printf("\n\t________________________________________________________________________________\n");
							printf("\n\t	Displaying Suspected Critical Section \n");
							printf("\n\t________________________________________________________________________________\n");
							while (( read = getline(&line,&len,output_file)) != -1) {
								//printf("\n %d %s \n",index_count,line);
								index_count++;
								// inserting
								if (index_count == cs_tab1[cs_tab_count].min_critical_location) {
									 printf("\n\t Index:\t   %d",cs_tab1[cs_tab_count].index);
									 printf("\n\t Shared Object:   %s",cs_tab1[cs_tab_count].critical_obj);
									 printf("\n\t Thread Function Index : %d",cs_tab1[cs_tab_count].thread_func_index);
									 printf("\n\t Starting location for critical section : %d",cs_tab1[cs_tab_count].min_critical_location);
									 printf("\n\t Ending location for critical section : %d",cs_tab1[cs_tab_count].max_critical_location); 		
									 printf("\n\t________________________________________________________________________________\n");
									 getchar();
									 printf("\n\t\t Printing actual critical section block");
									 printf("\n\t--------------------------------------------------------------------------------\n");
									 printf("\n\t Line Number \t Statement ");
									 printf("\n\t--------------------------------------------------------------------------------\n");
									 //printing to output file 
									 fprintf(add_lock,"%s",line);
									 fprintf(add_lock,"%s \n",sem_waitp);
									 flag  = 1;	
									continue;
								}
								if(flag == 1) {									
									printf("\n\t %d %s ",index_count,line);													
								}
								if(index_count-1 == cs_tab1[cs_tab_count].max_critical_location) {
											printf("\n\t--------------------------------------------------------------------------------\n");
											printf("\n\t________________________________________________________________________________\n");
											fprintf(add_lock," %s ",line); 
											fprintf(add_lock,"%s \n",sem_postp);
											
											cs_tab_count++;
											flag = 0;
											continue;
									}
										fprintf(add_lock," %s ",line);
								}
						}
		}
	fclose(output_file);
	fclose(add_lock);
	//printf("\n\n Press 1 for suggestion of sychronization for above critical section \n");
	//scanf("%d",&display_lock);
	//if(display_lock == 1) {		
		printf("\n Creating new file..... ");
		printf("\n File 'temp_cs.c' is created successfully and now displaying it ");
		getchar(); 
		system("less temp_cs.c");
		 
	//}/
}


void display_help()
{
        printf("\n\n NAME \n\t CRITICAL SECTION DETECTION - An application to automatically detect critical section in multithreaded environment.");
        printf("\n\n DISCRIPTION \n\t To design a GCC extension to identify the critical sections in multithreaded programs that lacks synchronization, which currently is not a feature in GCC (GNU Compiler Collection). The idea behind this technique is that compiler will automatically take care of the critical section by introducing Lock and Unlock function calls in a multithreaded program without involvement of the programmer.");

        printf("\n\n COMMAND LINE OPTIONS \n\t\t -h \t --help prints the usage for tool executable and exits.");
        printf("\n\t\t -a \t prints all tables with critical section(if any).");
        printf("\n\t\t -g \t prints global variable table ");
        printf("\n\t\t -f \t prints function table containing information about user defined functions.");
        printf("\n\t\t -L \t prints log information of variables used in funtions.");
        printf("\n\t\t -l \t printf local variable table.");
        printf("\n\t\t -t \t prints thread tablecontaining thread entries.");
        printf("\n\t\t -c \t prints critical section(if any)");
        printf("\n\t\t -p \t prints paarameter table containing all parameters defined in user defined functions.");
        printf("\n\t\t -s \t prints semaphore table.");
	printf("\n\t\t -m \t prints mutex table.");
	printf("\n\t\t -C \t prints Critical Section Region.");
}


int main(int argc, char *argv[])
{
	char * hdr_source, *source_path, *hdr_element;
	int i;
	char *source_file;
	if (strcmp(argv[1],"-h") == 0)
	{
		system("clear");
		display_help();
		return(0);
	}

	if (argc < 3)
	{
		printf("\n\n Error while processing command line!!!");
		return(0);
	}
	source_path = hdr_source = hdr_element = (char *)malloc(50 * sizeof(char));
	source_path = argv[2];

	init_cbr_stack(&cbr_stack); // initialize curlybrace stack

	yyin=fopen(argv[2],"r");
	yyparse();
	source_file = (char *)calloc(sizeof(char),strlen(argv[2])+1);
	strcpy(source_file,argv[2]);
	extract_archieve(source_path);

	for (i = 0; i < hdr_index; i++)
	{


		strcpy(hdr_source, source_path);
		hdr_element = headers[i];
		strcat(hdr_source,hdr_element);

		yyin = fopen(hdr_source,"r");
		yyparse();
	}

        
	create_main_thread();
	assign_func_index();
	check_thread_entry();
	check_threads();
	cs_check();
	system("clear");

	if (strcmp(argv[1],"-a") == 0)
	{
		display_global_variables();
		display_function();
		display_local_variables();
		getchar();
		display_func_paramtr();
		display_semaphr();
		display_mutex();
		getchar();
		display_thread();

		display_log();

		if(display_critical_section()) {
			create_cs_log();			
			add_lock_unlock(source_file,pre_counter);
		}
	}

	else if (strcmp(argv[1],"-g") == 0)
		display_global_variables();

	else if (strcmp(argv[1],"-f") == 0)
		display_function();

	else if (strcmp(argv[1],"-L") == 0)
		display_log();

	else if (strcmp(argv[1],"-l") == 0)
		display_local_variables();

	else if (strcmp(argv[1],"-t") == 0)
		display_thread();

	else if (strcmp(argv[1],"-p") == 0)
		display_func_paramtr();

	else if (strcmp(argv[1],"-c") == 0)
	{
		display_critical_section();
		create_cs_log();			
		add_lock_unlock(source_file,pre_counter);	
	}
	else if (strcmp(argv[1],"-s") == 0)
		display_semaphr();

	else if (strcmp(argv[1],"-h") == 0)
		display_help();

	else if (strcmp(argv[1],"-m") == 0)
		display_mutex();

	else if (strcmp(argv[1],"-C") == 0)
                add_lock_unlock(argv[2],pre_counter);
	else
		printf("\n\n Error in Input!!!");

	return 0;
}
