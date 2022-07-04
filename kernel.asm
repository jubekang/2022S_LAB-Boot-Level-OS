[BITS 64]
[ORG 0x200000]

start:
    mov byte[0xb8000],'K'
    mov byte[0xb8001],0xc

End:
    hlt
    jmp End