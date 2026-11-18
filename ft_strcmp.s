bits 64

section .text
    global ft_strcmp

ft_strcmp:
    mov rcx, 0 ;

.loop:
    mov al, byte [rdi + rcx]
    mov dl, byte [rsi + rcx]
    cmp al, 0 ; checking if s1 is at NULL
    je .done
    cmp al, dl
    jne .done ; jne means jump if not equal
    inc rcx
    jmp .loop

.done:
    movzx rax, al ; movzx extend a 8 bits val to 64 bits register, which avoid keeping garbage in the 64 bits ret val
    movzx rdx, dl ; this is necessary because we must return an int in C, i wouln't be with a char
    sub rax, rdx
    ret
