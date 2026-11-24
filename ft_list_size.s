section .text
    global ft_list_size

; Expected t_list structure (16 bytes on 64-bit):
; offset 0 : void          *data
; offset 8 : struct s_list *next
;
; Argument (System V AMD64):
; rdi = t_list *begin_list
;
; Return value:
; eax = unsigned int count (zero-extends to rax)

ft_list_size:
    ; count = 0 (also clears upper 32 bits of rax, since we're targeting a sub register) ;
    xor     eax, eax

.loop:
    test    rdi, rdi            ; Check if curr *node == NULL
    jz      .done

    inc     eax                 ; count++
    mov     rdi, [rdi + 8]      ; current = current->next. + 8 because sizeof(lst)
    jmp     .loop

.done:
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
