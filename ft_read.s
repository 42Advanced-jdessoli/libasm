bits 64

section .text
    global ft_read
    extern __errno_location

    ; ssize_t ft_read(int fd, void *buf, size_t count) ;
    ; rdi = fd, rsi = buf, rdx = count : already where the syscall expects them ;
    ft_read:
        mov rax, 0          ; 0 is the syscall num for sys_read under Linux x86_64
        syscall

        cmp rax, 0          ; syscall load a negative nb in rax if an error appeared
        jl .error
        ret

    .error:
        neg rax             ; We turn the val from neg to positive, which gives the error code
        push rax            ; Save the error code. Also re-aligns rsp on 16 bytes before the call

        ; dynamically get the addr of errno for this thread, thanks to wrt ..plt ;
        call __errno_location wrt ..plt

        pop rcx             ; Popping out of the stack and into rcx the error code
        mov [rax], ecx      ; errno is an int (4 bytes) -> write ecx, not rcx (8 bytes) ;

        mov rax, -1         ; ft_read return -1 upon failure
        ret

section .note.GNU-stack noalloc noexec nowrite progbits
