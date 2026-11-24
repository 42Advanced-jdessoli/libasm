bits 64

section .text
    global ft_list_remove_if
    extern free

; Expected t_list structure (16 bytes on 64-bit):
; offset 0 : void          *data
; offset 8 : struct s_list *next
;
; Arguments (System V AMD64):
; rdi = t_list **begin_list
; rsi = void *data_ref
; rdx = int (*cmp)(void *, void *)
; rcx = void (*free_fct)(void *)
;
; Callee-saved registers used:
; rbx = begin_list (t_list **)
; r12 = data_ref (void *)
; r13 = cmp function pointer
; r14 = free_fct function pointer
; r15 = current node (t_list *)
; [rsp] = previous node (t_list *) stored on stack (keeps rsp 16-byte aligned)
;
; pointer walk (parsing) style:
; current-and-previous

ft_list_remove_if:
    test    rdi, rdi            ; Check if begin_list == NULL ;
    jz      .return
    test    rdx, rdx            ; Check if cmp == NULL ;
    jz      .return
    test    rcx, rcx            ; Check if free_fct == NULL ;
    jz      .return
    ; use rax (scratch) here : r15 is callee-saved and has not been pushed yet ;
    mov     rax, [rdi]          ; rax = *begin_list ;
    test    rax, rax            ; Check if list is empty ;
    jz      .return

    ; regarding the stack alignment, consider that, before entering the func, we have a call ;
    ; that call count for 8 bytes on the stack ;
    push    rbx
    push    r12
    push    r13
    push    r14
    push    r15
    ; the 5 previous pushes added 40 bytes on the stack, so atp we're at 48 bytes, 8 + 40 ;
    ; with the sub below, we're givin 16 more bytes to the stack, so 64 bytes in total, a multiple of 16 ;
    sub     rsp, 16             ; [rsp] = prev (8 bytes), [rsp + 8] = alignment padding (8 bytes)

    mov     rbx, rdi            ; rbx = begin_list ;
    mov     r12, rsi            ; r12 = data_ref ;
    mov     r13, rdx            ; r13 = cmp ;
    mov     r14, rcx            ; r14 = free_fct ;
    mov     r15, [rbx]          ; r15 = curr = *begin_list ;
    ; qword means quad word, 64 bits (8 bytes) in NASM syntax (which is the size of a ptr, the t_list ptr in our case);
    ; so here we're saying "overwrite 64 bits in rsp by writting 0 on them" ;
    mov     qword [rsp], 0      ; prev = NULL ;

.loop:
    test    r15, r15            ; While curr != NULL exit condition;
    jz      .done

    mov     rdi, [r15]          ; arg1 = curr->data ;
    mov     rsi, r12            ; arg2 = data_ref ;
    call    r13                 ; eax = (*cmp)(curr->data, data_ref) ;

    test    eax, eax            ; If cmp(...) == 0, remove this element ;
    jz      .remove

    mov     [rsp], r15          ; prev = curr ;
    mov     r15, [r15 + 8]      ; curr = curr->next ;
    jmp     .loop

.remove:
    mov     rax, [r15 + 8]      ; rax = next_node, so curr->next ;
    mov     rdx, [rsp]          ; rdx = prev ;

    test    rdx, rdx            ; check if curr is head node (so prev == NULL) ;
    jnz     .unlink_mid_or_tail

    mov     [rbx], rax          ; *begin_list = next_node ;
    jmp     .free_node

.unlink_mid_or_tail:
    mov     [rdx + 8], rax      ; prev->next = next_node ;

.free_node:
    push    rax                 ; Save next_node across external calls (1 push = 8 bytes -> misaligned) ;
    sub     rsp, 8              ; Re-align stack to 16 bytes for free_fct & free not EXPLODING;

    mov     rdi, [r15]          ; arg1 = curr->data ;
    call    r14                 ; (*free_fct)(curr->data) ;

    mov     rdi, r15            ; arg1 = curr (t_list *) ;
    call    free wrt ..plt      ; free(curr) ;

    add     rsp, 8              ; Remove alignment padding ;
    pop     r15                 ; r15 = next_node (becomes new curr) ;
    jmp     .loop

.done:
    ; Clean up [rsp] and padding ;
    add     rsp, 16
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx

.return:
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
