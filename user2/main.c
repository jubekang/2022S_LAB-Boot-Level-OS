#include "lib.h"
#include "stdint.h"

int main(void)
{   
    char *p = (char *)0xffff800000200200;
    /* touch kernel region in user program -> exception */
    *p = 1;
    /* should terminate here */
    printf("process2\n");
    sleepu(100);

    return 0;
}