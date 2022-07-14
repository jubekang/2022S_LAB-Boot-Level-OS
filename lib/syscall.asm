section .text
global writeu
global sleepu

writeu:
    sub rsp,16
    xor eax,eax     ; rax holds the index number of system call function -> index 0 for write screen function

    mov [rsp],rdi   ; copy first and second arguments to the new allocated space
    mov [rsp+8],rsi
    
    mov rdi,2       ; rdi holds the number of arguments
    mov rsi,rsp     ; rsi points to the address of arguments
    int 0x80

    add rsp,16
    ret

sleepu:
    sub rsp,8
    mov eax,1

    mov [rsp],rdi
    mov rdi,1
    mov rsi,rsp

    int 0x80

    add rsp,8
    ret