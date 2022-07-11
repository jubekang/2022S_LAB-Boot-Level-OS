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

LoadKernel:
    ; --------------------- : Define structure
    mov si, ReadPacket
    mov word[si],0x10       ; size - 'word' - word(2)
    mov word[si+2],100      ; number of sectors
    mov word[si+4],0        ; offset
    mov word[si+6],0x1000   ; segment -> 0x1000*16 + 0 = 0x10000 
                            ; => to express large value like 0x10000
    mov dword[si+8],6       ; address lo - 'dword' - Double word(4)
    mov dword[si+0xc],0     ; address hi
    ; --------------------- : End Def

    mov dl,[DriveId]
    mov ah,0x42
    int 0x13
    jc ReadError

GetMemInfoStart:
    mov eax,0xe820      ; service name
    mov edx,0x534d4150  ; ascii code for smap
    mov ecx,20          ; length of memory block
    mov dword[0x9000],0 ; initialize 4byte to 0
    mov edi,0x9008      ; information stored in address 9008
    xor ebx,ebx
    int 0x15
    jc NotSupport       ; service e820 is not available

GetMemInfo:
    add edi,20
    inc dword[0x9000]   ; count the number of getting memory block
    test ebx,ebx        ; if ebx is 0, it means that reach the end and jump to Done
    jz GetMemDone

    mov eax,0xe820      ; service name
    mov edx,0x534d4150  ; ascii code for smap
    mov ecx,20          ; length of memory block
    int 0x15
    jnc GetMemInfo      ; reach end of memory block

GetMemDone:

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
    lgdt [Gdt32Ptr] ; load gdt ptr -> 
    lidt [Idt32Ptr] ; load idt ptr => invaild here => reset

    mov eax,cr0     ; Entering protect mode
    or eax,1        ; Set first bit of cr0 to 1
    mov cr0,eax     ;

    jmp 8:PMEntry   ; To load code segment descriptor to cs register
                    ; 8 : index of selector
                    ; index = 00001 | TI = 0 | RPL = 00(== DPL) -> 8

ReadError:
NotSupport:
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
    
    mov dword[0x70000],0x71003  ; U | W | P = 0 1 1 == 3
                                ; reason why we setted up to 7 is after we jump to ring3, 
                                ; we accessed memory and write to screen buffer -> U should be 1 at that time
    mov dword[0x71000],10000111b; 7th bit to 1

    mov eax,(0xffff800000000000>>39)
    and eax,0x1ff
    mov dword[0x70000+eax*8],0x72003
    mov dword[0x72000],10000111b
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
    mov rdi,0x200000    ; destination address is stored in rdi
    mov rsi,0x10000     ; source address is stored in rsi
    mov rcx,51200/8     ; rcx as a counter => copy 51200 q-word byte(read 100 sectors which is 512B)
    rep movsq           ; kernel is in 0x10000 and copied to 0x2000000

    mov rax,0xffff800000200000
    jmp rax        ; jump to kernel

LEnd:
    hlt
    jmp LEnd

DriveId:    db 0
ReadPacket: times 16 db 0

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