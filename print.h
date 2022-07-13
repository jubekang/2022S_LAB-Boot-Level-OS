#ifndef _PRINT_H_
#define _PRINT_H_

#define LINE_SIZE 160   /* 80 character each line and 2B each */

struct ScreenBuffer {
    char *buffer;       /* address of screen buffer */
    int column;         /* where to print message */
    int row;
};

int printk(const char *format, ... );
void write_screen(const char *buffer, int size, char color);


#endif