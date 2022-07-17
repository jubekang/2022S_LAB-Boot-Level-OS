section .text
global writeu
global sleepu
global exitu
global waitu
global keyboard_readu
global get_total_memoryu

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
    sub rsp,8       ; 
    mov eax,1       ; index number is 1

    mov [rsp],rdi
    mov rdi,1       ; 1 argument
    mov rsi,rsp

    int 0x80

    add rsp,8
    ret

exitu:
    ; no argument passing

    mov eax,2
    mov rdi,0       ; 0 argument

    int 0x80

    ret ; normally, not ret from exit

waitu:
    mov eax,3
    mov rdi,0       ; 0 argument

    int 0x80

    ret

keyboard_readu:
    mov eax,4
    xor edi,edi

    int 0x80

    ret

get_total_memoryu:
    mov eax,5
    xor edi,edi

    int 0x80

    ret