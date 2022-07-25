#include "lib.h"
#include "stdint.h"

int main(void)
{   
    int fd;
    int size;
    char buffer[100] = {0};

    if((fd = open_file("TEST.BIN")) == -1){
        printf("open file failed");
    }
    else{
        size = get_file_size(fd);
        size = read_file(fd, buffer, size);
        printf("%s\n", buffer);
        printf("read %db in total", size);
    }
    while(1){}
    return 0;
}