bits 64

section .text
    global ft_simd_memchr

; BEHOLD ! Way too many comments, but it's a deep topic ;

; void *ft_simd_memchr(const void *s, int c, size_t n) ;
; rdi = s (pointer to memory area) ;
; rsi = c (byte to search for, passed as int, masked to unsigned char) ;
; rdx = n (number of bytes to examine) ;
ft_simd_memchr:
    test    rdx, rdx                ; Check if n == 0 ;
    jz      .not_found

    ; Fill xxm1 with the target character, so, for exemple, 16 bytes full of 'a' ;
    ;
    ; We need to do the following instructions in 2 steps, not directly movzx xmm1, sil ;
    ; because crossing from a general-purpose register (like sil / eax) into an xmm vector ;
    ; asks for a bridge instruction, like movd, whom only accept a 32-bits general purpose register (hence the use of eax) ;
    movzx   eax, sil                ; Zero-extend (unsigned char)c into eax, since sil is 8 bits and eax 32 bits ;
    movd    xmm1, eax               ; Move into xmm1, as it's one of the registers used by SIMD functions ;

    ; punpcklbw stands for Packed UNPaCK Low Byte to Word ;
    ; punpcklwd is Packed Unpack Low Word to Doubleword ;
    ; pshufd stands for Packed Shuffle Doublewords ;
    ; sooo, we could actually use vpbroadcastb to directly fill the whole register with one char ;
    ; but it's only for modern x86 with AVX2 CPU instructions. That 3 steps approach is the classic SSE2 approach. ;
    punpcklbw xmm1, xmm1            ; Duplicate byte in low 16 bits, turning [c, 0, 0, ...] into [c, c, 0, 0, ...] ;
    punpcklwd xmm1, xmm1            ; Duplicate the first 2 bytes into the first 4 bytes, [c, c, c, c] in lower 32 bits of xmm1 ;
    pshufd  xmm1, xmm1, 0           ; Broadcast low dword across all 128 bits of xmm1, so 'c' is everywhere now ;

    ; we need to safely handle a *s that doesn't start on a 16 bytes boundary, to avoid page-boundary crashes ;
    ; page boundary crashes is reading or writting out a mapped memory page, a usually 4 KB memory block allocated by the OS ;
    mov     rcx, rdi                ; copy s addr in rcx, so we can check it's alignement without changing the original ptr ;
    and     rcx, 15                 ; keeps the lowest 4 bits of rdi addr, rdi % 16, to put in rcx a possible misalignment offset ;
    jz      .aligned_loop           ; hypothesis of already 16-byte aligned, jump straight to main loop ;

    mov     rax, rdi                ; copy s ptr, so we can round it down (drop the extra offset) and land on the nearest mult of 16 <= original s addr;
    and     rax, -16                ; rax = rdi & ~15. Clears bottom 4 bits, rounding rax down to the start of the 16-byte aligned chunk containing s ;
    movdqa  xmm0, [rax]             ; load of the 16 bytes of the aligned chunk in xmm0 without risking a page-boundary crash ;
    pcmpeqb xmm0, xmm1              ; compare 16 bytes in both register with a single CPU instruction. How cool is that ?
    pmovmskb eax, xmm0              ; Extract 16-bit comparison mask into eax

    ; so, at this point, here the situation. Imagine our aligned block starts at addr 1008, and our starting pointer s (rdi) is at addr 1011;
    ; pmovmskb will start at 1008, so 3 bytes before the the starting pointer, so searching means we risk finding our char up to 3 bytes before *s;
    ; shr make us move to *s thanks to bit shift, and shl restor to 1008 pos. That movement wipe out matches on the 3 prev bytes ;
    shr     eax, cl                 ; bit shift the eax mask by cl position, to move to the begining ptr and ignore possible match on prev mem addr
    shl     eax, cl                 ; Restore bit positions (bits < cl are now 0)

    ; Check if we found a match within the valid prefix and within n bytes ;
    bsf     r8d, eax                ; bsf stands for Bit Scan Forward. Find index of first matching bit (0..15) and write it in r8d ;
    jz      .advance_to_aligned     ; If eax == 0, no match in this first chunk

    sub     r8, rcx                 ; r8 index - rcx offset = r8 gives the exact byte distance from s (rdi)
    cmp     r8, rdx                 ; cmp the distance found with the total search limit n, while (str[i] < n) logic ;
    jae     .not_found              ; Match occurred at or past `s + n` -> return NULL. r8 >= n hypothesis. ;
    lea     rax, [rdi + r8]         ; load effective addr of rdi + r8 in rax. Said otherwise, return s + offset ;
    ret

.advance_to_aligned:
    ; Advance `rdi` to the next 16-byte aligned address and decrease `n` (rdx) ;
    mov     r8, 16
    sub     r8, rcx                 ; r8 = number of bytes checked in this partial chunk ;
    cmp     rdx, r8                 ; Did we already check all `n` bytes? ;
    jbe     .not_found              ; If n <= r8, we are done -> return NULL ;
    add     rdi, r8                 ; rdi is now 16-byte aligned ;
    sub     rdx, r8                 ; Update remaining byte count `n` ;

    ; main 16-byte Aligned SIMD Loop ;
.aligned_loop:
    cmp     rdx, 16                 ; Do we have at least 16 bytes left? ;
    jb      .tail_chunk             ; Fewer than 16 bytes left -> handle tail safely ;

    movdqa  xmm0, [rdi]             ; Load 16 aligned bytes from `s` ;
    pcmpeqb xmm0, xmm1
    pmovmskb eax, xmm0
    test    eax, eax                ; Any byte matched ? ;
    jnz     .found_in_chunk         ; Yes -> compute exact pointer ;

    add     rdi, 16                 ; Advance pointer by 16 bytes ;
    sub     rdx, 16                 ; Decrease remaining count by 16 ;
    jmp     .aligned_loop

    ; handling final tail chunk, so below 16 bytes ;
.tail_chunk:
    test    rdx, rdx                ; Any bytes left? ;
    jz      .not_found

    ; Since `rdi` is 16-byte aligned and `rdx` >= 1, we're sure to read on a mapped memory page ;
    movdqa  xmm0, [rdi]             ; Safe 16-byte aligned load ;
    pcmpeqb xmm0, xmm1
    pmovmskb eax, xmm0
    bsf     ecx, eax
    jz      .not_found              ; No match at all in chunk ;
    cmp     rcx, rdx                ; Was the match within the remaining `n` bytes? ;
    jae     .not_found              ; Match was in the padding past `n` -> ignore ;
    lea     rax, [rdi + rcx]        ; Return pointer to matched byte ;
    ret

.found_in_chunk:
    bsf     ecx, eax                ; Find lowest set bit in mask (index 0..15), so first char found ;
    lea     rax, [rdi + rcx]        ; rax = rdi + index ;
    ret

.not_found:
    xor     eax, eax                ; Return NULL (0)
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
