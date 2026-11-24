bits 64

section .text
    global ft_atoi_base

; rdi will store the ptr of str ;
; rsi will store the base ;
; eax instead of rax for return because the func ret an int ;
; and the System V AMD64 AB call convention says we should use eax for that ;

ft_atoi_base:
    ; rbx = our accumulator, that will store the complete number;
    ; r12 = base len, so, as an example, "01" for binary;
    ; r13 = current pointer in str ;
    ; r14 = sign, so pos or neg ;
    ; we push them to save them, calle-saved register situation ;
    push    rbx
    push    r12
    push    r13
    push    r14
    ; aligning rsp on 16 bytes, to match ABI
    sub     rsp, 8

    ; setting default ret to 0 ;
    xor     eax, eax
    ; checking we have a *str and a base ;
    test    rdi, rdi
    jz      .done
    test    rsi, rsi
    jz      .done

    ; set r12d to 0, which set all r12 to 0;
    ; this will be out index to parse the base ;
    xor     r12d, r12d
.base_len_loop:
    ; parse the base byte per byte ;
    movzx   ecx, byte [rsi + r12]
    ; check if we encounter '\0'
    test    cl, cl
    jz      .check_base_len

    ; check for invalid char in the base ;
    cmp     cl, '+'
    je      .invalid
    cmp     cl, '-'
    je      .invalid
    cmp     cl, ' '
    je      .invalid
    cmp     cl, 9               ; '\t'
    jb      .base_len_next
    cmp     cl, 13              ; '\r'
    jbe     .invalid

.base_len_next:
    ; incrementing our index and going to the next char in base ;
    inc     r12d
    jmp     .base_len_loop

.check_base_len:
    ; if base < 2, then it's a base 1 with a singular char available ;
    ; bro what would be the point ? ;
    cmp     r12d, 2
    jl      .invalid

    ; setting ecx to 0, used as an index to check for possible duplicates ;
    xor     ecx, ecx

    ; the two next blocks, outer and inner, checks for duplicates ;
    ; we pick a char with i, and run through the whole base with j for comp;
    ; ecx = i, r8d = j ;

    ; isolated i char ;
.outer_dup:
    cmp     ecx, r12d
    ; if i >= base len -> we finished parsing and there's no duplicate ;
    jge     .base_valid
    movzx   edx, byte [rsi + rcx]
    mov     r8d, ecx
    inc     r8d                 ; j = i + 1
    ; running j char ;
.inner_dup:
    cmp     r8d, r12d
    ; if j >= base len, we finished comparing the whole base with the curr char ;
    ; so we need to move on to the next i char ;
    jge     .next_outer
    ; the line below mean if duplicate == base[j] ;
    cmp     dl, byte [rsi + r8]
    je      .invalid
    inc     r8d
    jmp     .inner_dup
.next_outer:
    inc     ecx
    jmp     .outer_dup

; if you need a reminder, go on top of the file ;
.base_valid:
    mov     r13, rdi
    mov     r14d, 1

; skipping leading white spaces + jmp to sign if needs be ;
.skip_ws:
    movzx   eax, byte [r13]
    test    al, al
    jz      .zero_ret
    cmp     al, ' '
    je      .inc_ws
    cmp     al, 9
    jb      .parse_signs
    cmp     al, 13
    jbe     .inc_ws
    jmp     .parse_signs
; move the ptr forward ;
.inc_ws:
    inc     r13
    jmp     .skip_ws

; read + and - ;
.parse_signs:
    movzx   eax, byte [r13]
    cmp     al, '+'
    je      .plus_sign
    cmp     al, '-'
    je      .minus_sign
    jmp     .convert_init

.plus_sign:
    inc     r13
    jmp     .parse_signs

.minus_sign:
    neg     r14d
    inc     r13
    jmp     .parse_signs

.convert_init:
    xor     ebx, ebx            ; set ret val at 0

; parse str (rsi + rcx), checks if char (al) is in base ;
; if so add to ebx, if not or if a \0 is encountered, stops ;
.convert_loop:
    movzx   eax, byte [r13]
    test    al, al
    jz      .apply_sign

    xor     ecx, ecx            ; index = 0
.find_digit:
    cmp     ecx, r12d
    jge     .apply_sign
    cmp     al, byte [rsi + rcx]
    je      .found_digit
    inc     ecx
    jmp     .find_digit

.found_digit:
    ; we update the accumulator ebx, with the rule for positional changing base ;
    ; this rule is ebx = base_len + index, so ebx = ebx * r12d + ecx ;
    imul    ebx, r12d
    add     ebx, ecx
    inc     r13
    jmp     .convert_loop

.apply_sign:
    imul    ebx, r14d
    mov     eax, ebx
    jmp     .done

.invalid:
.zero_ret:
    xor     eax, eax

.done:
    add     rsp, 8
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
