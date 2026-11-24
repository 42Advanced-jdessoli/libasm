section .text
    global ft_list_sort

; Expected t_list structure (16 bytes on 64-bit):
; offset 0 : void          *data
; offset 8 : struct s_list *next
;
; Arguments (System V AMD64):
; rdi = t_list **begin_list
; rsi = int (*cmp)(void *, void *)
;
; Callee-saved registers used:
; rbx = cmp function pointer
; r12 = outer loop current node (list_ptr)
; r13 = inner loop current node (list_other_ptr)
; r14 = begin_list pointer (t_list **)
;
; Algorithm for sorting :
; Bubble sort (yeah, really)

ft_list_sort:
    test    rdi, rdi            ; Check if begin_list == NULL
    jz      .return
    test    rsi, rsi            ; Check if cmp == NULL
    jz      .return
    ; use rax (scratch) here : r12 is callee-saved and has not been pushed yet ;
    mov     rax, [rdi]          ; rax = *begin_list
    test    rax, rax            ; Check if list is empty
    jz      .return

    ; savec callee-saved + aligning stack
    push    rbx
    push    r12
    push    r13
    push    r14
    sub     rsp, 8              ; Keep rsp 16-byte aligned for calls to (*cmp)

    mov     r14, rdi            ; r14 = begin_list
    mov     rbx, rsi            ; rbx = cmp
    mov     r12, [r14]          ; r12 = list_ptr, so *begin_list

.outer_loop:
    test    r12, r12            ; exit condition, list_ptr == NULL
    jz      .done

    mov     r13, [r12 + 8]      ; r13 = list_other_ptr, so list_ptr->next

.inner_loop:
    test    r13, r13            ; exit condition, list_other_ptr == NULL
    jz      .next_outer

    mov     rdi, [r12]          ; rdi is loaded with list_ptr->data
    mov     rsi, [r13]          ; rsi is loaded with list_other_ptr->data
    call    rbx                 ; calling cmp func, so eax = (*cmp)(list_ptr->data, list_other_ptr->data)

    ; If cmp(...) > 0, swap is needed, otherwise jmp to .no_swap, so lst->next ;
    cmp     eax, 0
    jle     .no_swap

    ; Swap data pointers between list_ptr and list_other_ptr ;
    ; more optimal that relinking nodes ;
    mov     rax, [r12]
    mov     rdx, [r13]
    mov     [r12], rdx
    mov     [r13], rax

.no_swap:
    mov     r13, [r13 + 8]      ; list_other_ptr = list_other_ptr->next
    jmp     .inner_loop

.next_outer:
    mov     r12, [r12 + 8]      ; list_ptr = list_ptr->next
    jmp     .outer_loop

.done:
    ; restore stack pointer and callee-saved registers ;
    add     rsp, 8
    pop     r14
    pop     r13
    pop     r12
    pop     rbx

.return:
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
