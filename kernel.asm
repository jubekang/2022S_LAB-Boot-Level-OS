[BITS 64]
[ORG 0x200000]

start:
    mov rdi,Idt         ; hold address of IDT
    mov rax,handler0    ; stores the offset of handler0

    mov [rdi],ax        ; copy handler0's address to Idt
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

    xor rbx,rbx
    div rbx             ; Divide by 0

End:
    hlt
    jmp End

handler0:
    mov byte[0xb8000],'D'
    mov byte[0xb8001],0xd

    jmp End

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
        dw 0x8  ; Selector
        db 0    ; IST 
        db 0x8e ; Attributes : P | DPL | TYPE = 1 | 00 | 01110
        db 0    ; Offset -> 16~31 offset
        dw 0    ; Offset
        dd 0    ; Offset -> 32~63 offset
        dd 0    ; 
    %endrep

IdtLen: equ $-Idt

IdtPtr: dw IdtLen-1
        dq Idt
