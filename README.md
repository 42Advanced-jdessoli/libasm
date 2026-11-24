# libasm

A small library of libc-like functions written in **x86-64 assembly** (NASM, Intel syntax, Linux, System V ABI).

| Mandatory | Bonus |
|---|---|
| `ft_strlen`, `ft_strcpy`, `ft_strcmp`, `ft_write`, `ft_read`, `ft_strdup` | `ft_atoi_base`, `ft_list_push_front`, `ft_list_size`, `ft_list_sort`, `ft_list_remove_if`, `ft_calloc`, `ft_simd_memchr` |

Prototypes and the `t_list` struct are in `libasm.h`.

## Build & use

```sh
make          # mandatory part  -> libasm.a
make bonus    # mandatory + bonus -> libasm.a
make clean / fclean / re
```

Assemble a single file by hand:

```sh
nasm -f elf64 ft_strlen.s -o ft_strlen.o
```

Link with a C program:

```sh
cc -Wall -Wextra -Werror main.c -L. -lasm      # or: cc main.c libasm.a
```

`-f elf64` tells NASM to produce a 64-bit ELF object file, the Linux object format.

---

# Assembly for beginners

## 1. What assembly is

The CPU only runs **machine code**, which is bytes such as `48 89 f8`. Assembly is a human-readable name for each of those instructions (`mov rax, rdi`). An **assembler** (NASM) translates it 1:1 into machine code. There are no types, no variables and no loops, only:

- **registers**: a handful of very fast storage slots inside the CPU,
- **memory**: one big array of bytes, addressed by numbers (pointers),
- **instructions**: small operations on registers and memory,
- **flags**: bits set by the last arithmetic or comparison, which conditional jumps read.

A C `while` loop turns into "compare, then jump back if the condition holds".

## 2. Registers

### General-purpose registers (64-bit)

Every 64-bit register has smaller "views" onto its low bits:

| 64-bit | low 32 | low 16 | low 8 | Conventional role (System V ABI) | Saved by |
|---|---|---|---|---|---|
| `rax` | `eax` | `ax` | `al` | **return value**, syscall number | caller |
| `rbx` | `ebx` | `bx` | `bl` | general purpose | **callee** |
| `rcx` | `ecx` | `cx` | `cl` | **4th argument**, counter (`cl` for shifts); destroyed by `syscall` | caller |
| `rdx` | `edx` | `dx` | `dl` | **3rd argument**, 2nd return value, high half of `mul` | caller |
| `rsi` | `esi` | `si` | `sil` | **2nd argument** | caller |
| `rdi` | `edi` | `di` | `dil` | **1st argument** | caller |
| `rbp` | `ebp` | `bp` | `bpl` | frame pointer (optional) | **callee** |
| `rsp` | `esp` | `sp` | `spl` | **stack pointer**: always points to the top of the stack | **callee** |
| `r8`  | `r8d` | `r8w` | `r8b` | **5th argument** | caller |
| `r9`  | `r9d` | `r9w` | `r9b` | **6th argument** | caller |
| `r10` | `r10d` | `r10w` | `r10b` | scratch; 4th argument of a **syscall** | caller |
| `r11` | `r11d` | `r11w` | `r11b` | scratch; destroyed by `syscall` | caller |
| `r12`–`r15` | `r12d`… | `r12w`… | `r12b`… | general purpose | **callee** |

```
 63                              31              15       7      0
 +-------------------------------+---------------+--------+------+
 |                              rax                              |
 +-------------------------------+---------------+--------+------+
                                 |      eax                      |
                                                 |   ax          |
                                                          |  al  |
```

> ⚠️ Writing to a **32-bit** view (`mov eax, 1`) **zeroes the upper 32 bits** of `rax`.
> Writing to an 8- or 16-bit view (`mov al, 1`) **leaves the other bits as they were**, so leftover data can remain.
> That is why the code uses `movzx eax, byte [...]`: it loads one byte and zero-extends it, so no stale bits are left.
> It is also why `xor eax, eax` is the usual way to zero all of `rax`.

### Special registers

| Register | Role |
|---|---|
| `rip` | Instruction pointer: the address of the next instruction. You never write to it directly; `jmp`, `call` and `ret` change it. `[rel label]` addresses relative to it. |
| `rflags` | Status flags, set by `cmp`, `test`, `add`, `sub`… Read by `jcc` (conditional jump) and `setcc`/`cmovcc`. |
| `xmm0`–`xmm15` | 128-bit **SIMD** registers (SSE). They hold 16 bytes, 4 floats and so on. Used for floating-point arguments and returns (`xmm0`–`xmm7`) and for vector work such as `ft_simd_memchr`. All are caller-saved. |
| `ymm`/`zmm` | 256 / 512-bit extensions (AVX / AVX-512). |

### The important flags

| Flag | Name | Set when… |
|---|---|---|
| `ZF` | Zero | the result is 0 (`cmp a, b` sets ZF when a == b) |
| `SF` | Sign | the result is negative (top bit is 1) |
| `CF` | Carry | an **unsigned** overflow or borrow happened (a < b on `cmp`) |
| `OF` | Overflow | a **signed** overflow happened |

## 3. The calling convention (System V AMD64 ABI)

This is the contract that lets C and assembly call each other.

- **Integer and pointer arguments** go, in order, in `rdi, rsi, rdx, rcx, r8, r9`. Any further arguments go on the stack.
- **Return value** goes in `rax` (or `eax` for an `int`, `al` for a `char`…).
- **Caller-saved** ("scratch") registers are `rax, rcx, rdx, rsi, rdi, r8–r11, xmm*`. A called function may destroy them. If you need one after a `call`, save it yourself (push it, or keep it in a callee-saved register).
- **Callee-saved** registers are `rbx, rbp, rsp, r12–r15`. If your function uses one, it must **restore its original value before `ret`**, normally with `push` at the start and `pop` in reverse order at the end. Your caller, maybe compiled C code, expects them unchanged.
- **The stack must be 16-byte aligned at every `call`** (see section 5).
- **Syscalls** (Linux) are different. The number goes in `rax` and the arguments in `rdi, rsi, rdx, r10, r8, r9` (**`r10`** replaces `rcx`). `syscall` destroys `rcx` and `r11`. On error the kernel returns **`-errno`** in `rax`, a value between -4095 and -1. That is why `ft_write` and `ft_read` negate it, store it through `__errno_location()`, and return -1.

Example: `ft_strcmp(s1, s2)` gets `s1` in `rdi` and `s2` in `rsi`, and returns the difference in `eax`.

## 4. The stack

The stack is a memory region that **grows downward**, toward lower addresses. `rsp` always points to the last value pushed.

| Instruction | Equivalent to |
|---|---|
| `push x` | `sub rsp, 8` then `mov [rsp], x` |
| `pop x`  | `mov x, [rsp]` then `add rsp, 8` |
| `call f` | `push` the return address (the next `rip`) then `jmp f` |
| `ret`    | `pop rip` |

```
 higher addresses
 +------------------+
 | caller's stuff   |
 +------------------+
 | return address   |  <- rsp right after `call` (pushed by call)
 +------------------+
 | saved rbx        |  <- after `push rbx`
 +------------------+
 | local / padding  |  <- after `sub rsp, 8`
 +------------------+ <- rsp
 lower addresses
```

**Golden rule:** every `push` needs a matching `pop`, and every `sub rsp, N` needs a matching `add rsp, N`. By the time you reach `ret`, `rsp` must point at the return address again. Otherwise `ret` jumps to garbage and the program crashes.

## 5. Stack alignment, explained

**The rule:** right before any `call` instruction, `rsp` must be a multiple of 16 (`rsp % 16 == 0`).

**Why:** SSE instructions such as `movaps` and `movdqa` read or write 16 bytes at once and **require** a 16-byte-aligned address, otherwise the CPU raises a fault (segfault). Compilers know the ABI guarantees alignment, so glibc functions (`malloc`, `printf`, …) put such instructions on stack locations without checking. If you call them with a misaligned stack, they can crash **randomly**: only on some code paths, only with some sizes, only on some machines. These bugs are very hard to track down.

**How to count:**

1. Just before your caller ran `call ft_something`, `rsp % 16 == 0` (the caller follows the rule).
2. `call` pushes an 8-byte return address, so **on entry to your function, `rsp % 16 == 8`**.
3. Each `push` or `sub rsp, 8` adds 8 bytes. You need an **odd number of 8-byte slots** in total before your own `call` to get back to `% 16 == 0`.

| What you push on entry | Bytes since the caller's `call` (incl. return address) | Aligned for a `call`? |
|---|---|---|
| nothing | 8 | ❌ |
| 1 push | 16 | ✅ |
| 2 pushes | 24 | ❌ (add `sub rsp, 8`) |
| 3 pushes | 32 | ✅ |
| 4 pushes | 40 | ❌ → 4 pushes + `sub rsp, 8` = 48 ✅ |
| 5 pushes | 48 | ✅ (`ft_list_remove_if` does 5 pushes + `sub rsp, 16` = 64 ✅) |

Examples from this repo:

- `ft_strdup`: **one** `push rdi` before calling `malloc`, so 8 + 8 = 16 ✅. Two pushes would be 24 and misaligned. That was a real bug here.
- `ft_list_sort`: 4 callee-saved pushes plus `sub rsp, 8`, so 8 + 32 + 8 = 48 ✅.
- `ft_write`'s error path: one `push rax` (the error code) before `call __errno_location`, so 16 ✅.
- A **leaf function** (one that calls nothing, such as `ft_strlen`) can ignore alignment completely.

## 6. NASM syntax cheat-sheet

```nasm
bits 64                 ; generate 64-bit code
section .text           ; code goes here (.data = initialised globals, .bss = zeroed globals)
    global ft_strlen    ; export the symbol so the linker / C can see it
    extern malloc       ; symbol defined elsewhere (libc, another .s file)

ft_strlen:              ; a label = an address
.loop:                  ; label starting with '.' = local to the previous global label
    ; comments start with ';'
```

**Operand order is `instr destination, source`** (Intel syntax). `mov rax, rdi` means `rax = rdi`.

**Memory operands** use square brackets: `[base + index*scale + displacement]`.

```nasm
mov  al, byte [rdi + rcx]     ; al = s[i]          (byte = 1, word = 2, dword = 4, qword = 8 bytes)
mov  [rax + 8], rcx           ; node->next = rcx   (offset 8 in t_list)
mov  qword [rsp], 0           ; size needed: NASM can't guess from an immediate
lea  rax, [rdi + r8]          ; rax = rdi + r8, address computation only, no memory read
```

**Common instructions**

| Instruction | Meaning |
|---|---|
| `mov a, b` | `a = b` |
| `movzx a, b` | copy a smaller value and zero-extend it |
| `lea a, [expr]` | `a = address of expr` (often used as cheap arithmetic) |
| `add / sub / inc / dec / neg` | arithmetic |
| `imul a, b` | signed `a *= b` |
| `mul r` | unsigned `rdx:rax = rax * r` (128-bit result; `rdx != 0` means it overflowed 64 bits) |
| `and / or / xor / not` | bitwise operations |
| `shl / shr / sar` | shift left / logical right / arithmetic (signed) right |
| `cmp a, b` | compute `a - b`, set the flags, throw the result away |
| `test a, b` | compute `a & b`, set the flags, throw the result away (`test rax, rax` means "is rax 0?") |
| `jmp label` | unconditional jump |
| `call f` / `ret` | function call and return |
| `syscall` | enter the kernel |
| `push / pop` | stack operations |

**Conditional jumps** (after `cmp a, b`)

| Condition | Signed | Unsigned |
|---|---|---|
| a == b | `je` / `jz` | `je` / `jz` |
| a != b | `jne` / `jnz` | `jne` / `jnz` |
| a < b  | `jl`  | `jb`  (below) |
| a <= b | `jle` | `jbe` |
| a > b  | `jg`  | `ja`  (above) |
| a >= b | `jge` | `jae` |

Choose by type: sizes, pointers and `unsigned char` use the **unsigned** jumps (`jb/ja`); `int` uses the **signed** ones (`jl/jg`).

## 7. Calling libc from assembly: PIC and `wrt ..plt`

Modern Linux builds **PIE** (position-independent executables) by default, so the program can be loaded at any address. libc is a shared library, and its address is only known at run time.
`call malloc wrt ..plt` calls through the **PLT** (Procedure Linkage Table), a small stub the dynamic linker fills in with the real address. A plain `call malloc` can fail to link with *"relocation R_X86_64_PC32 … can not be used when making a PIE object"*.

`errno` is thread-local, so it is not one global variable. `__errno_location()` returns a pointer (`int *`) to the current thread's copy:

```nasm
call __errno_location wrt ..plt
mov  [rax], ecx          ; errno is an int -> write 4 bytes (ecx), NOT 8 (rcx)
```

## 8. Linked lists in memory

```c
typedef struct s_list { void *data; struct s_list *next; } t_list;
```

On 64-bit, a pointer is 8 bytes, so `data` sits at offset **0** and `next` at offset **8**, for 16 bytes in total.

```nasm
mov rdi, [r15]       ; rdi = node->data
mov r15, [r15 + 8]   ; node = node->next
```

## 9. SIMD in one paragraph (`ft_simd_memchr`)

SIMD (Single Instruction, Multiple Data) processes 16 bytes with **one** instruction:

- broadcast the searched byte into all 16 lanes of `xmm1` (`punpcklbw` / `punpcklwd` / `pshufd`),
- load 16 bytes into `xmm0` (`movdqa`, which needs a 16-byte-aligned address),
- `pcmpeqb` sets each lane to `0xFF` if the bytes are equal,
- `pmovmskb` packs those lanes into a 16-bit integer mask,
- `bsf` (bit scan forward) gives the index of the first match.

An aligned 16-byte load can never cross a 4 KiB page boundary, so reading a few bytes past `n` inside the same block is safe. glibc uses the same trick.

## 10. Debugging tips

```sh
gdb ./a.out
(gdb) layout asm          # show the disassembly
(gdb) layout regs         # show the registers live
(gdb) break ft_strdup
(gdb) stepi / nexti       # step one instruction (into / over calls)
(gdb) info registers rax rdi rsi
(gdb) x/16xb $rdi         # examine 16 bytes at the address in rdi
(gdb) p/x $rsp % 16       # check stack alignment (8 on function entry, 0 before a call)

objdump -d -M intel obj/ft_strlen.o   # disassemble an object file
valgrind ./a.out                       # memory errors / leaks
```

Common crashes:

- **Segfault inside `malloc` or `printf`**: the stack is misaligned (section 5).
- **Caller behaves strangely after your function returns**: you changed a callee-saved register (`rbx`, `rbp`, `r12`–`r15`) without saving and restoring it.
- **Crash on `ret`**: unbalanced push/pop, so `rsp` doesn't point at the return address.
- **Garbage in the high bits**: you wrote to `al` or `ax` and then read `rax`. Use `movzx`.

## Resources

- System V AMD64 ABI, calling convention summary: https://gist.github.com/justinian/385c70347db8aca7ba93e87db90fc9a6
- Linux syscall table (x86-64): https://filippo.io/linux-syscall-table/
- Felix Cloutier's x86 instruction reference: https://www.felixcloutier.com/x86/
- NASM manual: https://www.nasm.us/doc/
