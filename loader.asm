[BITS 16]
[ORG 0x7e00]    ; 0x7c00 + 0x200(512byte)


;   strucure of memory block(20) when int 15
;   offset  | field
;
;   0       | base address(8)  
;   8       | length(8)
;   16      | type(4)


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
    mov ax,3    ; ah 0 : viedo mode / al 3 : text mode
    int 0x10    ; text mode
    
    ;   two byte per character 
    ;   high : Character / Low : Background | Foreground color

    mov si,Message  ; save address of characters
    mov ax,0xb800   ; text mode address 
    mov es,ax       ;
    xor di,di       ;
    mov cx,MessageLen   

PrintMessage:
    mov al,[si]             ; copy the character of message
    mov [es:di],al          ; map to the screen
    mov byte[es:di+1],0xc   ; color

    add di,2                ; character takes 2 bytes
    add si,1                ; character stored in message takes 1 bytes
    loop PrintMessage

ReadError:
NotSupport:
End:
    hlt
    jmp End

DriveId:    db 0
Message:    db "Text mode is set"
MessageLen: equ $-Message
ReadPacket: times 16 db 0