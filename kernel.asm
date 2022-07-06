[BITS 64]
[ORG 0x200000]

start:
    mov rdi,Idt         ; hold address of IDT desc
    
    mov rax,Handler0    ; stores the offset of handler0
    mov [rdi],ax        ; copy handler0's address to Idt
    shr rax,16
    mov [rdi+6],ax
    shr rax,16
    mov [rdi+8],eax

    mov rax,Timer       ; set Interrupts 32 handler desc
    add rdi,32*16
    mov [rdi],ax
    shr rax,16
    mov [rdi+6],ax
    shr rax,16
    mov [rdi+8],eax

    lgdt [Gdt64Ptr]     ; load Gdt pointer
    lidt [IdtPtr]

SetTss:
    mov rax,Tss         
    mov [TssDesc+2],ax  ; lower 16 bits of the address in the 3th byte in desc
    shr rax,16
    mov [TssDesc+4],al  ; 16-23 bits of the address in the 5th byte in desc
    shr rax,8
    mov [TssDesc+7],al  ; next 8 bits of the address in the 8th byte in desc
    shr rax,8
    mov [TssDesc+8],eax ; last 32 bits of the address in the 9th byte in desc

    ; Descriptor is set here

    mov ax,0x20         ; selector we use is 0x20
    ltr ax              ; load task register inst'

    push 8              ; code segment discriptor is second entry of gdt
    push KernelEntry    ; return address
    db 0x48             ; default operand size of far ret is 32 bit => override prefix 48 to make 64 bit
    retf                ; load code segment descriptor in cs register : use far return

KernelEntry:
    mov byte[0xb8000],'K'
    mov byte[0xb8001],0xc

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

    ; sti

    push 0x18|3     ; ss selector : DPL is 3 | stack segment selector is 18
    push 0x7c00     ; RSP
    push 0x202      ; Rflags : set bit 1 to 1 + 9 bit to 1 for interrupt flag to enable interrupt
    push 0x10|3     ; cs selector DPL is 3 | code segment selector is 10
    push UserEntry  ; RIP : return address
    iretq           ; interrupt return

End:
    hlt
    jmp End

UserEntry:
    ; mov ax,cs   ; check lower 2 bit of cs to check DPL
    ; and al,11b
    ; cmp al,3    ; check whether DPL is 3
    ; jne UEnd    ; if not in ring 3, jump

    inc byte[0xb8010]       ; in Ring3
    mov byte[0xb8011],0xf

UEnd:
    jmp UserEntry

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

    inc byte[0xb8020]
    mov byte[0xb8021],0xe
    
    mov al,0x20 ; command register of the PIC
    out 0x20,al
   
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
    dq 0x0020f80000000000   ; DPL 00 -> 11
    dq 0x0020f20000000000   ; DPL 00 -> 11 / present bit 1 -> data seegment descriptor
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

Tss:
    dd 0            ; first 4 byte are reserved
    dq 0x150000     ; RSP : new address to TSS loaded
    times 88 db 0   ; not used
    dd TssLen       ; size of Tss + IO permission bitmap is not used

TssLen: equ $-Tss