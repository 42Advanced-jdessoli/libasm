bits 64

global ft_strdup
extern ft_strlen
extern ft_strcpy
extern malloc

section .text
ft_strdup:
    ; On entry rsp % 16 == 8 (the `call` pushed an 8-byte return addr) ;
    ; ONE push of 8 bytes brings us back to rsp % 16 == 0, which malloc requires ;
    ; (two pushes would put us back at % 16 == 8 -> misaligned) ;
    push rdi                ; Saving const char *s initial pos on the stack

    call ft_strlen          ; loading rax with s len

    inc rax                 ; adding 1 to rax to account for the closing '\0'
    mov rdi, rax            ; moving to rdi the size needed to malloc the str

    call malloc wrt ..plt   ; malloc sets errno to ENOMEM itself on failure

    test rax, rax           ; checking if malloc failed, so returned 0 / NULL
    jz .malloc_error

    ; if malloc succeeded, it stored in rax the addr of the new memory ;
    ; ft_strcpy(dest = rax, src = s) -> it returns dest in rax, which is exactly what we return ;
    mov rdi, rax
    pop rsi                 ; src = s. Stack is now back to its entry state ;
    jmp ft_strcpy           ; tail call : ft_strcpy's `ret` returns straight to our caller ;

.malloc_error:
    pop rdi                 ; get the const char *s ptr out of the stack (balance)
    xor rax, rax            ; return NULL
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
