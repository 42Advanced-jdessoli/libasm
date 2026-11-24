bits 64

section .text
    global ft_list_push_front
    extern malloc

; Expected t_list structure (16 bytes on 64-bit):
; offset 0 : void          *data
; offset 8 : struct s_list *next
;
; Arguments (System V AMD64):
; rdi = t_list **begin_list
; rsi = void *data

ft_list_push_front:
    ; NULL check on begin_list ;
    test    rdi, rdi
    jz      .return

    ; Save args on stack, then align it ;
    push    rdi
    push    rsi
    sub     rsp, 8

    mov     rdi, 16             ; loading 16 because sizeof(t_list) = 8 (data) + 8 (next) ;
    call    malloc wrt ..plt    ; Allocate new node -> rax holds pointer (or NULL) ;

    ; restore stack alignment, data, and begin_list ;
    add     rsp, 8
    pop     rsi
    pop     rdi

    ; check malloc fail, so if rax == NULL ;
    test    rax, rax
    jz      .return

    mov     [rax], rsi          ; new_node->data = data ;
    mov     rcx, [rdi]          ; rcx = *begin_list (previous head or NULL) ;
    mov     [rax + 8], rcx      ; new_node->next = *begin_list ;
    mov     [rdi], rax          ; *begin_list = new_node ;

.return:
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
