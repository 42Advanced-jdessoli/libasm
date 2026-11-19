bits 64

global ft_calloc
extern malloc
extern __errno_location

section .text
ft_calloc:
    ; rdi is for nmemb (number of blocks), rsi is for size (size of one block);
    ; the checks below are to see if rdi == 0 or rsi == 0 ;
    ; so if nmemb or size are NULL ;
    test rdi, rdi
    jz .return_null
    test rsi, rsi
    jz .return_null

    ; we do rax * rsi, so nmemb * size, to check for a possible overflow ;
    ; if there's an overflow, aka result needs more than 64 bits, rdx will != 0 ;
    mov rax, rdi
    mul rsi
    cmp rdx, 0
    jne .return_null

    ; aligning the stack, then saving nmemb * size in rax ;
    push rbx
    push rax

    ; malloc gets the allocated size from rdi, and return the addr in rax ;
    ; so we first need to move the size in rdi, as asked by convention System V ;
    ; which also clean rax so it can receive the addr ;
    mov rdi, rax
    call malloc wrt ..plt

    ; rsi also contains nmemb * size ;
    ; we used the first nmemb * size storage to do the malloc ;
    ; that second one will be needed for the bzero ;
    pop rsi

    ; check if malloc failed ;
    cmp rax, 0
    je .malloc_error

    ; we move the starting addr in rdi, and the total size in rcx ;
    ; so we're giving the begining and ending for bzero loop ;
    mov rdi, rax
    mov rcx, rsi

    ; bzero loop. First, exit condition : checking if rcx is at 0, aka if bzero is finished ;
    ; then we fill with 0, starting from the start, and rcx-- after each 0 is placed ;
    ; so rcx is used as a decreasing counter here ;
.loop_zero:
    test rcx, rcx
    jz .done
    mov byte [rdi + rcx - 1], 0
    dec rcx
    jmp .loop_zero

    ; restauring the stack to prev state, then return the starting addr of bzero array ;
.done:
    pop rbx
    ret

.malloc_error:
    pop rbx
    mov rax, 0
    ret

    ; xor rax, rax is just an optimized manner to ret 0
.return_null:
    xor rax, rax
    ret
