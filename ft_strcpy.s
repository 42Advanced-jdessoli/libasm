bits 64

section .text
    global ft_strcpy

ft_strcpy:
    xor rcx, rcx ; using rcx for storing index, since we'll need rax for the ret
    mov rax, rdi ; saving the dest pointer initial pos in ret val

.loop:
    mov dl, byte [rsi + rcx] ; get byte from src, using dl from rdx instead of al to keep rax memory safe
    mov byte [rdi + rcx], dl ; put byte in dest
    cmp dl, 0 ; checking if the copied byte is NULL
    je .done
    inc rcx
    jmp .loop


.done:
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
