bits 64

section .text
    global ft_write

    ft_write:
        mov rax, 1          ; 1 is the syscall num for sys_write under Linux x86_64
        syscall

        cmp rax, 0          ; syscall load a negative nb in rax if an error appeared
        jl .error
        ret

    .error:
        neg rax             ; We turn the val from neg to positive, which gives the error code
        push rax            ; We save the error code on the stack, since calling the function will modify the registers

        ; dynamically get the addr or errno for this thread, thanks to wrt ..plt ;
        ; this is needed for PIC (Position Independent Code) ;
        call __errno_location wrt ..plt

        pop rcx             ; Popping out of the stack and into rcx the error code
        mov [rax], rcx      ; Moving err code in the addr returned by __errno_location

        mov rax, -1         ; ft_write return -1 upon failure
        ret
