[BITS 16]
[ORG 0x7e00]    ; 0x7c00 + 0x200(512byte)

start:  ; use same print function for simple program
    mov [DriveId],dl

    mov eax,0x80000000  ; check weather cpu support 0x80000001
    cpuid               ; return processor identification and feature info to edx
    cmp eax,0x80000001
    jb NotSupport       ; if eax is less than 0x80000001

    mov eax,0x80000001
    cpuid
    test edx,(1<<29)    ; long mode support bit
    jz NotSupport       ; return processor identification and feature info to edx
    test edx,(1<<26)    ; 1g page suppport bit
    jz NotSupport

    mov ax,0x2000
    mov es,ax           ; es = 0x20000

GetMemInfoStart:
    mov eax,0xe820      ; service name
    mov edx,0x534d4150  ; ascii code for smap
    mov ecx,20          ; length of memory block
    mov dword[es:0],0   ; initialize 0x20000 4byte to 0

    mov edi,8           ; es di pointing to 0x20008
    xor ebx,ebx
    int 0x15
    jc NotSupport       ; service e820 is not available

GetMemInfo:                 ; check each block if it's free region
    cmp dword[es:di+16],1   ; offset 16 : memory type -> if it not 1, it is not free region
    jne Cont
    cmp dword[es:di+4],0    ; offset 4 : higher part of address -> if is not zero, larger than 4GB
    jne Cont
    mov eax,[es:di]         ; lower part of address -> if is bigger than 0x30000000, it is not wanted region
    cmp eax,0x30000000
    ja Cont
    cmp dword[es:di+12],0   ; higher part of length : larger than 4GB
    jne Find
    add eax,[es:di+8]       ; lower part of length : smaller than 100MB which is size of image
    cmp eax,0x30000000 + 100*1024*1024
    jb Cont

Find:
    mov byte[LoadImage],1   ; if it's 1, we found

Cont:
    add edi,20
    inc dword[es:0]     ; count the number of getting memory block
    test ebx,ebx        ; if ebx is 0, it means that reach the end and jump to Done
    jz GetMemDone

    mov eax,0xe820      ; service name
    mov edx,0x534d4150  ; ascii code for smap
    mov ecx,20          ; length of memory block
    int 0x15
    jnc GetMemInfo      ; reach end of memory block

GetMemDone:
    cmp byte[LoadImage],1
    jne ReadError

TestA20:
    mov ax,0xffff
    mov es,ax
    mov word[ds:0x7c00],0xa200  ; 0:0x7c00 -> 0x7c00
    cmp word[es:0x7c10],0xa200  ; 0xffff:0x7c10 -> 0x107c00
                                ; if content is not eqaul, suceesfully access to 107c00 
    jne SetA20LineDone

    mov word[0x7c00],0xb200     ; second test : if original value of word[es:0x7c10] is 0xa200
    cmp word[es:0x7c10],0xb200
    je End                      ; if not same, a20 is on

SetA20LineDone:
    xor ax, ax
    mov es, ax

SetVideoMode:
    mov ax,3        ; ah 0 : viedo mode / al 3 : text mode
    int 0x10        ; text mode

    ; Set protect mode 
    cli             ; clear interrupt flag
    lgdt [Gdt32Ptr] ; load gdt ptr

    mov eax,cr0     ; Entering protect mode
    or eax,1        ; Set first bit of cr0 to 1
    mov cr0,eax     ;

LoadFS:             ; unlimit 4GB in FS
    mov ax,0x10     ; move 16 to fs
    mov fs,ax

    mov eax,cr0     ; back to real mode
    and al,0xfe
    mov cr0,eax

BigRealMode:
    sti
    mov cx,203*16*63/100    ; total 100 sector, cx act as a counter
    xor ebx,ebx             ; clear bx
    mov edi,0x30000000      ; address of high memory where we want to place file system
    xor ax,ax               ; clear fs
    mov fs,ax

ReadFAT:
    push ecx                ; save registers
    push ebx
    push edi
    push fs
    
    mov ax,100
    call ReadSectors
    test al,al
    jnz  ReadError

    pop fs
    pop edi
    pop ebx

    mov cx,512*100/4
    mov esi,0x60000
    
CopyData:
    mov eax,[fs:esi]
    mov [fs:edi],eax

    add esi,4
    add edi,4
    loop CopyData

    pop ecx

    add ebx,100
    loop ReadFAT

ReadRemainingSectors:
    push edi
    push fs

    mov ax,(203*16*63) % 100
    call ReadSectors
    test al,al
    jnz  ReadError

    pop fs
    pop edi
    
    mov cx,(((203*16*63) % 100) * 512)/4
    mov esi,0x60000

CopyRemainingData: 
    mov eax,[fs:esi]
    mov [fs:edi],eax

    add esi,4
    add edi,4
    loop CopyRemainingData


    cli
    lidt [Idt32Ptr]

    mov eax,cr0     ; switch to protected mode
    or eax,1
    mov cr0,eax

    jmp 8:PMEntry   ; To load code segment descriptor to cs register
                    ; 8 : index of selector
                    ; index = 00001 | TI = 0 | RPL = 00(== DPL) -> 8

ReadSectors:
    mov si,ReadPacket
    mov word[si],0x10
    mov word[si+2],ax
    mov word[si+4],0
    mov word[si+6],0x6000
    mov dword[si+8],ebx
    mov dword[si+0xc],0
    mov dl,[DriveId]
    mov ah,0x42
    int 0x13
    
    setc al     ; set al 1 if carry flag is set
    ret


ReadError:
NotSupport:
    mov ah,0x13
    mov al,1
    mov bx,0xa
    xor dx,dx
    mov bp,Message
    mov cx,MessageLen 
    int 0x10

End:
    hlt
    jmp End

[BITS 32]

PMEntry:
    mov ax,0x10 ; init all segment register
    mov ds,ax
    mov es,ax
    mov ss,ax
    mov esp,0x7c00

    ;---------------------  : find a free memory area and inititialize the paging structure
    cld
    mov edi,0x70000         ; value of cr3 is 0x70000
    xor eax,eax
    mov ecx,0x10000/4
    rep stosd
    
    mov dword[0x70000],0x71007  ; U | W | P = 1 1 1 == 7
                                ; reason why we setted up to 7 is after we jump to ring3, 
                                ; we accessed memory and write to screen buffer -> U should be 1 at that time
    mov dword[0x71000],10000111b; 7th bit to 1

    mov eax,(0xffff800000000000>>39)
    and eax,0x1ff
    mov dword[0x70000+eax*8],0x72003
    mov dword[0x72000],10000011b
    ;-----------------------

    lgdt [Gdt64Ptr]     ; set gdt pointer

    mov eax,cr4         
    or eax,(1<<5)       ; set physical address extension bit(5)
    mov cr4,eax

    mov eax,0x70000     ; set cr3 to 0x80000 -> using physical address
    mov cr3,eax

    mov ecx,0xc0000080  
    rdmsr               ; read msr : ret value is eax
    or eax,(1<<8)       ; enable long mode
    wrmsr               ; write msr

    mov eax,cr0
    or eax,(1<<31)      ; enable page setting -> virtual memory from here
    mov cr0,eax

    jmp 8:LMEntry       ; To load code segment descriptor to cs register
                        ; 8 : index of selector
                        ; index = 00001 | TI = 0 | RPL = 00(== DPL) -> 8

PEnd:
    hlt
    jmp PEnd

[BITS 64]
LMEntry:                ; Start of LONG_MODE
    mov rsp,0x7c00      ; init stack pointer

    cld                 ; clear direction flag : data is copied to forward direction
    mov rdi,0x100000    ; destination address is stored in rdi
    mov rsi,CModule     ; source address is stored in rsi
    mov rcx,512*15/8    ; rcx as a counter => copy 512*15 q-word byte(read 100 sectors which is 512B)
    rep movsq           ; kernel is in 0x10000 and copied to 0x1000000

    mov rax,0xffff800000100000
    jmp rax        ; jump to kernel

LEnd:
    hlt
    jmp LEnd


Message:    db "We have an error in boot process"
MessageLen: equ $-Message

DriveId:    db 0
ReadPacket: times 16 db 0
LoadImage:  db 0

Gdt32:
    dq 0        ; First Discriptor to NULL

Code32:         ; Second Discriptor
    dw 0xffff   ; segment size -> set to maximum
    dw 0        ; base address -> 0 -> code segment start from 0
    db 0        ; base address -> 0

    db 0x9a     ; P = 1 | DPL = 00 | S = 1 | TYPE = 1010 -> 0x9a
                ; P(1) : should be 1 when we load the descriptor / OW exception 
                ; DPL(00) : privilege level of the segment
                ; S(1) : code or data segment / or system segment
                ; TYPE(1010 or 10) : non-conforming code segment

    db 0xcf     ; G = 1 | D = 1 | 0 | A = 0 | LIMIT = 1111 -> 0xcf
                ; G(1) : Granularity bit -> size field scaled by 4KB => 4GB
                ; D(1) : 32 or 16 -> 32 here
                ; A(0) : used by system software
                ; LIMIT(1111) : maximum size
    db 0        ; 8 bits of base address

Data32:         ; Third Discriptor
    dw 0xffff
    dw 0
    db 0
    db 0x92     ; TYPE is only difference : 1010 -> 0010 => readable and writeable segment
    db 0xcf
    db 0

Gdt32Len:   equ $-Gdt32
    
Gdt32Ptr:   dw Gdt32Len-1
            dd Gdt32

Idt32Ptr:   dw 0    ; invaild Ptr 0
            dd 0    ; To make non-recoverable hadeware error

Gdt64:
    dq 0
    dq 0x0020980000000000
    ; D = 0 | L = 1 | P = 1 | DPL = 00 | 1 | 1 | C = 0
    ; C(0) : non/conforming bit
    ; 1's : code segment descriptor
    ; DPL : level 0
    ; Present bit : 1 - 64bit / 0 - compatibility mode
    ; D : 0 when long bit is set
    ; if there is no plan to ring3, don't need data segment

Gdt64Len: equ $-Gdt64

Gdt64Ptr: dw Gdt64Len-1
          dd Gdt64

CModule: