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
    xor ebx,ebx
    int 0x15
    jc NotSupport       ; service e820 is not available

GetMemInfo:
    add edi,20
    mov eax,0xe820      ; service name
    mov edx,0x534d4150  ; ascii code for smap
    mov ecx,20          ; length of memory block
    int 0x15
    jc GEtMemdone       ; reach end of memory block

    test ebx,ebx
    jnz GetMemInfo

GEtMemdone:

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

    mov byte[0xb8000],'P'   ; print 'P'
    mov byte[0xb8001],0xc

PEnd:
    hlt
    jmp PEnd

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