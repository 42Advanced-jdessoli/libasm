bits 64

section .text
    global ft_strlen

ft_strlen:
    mov rax, 0 ; rax is the default return val, we set it to 0

.loop:
    cmp byte [rdi + rax], 0 ; same logic as str + i
    je .done ; je means jump if equal, see ZF flag for more
    inc rax
    jmp .loop

.done:
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
