bits 64

global ft_strdup
extern ft_strlen
extern malloc
extern __errno_location

section .text
ft_strdup:
    ; those two push are needed because we need to align memory ;
    ; We have 16 bits, 8 + 8, instead of only 8 bits. This avoid random segfault because of malloc ;
    push rbx
    push rdi                ; Saving const char *s initial pos on the stack

    call ft_strlen          ; loading rax with s len

    inc rax                 ; adding 1 to rax to account for the closing '\0'
    mov rdi, rax            ; moving to rdi the size needed to malloc the str

    call malloc wrt ..plt

    cmp rax, 0              ; checking if malloc failed, so returned 0 / NULL
    je .malloc_error

    ; if malloc succeeded, it stored in rax the addr of the newly emptied memory ;
    ; so moving rax content in rdi means making rdi the dest of strcpy ;
    ; pop get the src ptr out of the stack, and into rsi. So now we have rsi for src ptr, and rdi for dest ptr ;
    ; push rdi is to save dest ptr on the stack, since calling strcpy will overwrite rdi with the content for rsi ;
    mov rdi, rax
    pop rsi
    push rdi

    call ft_strcpy

    pop rax                 ; getting the ptr from the stack and storing it into rax ;
    pop rbx                 ; pop rbx for stack balancing. Huge topic. ;
    ret

.malloc_error:
    pop rdi                 ; get the const char *s ptr out of the stack
    pop rbx

    mov rax, 0
    ret
