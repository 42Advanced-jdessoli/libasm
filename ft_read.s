bits 64

section .text
    global ft_read

    ft_write:
        mov rax, 0          ; 0 is the syscall num for sys_read under Linux x86_64
        syscall

        cmp rax, 0
        jl .error
        ret

    .error:
        neg rax
        push rax

        call __errno_location wrt ..plt

        pop rcx
        mov [rax], rcx

        mov rax, -1
        ret
