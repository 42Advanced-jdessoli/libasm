bits 64

global ft_calloc
extern malloc
extern __errno_location

%define ENOMEM 12

section .text
ft_calloc:
    ; rdi is for nmemb (number of blocks), rsi is for size (size of one block);
    ; the checks below are to see if rdi == 0 or rsi == 0 ;
    test rdi, rdi
    jz .return_null
    test rsi, rsi
    jz .return_null

    ; we do rax * rsi, so nmemb * size, to check for a possible overflow ;
    ; if there's an overflow, aka result needs more than 64 bits, rdx will != 0 ;
    mov rax, rdi
    mul rsi
    test rdx, rdx
    jnz .overflow

    ; On entry rsp % 16 == 8. ONE push (8 bytes) -> rsp % 16 == 0, aligned for malloc ;
    ; it also saves nmemb * size, which malloc would otherwise destroy ;
    push rax

    ; malloc gets the allocated size from rdi, and return the addr in rax ;
    mov rdi, rax
    call malloc wrt ..plt

    ; rsi now gets back nmemb * size for the bzero part ;
    pop rsi

    ; check if malloc failed (malloc already set errno) ;
    test rax, rax
    jz .return

    ; rdi = start addr, rcx = total size ;
    mov rdi, rax
    mov rcx, rsi

    ; bzero loop. rcx is used as a decreasing counter ;
.loop_zero:
    test rcx, rcx
    jz .return
    mov byte [rdi + rcx - 1], 0
    dec rcx
    jmp .loop_zero

.overflow:
    ; nmemb * size does not fit in 64 bits -> errno = ENOMEM, return NULL ;
    sub rsp, 8                      ; align for the call
    call __errno_location wrt ..plt
    add rsp, 8
    mov dword [rax], ENOMEM

    ; xor rax, rax is just an optimized manner to ret 0
.return_null:
    xor rax, rax
.return:
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
