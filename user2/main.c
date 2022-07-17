#include "lib.h"
#include "console.h"
#include "stdint.h"

static char *global_buffer;

static void set_buffer(char *buffer)
{
    global_buffer = buffer;
}

static char* get_buffer(void)
{
    return global_buffer;
}

static void cmd_get_total_memory(void)
{
    uint64_t total;
    
    total = get_total_memoryu();
    printf("Total Memory is %dMB\n", total);
}

static void cmd_echo(void)
{
    printf("%s\n", get_buffer()+5);
}

static int read_cmd(char *buffer)
{
    char ch[2] = { 0 };
    int buffer_size = 0;

    while (1) {
        ch[0] = keyboard_readu();
        
        if (ch[0] == '\n' || buffer_size >= 80) {
            printf("%s", ch); /* it is command */
            break;
        }
        else if (ch[0] == '\b') {    
            if (buffer_size > 0) {
                buffer_size--;
                printf("%s", ch);    
            }           
        }          
        else {     
            buffer[buffer_size++] = ch[0]; 
            printf("%s", ch);        
        }
    }

    return buffer_size;
}

static int parse_cmd(char *buffer, int buffer_size)
{
    int cmd = -1;

    if (buffer_size == 8 && (!memcmp("totalmem", buffer, 8))) {
        cmd = 0;
    }

    if (buffer_size >= 4  && (!memcmp("echo", buffer, 4))) {
        cmd = 1;
        set_buffer(buffer);
    }

    return cmd;
}

static void execute_cmd(int cmd)
{ 
    CmdFunc cmd_list[2] = {cmd_get_total_memory, cmd_echo};
    
    if (cmd == 0) {       
        cmd_list[0]();
    }
    else if (cmd == 1) {
        cmd_list[1]();
    }
}

int main(void)
{
    char buffer[80] = { 0 };
    int buffer_size = 0;
    int cmd = 0; /* index of the commands */

    printf("\n");

    while (1) {
        printf("$ ");
        buffer_size = read_cmd(buffer);

        if (buffer_size == 0) {
            continue;
        }
        
        cmd = parse_cmd(buffer, buffer_size);
        
        if (cmd < 0) {
            printf("Command Not Found!\n");
        }
        else {
            execute_cmd(cmd);             
        }            
    }

    return 0;
}