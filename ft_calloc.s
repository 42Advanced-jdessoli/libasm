bits 64

global ft_calloc
extern malloc
extern __errno_location

section .text
ft_calloc:
    ; Prototype : void *ft_calloc(size_t nmemb, size_t size);
    ; En System V AMD64 ABI :
    ;   rdi = nmemb
    ;   rsi = size

    ; Étape 1 : Vérification des arguments nuls (optionnel mais propre, si nmemb == 0 ou size == 0)
    test rdi, rdi
    jz .return_null
    test rsi, rsi
    jz .return_null

    ; Étape 2 : Détection de l'overflow sur nmemb * size
    ; On veut vérifier si nmemb * size dépasse la taille max d'un size_t.
    ; Astuce en assembleur : on utilise l'instruction mul (multiplication non signée).
    ; 'mul rsi' multiplie rax (qui doit contenir nmemb) par rsi.
    ; Le résultat est stocké sur 128 bits dans le couple de registres rdx:rax.
    mov rax, rdi            ; rax = nmemb
    mul rsi                 ; rdx:rax = nmemb * size

    ; Si rdx est différent de 0, cela signifie que le résultat tient sur plus de 64 bits -> OVERFLOW !
    cmp rdx, 0
    jne .return_null

    ; Si on arrive ici, rax contient la taille totale propre (nmemb * size) sans overflow.
    ; On sauvegarde cette taille et d'autres registres pour la suite.
    push rbx                ; rbx : callee-saved (pour alignement pile 16 octets et sauvegarde)
    push rax                ; Sauvegarde de la taille totale à allouer

    ; Étape 3 : Allocation de la mémoire avec malloc
    mov rdi, rax            ; malloc prend sa taille en argument dans rdi
    call malloc wrt ..plt   ; Appel de malloc (adresse retournée dans rax)

    pop rsi                 ; On récupère la taille totale dans rsi (qu'on avait push juste avant)

    cmp rax, 0              ; Vérifie si malloc a échoué (retourne NULL)
    je .malloc_error        ; Si malloc renvoie 0 -> erreur

    ; Étape 4 : Initialiser la mémoire allouée à zéro (ft_bzero / memset personnalisé)
    ; rax contient l'adresse du bloc alloué par malloc.
    ; On va parcourir chaque octet pour y mettre 0.
    mov rdi, rax            ; rdi pointe vers le début du bloc
    mov rcx, rsi            ; rcx = nombre d'octets total (taille)

.loop_zero:
    test rcx, rcx           ; S'il ne reste plus d'octets à mettre à zéro
    jz .done                ; On a fini
    mov byte [rdi + rcx - 1], 0  ; On met l'octet à 0 en partant de la fin
    dec rcx
    jmp .loop_zero

.done:
    pop rbx                 ; Restaure rbx
    ret                     ; Retourne le pointeur du bloc initialisé dans rax

.malloc_error:
    pop rbx                 ; Restaure rbx avant de quitter
    mov rax, 0              ; Retourne NULL
    ret

.return_null:
    xor rax, rax            ; Retourne 0 (NULL)
    ret
