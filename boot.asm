[BITS 16]   ; boot code is running at 16-bit mode
[ORG 0x7c00]    ; code running at memory address 0x7c00

start:
    xor ax,ax   ; set ax to 0
    mov ds,ax   ; ds = 0
    mov es,ax   ; es = 0
    mov ss,ax   ; ss = 0
    mov sp,0x7c00   ; set stack pointer to 0x7c00 (0x7bfe)

TeskDiskExtension:
    mov [DriveId],dl
    mov ah,0x41 ; ax to 41
    mov bx,0x55aa   ; bx to 0x55aa
    int 0x13    
    jc NotSupport   ; when disk extension is not supported
    cmp bx,0xaa55   
    jne NotSupport  ; when disk extension was not supported

LoadLoader:
    mov si, ReadPacket  ; set offset
    ; --------------------- : Define structure
    mov word[si],0x10       ; size - 'word' - word(2)
    mov word[si+2],5        ; number of sectors
    mov word[si+4],0x7e00   ; offset
    mov word[si+6],0        ; segment -> 0*16 + 0x7e00 = 0x7e00
    mov dword[si+8],1       ; address lo - 'dword' - Double word(4)
    mov dword[si+0xc],0     ; address hi
    ; --------------------- : End Def
    mov dl,[DriveId]    ; save Drive ID
    mov ah,0x42 ; function code 0x42 : want to use disk extension service
    int 0x13
    jc ReadError    ; when disk extension is not supported

    mov dl,[DriveId]
    jmp 0x7e00  ; To new asm file : loader.asm

ReadError:
NotSupport:
    mov ah,0x13 ; function code 0x13 : print string
    mov al,1    ; write mode 1 : cursor placed at the end of string
    mov bx,0xa  ; bh : page number / bl : info of character attributes(color etc)
    xor dx,dx   ; dh : rows / dl : columns -> print at beginning of the screen => (0,0)
    mov bp,Message  ; bp : address of string + copy needs bracket (Ex.[Message])
    mov cx,MessageLen   ; cx : copy of number of characters
    int 0x10    ; call interrupt to call specific BIOS service

End:
    hlt
    jmp End
     
DriveId :   db 0
Message:    db "We have an error in boot process"
MessageLen: equ $-Message   ; $ represents end of string and "Message" represents start of string
ReadPacket: times 15 db 0

times (0x1be-($-$$)) db 0   ; times dp repeated : ($-$$) - size from start of code to end of message

    db 80h      ; boot indicator
    db 0,2,0    ; starting CHS
    db 0f0h     ; type
    db 0ffh,0ffh,0ffh   ; ending CHS
    dd 1        ; starting sector
    dd (20*16*63-1) ; size
	
    times (16*3) db 0

    db 0x55
    db 0xaa

	
