section .text
global memset
global memcpy
global memmove
global memcmp

memset:         ; rdi(buffer), rsi(value), rdx(size)
    cld         ; clear the direction flag -> copy data from low to high
    mov ecx,edx ; move size to ecx
    mov al,sil  ; value is 8 bit -> move to rax
    rep stosb   ; copy the value in al to the memory address by rdi(until ecx is zero)
    ret

memcmp:         ; rdi(src1), rsi(src2), rdx(size)
    cld
    xor eax,eax ; clear ax
    mov ecx,edx ; move size to ecx
    rep cmpsb   ; compare memory and set eflags -> if they are equal and ecx is non-zero, repeat
    setnz al    ; set ax 1 if zero flag is 0
    ret

memcpy:         ; rdi(dst), rsi(src), rdx(size)
memmove:        ; if region is overlap and dst(rdi) > src(rsi) -> copy from backward
    cld
    cmp rsi,rdi
    jae .copy
    mov r8,rsi
    add r8,rdx  ; r8 = src + size
    cmp r8,rdi  
    jbe .copy

.overlap:   ; copy from backward
    std     ; set direction flag copy the data from high memory to low memory(<=>cld)
    add rdi,rdx
    add rsi,rdx
    sub rdi,1
    sub rsi,1

.copy:
    mov ecx,edx
    rep movsb
    cld
    ret



