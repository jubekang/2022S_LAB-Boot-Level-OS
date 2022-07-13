; Code Initializing the TSS, PIT, PIC

section .data

global Tss

Gdt64:
    dq 0
    dq 0x0020980000000000
    dq 0x0020f80000000000   ; DPL 00 -> 11
    dq 0x0000f20000000000   ; DPL 00 -> 11 / present bit 1 -> data seegment descriptor
TssDesc:
    dw TssLen-1 ; Tss limit
    dw 0        ; lower 24 bits of the base address
    db 0
    db 0x89     ; P(1) DPL(00) MODE(01001) -> 64bit Tss
    db 0
    db 0
    dq 0

Gdt64Len: equ $-Gdt64


Gdt64Ptr: dw Gdt64Len-1
          dq Gdt64      ; base address is 8byte

Tss:
    dd 0            ; first 4 byte are reserved
    dq 0xffff800000190000     ; RSP : new address to TSS loaded
    times 88 db 0   ; not used
    dd TssLen       ; size of Tss + IO permission bitmap is not used

TssLen: equ $-Tss

section .text

extern KMain
global start


start:
    mov rax,Gdt64Ptr
    lgdt [rax]     ; load Gdt pointer

SetTss:
    mov rax,Tss 
    mov rdi,TssDesc        
    mov [rdi+2],ax  ; lower 16 bits of the address in the 3th byte in desc
    shr rax,16
    mov [rdi+4],al  ; 16-23 bits of the address in the 5th byte in desc
    shr rax,8
    mov [rdi+7],al  ; next 8 bits of the address in the 8th byte in desc
    shr rax,8
    mov [rdi+8],eax ; last 32 bits of the address in the 9th byte in desc

    mov ax,0x20         ; selector we use is 0x20
    ltr ax              ; load task register inst'

InitPIT:                    ; Programmable Interval Timer ; only using channel 0
    mov al,(1<<2)|(3<<4)    ; setting => 76 - channel | 54 - access mode | 321 - operating mode | 0 - binary/BCD => 00 11 010 0
    out 0x43,al             ; address of mode command register is 43 => use "out" command to write the register

    mov ax,11931            ; 1193182/100 -> to make 100Hz
    out 0x40,al             ; address of data register
    mov al,ah               
    out 0x40,al

InitPIC:        ; Programmable Interval Controller(PIT use IRQ0)
    mov al,0x11 ; Initialization Command Word => bit 0 - we use last init command word / bit 4 - we write following three init command ??
    out 0x20,al ; command register of master
    out 0xa0,al ; command register of slave
 
    mov al,32   ; starting vector number 32 => IRQ 0 = 32 / IRQ 1 = 33 ... [32-255]
    out 0x21,al ; data register of master
    mov al,40   ; starting vector number 40(39 for IRQ 7 of slave)
    out 0xa1,al ; data register of slave

    mov al,4    ; IRQ 2 is used in master (bit 2)
    out 0x21,al
    mov al,2    ; identification in slave(2)
    out 0xa1,al

    mov al,1    ; end of interrupt
    out 0x21,al
    out 0xa1,al

    mov al,11111110b    ; only IRQ0 is used(fire interrupt)
    out 0x21,al
    mov al,11111111b
    out 0xa1,al

    mov rax,KernelEntry
    push 8              ; code segment discriptor is second entry of gdt
    push rax    ; return address
    db 0x48             ; default operand size of far ret is 32 bit => override prefix 48 to make 64 bit
    retf                ; load code segment descriptor in cs register : use far return

KernelEntry:    ; jump to main function in C

    mov rsp,0xffff800000200000
    call KMain

End:
    hlt
    jmp End