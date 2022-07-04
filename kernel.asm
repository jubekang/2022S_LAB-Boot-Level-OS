[BITS 64]
[ORG 0x200000]

start:
    mov rdi,Idt         ; hold address of IDT
    
    mov rax,Handler0    ; stores the offset of handler0
    mov [rdi],ax        ; copy handler0's address to Idt
    shr rax,16
    mov [rdi+6],ax
    shr rax,16
    mov [rdi+8],eax

    mov rax,Timer       ; set Interrupts 32 handler
    add rdi,32*16
    mov [rdi],ax
    shr rax,16
    mov [rdi+6],ax
    shr rax,16
    mov [rdi+8],eax

    lgdt [Gdt64Ptr]     ; load Gdt pointer
    lidt [IdtPtr]

    push 8              ; code segment discriptor is second entry of gdt
    push KernelEntry    ; return address
    db 0x48             ; default operand size of far ret is 32 bit => override prefix 48 to make 64 bit
    retf                ; load code segment descriptor in cs register : use far return

KernelEntry:
    mov byte[0xb8000],'K'
    mov byte[0xb8001],0xc

InitPIT:        ; Programmable Interval Timer
    mov al,(1<<2)|(3<<4)
    out 0x43,al

    mov ax,11931
    out 0x40,al
    mov al,ah
    out 0x40,al

InitPIC:        ; Programmable Interval Controller
    mov al,0x11 ; Initialization Command Word
    out 0x20,al ; master
    out 0xa0,al ; slave

    mov al,32   ; vector 32
    out 0x21,al
    mov al,40
    out 0xa1,al

    mov al,4
    out 0x21,al
    mov al,2
    out 0xa1,al

    mov al,1
    out 0x21,al
    out 0xa1,al

    mov al,11111110b
    out 0x21,al
    mov al,11111111b
    out 0xa1,al

    sti

End:
    hlt
    jmp End

Handler0:

    ; saving all registers
    push rax
    push rbx  
    push rcx
    push rdx  	  
    push rsi
    push rdi
    push rbp
    push r8
    push r9
    push r10
    push r11
    push r12
    push r13
    push r14
    push r15
    
    mov byte[0xb8000],'D'
    mov byte[0xb8001],0xd

    jmp End

    pop	r15
    pop	r14
    pop	r13
    pop	r12
    pop	r11
    pop	r10
    pop	r9
    pop	r8
    pop	rbp
    pop	rdi
    pop	rsi  
    pop	rdx
    pop	rcx
    pop	rbx
    pop	rax

    iretq

Timer:
    push rax
    push rbx  
    push rcx
    push rdx  	  
    push rsi
    push rdi
    push rbp
    push r8
    push r9
    push r10
    push r11
    push r12
    push r13
    push r14
    push r15

    mov byte[0xb8020],'T'
    mov byte[0xb8021],0xe
    jmp End
   
    pop	r15
    pop	r14
    pop	r13
    pop	r12
    pop	r11
    pop	r10
    pop	r9
    pop	r8
    pop	rbp
    pop	rdi
    pop	rsi  
    pop	rdx
    pop	rcx
    pop	rbx
    pop	rax

    iretq

Gdt64:
    dq 0
    dq 0x0020980000000000

Gdt64Len: equ $-Gdt64


Gdt64Ptr: dw Gdt64Len-1
          dq Gdt64      ; base address is 8byte


Idt:
    %rep 256
        dw 0    ; Offset -> 0~15 offset
        dw 0x8  ; selector
        db 0    ; IST
        db 0x8e ; Attributes : P | DPL | TYPE = 1 | 00 | 01110
        dw 0    ; Offset -> 16~31 offset
        dd 0    ; Offset
        dd 0
    %endrep

IdtLen: equ $-Idt

IdtPtr: dw IdtLen-1
        dq Idt