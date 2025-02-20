; Fonctions externes issues de la bibliothèque X11
extern XOpenDisplay
extern XDisplayName
extern XCloseDisplay
extern XCreateSimpleWindow
extern XMapWindow
extern XRootWindow
extern XSelectInput
extern XFlush
extern XCreateGC
extern XSetForeground
extern XDrawLine
extern XDrawPoint
extern XNextEvent

; Fonctions externes issues de la bibliothèque stdio
extern printf
extern exit

%define NOTIFY_MASK      131072
%define KEY_MASK         1
%define BUTTON_MASK      4
%define EVT_MAP          19
%define EVT_KEY          2
%define EVT_BUTTON       4
%define EVT_EXPOSE       12
%define EVT_CONFIGURE    22
%define EVT_CREATE       16
%define Q_WORD           8
%define D_WORD           4
%define W_WORD           2
%define B_WORD           1
%define NUM_CENTERS      150
%define NUM_DOTS         100000
%define WIN_W            800
%define WIN_H            800

global main

section .bss

dpy_ptr:           resq 1
screen_idx:        resd 1
col_depth:         resd 1
conn_id:           resd 1
win_ptr:           resq 1
gc_ptr:            resq 1

minDistance:       resd 1
minDistanceIndex:  resd 1

centerX:           resd NUM_CENTERS+1
centerY:           resd NUM_CENTERS+1
drawDone:          resb 1

section .data

index:         db "Index : %d", 10, 0
error:         db "Erreur : supperieur au limites", 0xA, 0

evtBuffer:     times 24 dq 0

win_w:         dd WIN_W
win_h:         dd WIN_H
points_count:  dd NUM_DOTS
center_count:  dd NUM_CENTERS

pt1_x:         dd 0
pt1_y:         dd 0
pt2_x:         dd 0
pt2_y:         dd 0

color_palette: dd 0x8ff0a4, 0x82e0a6, 0x75d0a8, 0x68c0a9, 0x5bb0ab, 0x4e9fad, 0x418faf, 0x347fb0, 0x276fb2, 0x1a5fb4
num_colors:    dd 10

section .text

main:
    mov     byte [drawDone], 0

    push    rbp
    mov     rbp, rsp

    xor     rdi, rdi
    call    XDisplayName
    test    rax, rax
    jz      cleanup

    xor     rdi, rdi
    call    XOpenDisplay
    test    rax, rax
    jz      cleanup
    mov     [dpy_ptr], rax

    mov     rsp, rbp
    pop     rbp

    mov     rax, [dpy_ptr]
    mov     eax, dword [rax + 0xe0]
    mov     [screen_idx], eax

    mov     rdi, [dpy_ptr]
    mov     esi, eax
    call    XRootWindow
    mov     rbx, rax

    mov     rdi, [dpy_ptr]
    mov     rsi, rbx
    mov     rdx, 10         
    mov     rcx, 10         
    mov     r8, [win_w]     
    mov     r9, [win_h]     
    push    0XFFFFFF        
    push    0x000000        
    push    1               
    call    XCreateSimpleWindow
    mov     [win_ptr], rax

    mov     rdi, [dpy_ptr]
    mov     rsi, [win_ptr]
    mov     rdx, 131077     
    call    XSelectInput

    mov     rdi, [dpy_ptr]
    mov     rsi, [win_ptr]
    call    XMapWindow

    mov     rdi, [dpy_ptr]
    test    rdi, rdi
    jz      cleanup
    mov     rsi, [win_ptr]
    test    rsi, rsi
    jz      cleanup
    xor     rdx, rdx
    xor     rcx, rcx
    call    XCreateGC
    test    rax, rax
    jz      cleanup
    mov     [gc_ptr], rax

event_loop:
    mov     rdi, [dpy_ptr]
    mov     rsi, evtBuffer
    call    XNextEvent

    cmp     dword [evtBuffer], EVT_CONFIGURE
    je      gen_centers

    cmp     dword [evtBuffer], EVT_KEY
    je      cleanup
    jmp     event_loop

gen_centers:
    cmp     byte [drawDone], 1
    je      event_loop

    xor     r14, r14            ; compteur 

center_loop:
    mov     ecx, [win_w]
    call    rand_gen
    mov     [centerX + r14*D_WORD], r12

    mov     ecx, [win_h]
    call    rand_gen
    mov     [centerY + r14*D_WORD], r12

    inc     r14
    cmp     r14d, [center_count]
    jl      center_loop

    xor     r14, r14            ; réinitialise le compteur 
    jmp     points_loop

points_loop:
    mov     ecx, [win_w]
    call    rand_gen
    mov     [pt1_x], r12d

    mov     ecx, [win_h]
    call    rand_gen
    mov     [pt1_y], r12d

    xor     r15d, r15d
    mov     dword [minDistance], 0xffffff

center_points_loop:
    mov     rdi, [centerX + r15d*D_WORD]
    mov     rsi, [centerY + r15d*D_WORD]
    mov     rdx, [pt1_x]
    mov     rcx, [pt1_y]
    call    sq_distance

    cmp     r12d, [minDistance]
    jl      update_min
update_next:
    inc     r15d
    cmp     r15d, [center_count]
    jl      center_points_loop

    mov     ecx, [num_colors]
    call    rand_gen
    mov     rdi, [dpy_ptr]
    mov     rsi, [gc_ptr]
    mov     edx, [color_palette + r12*D_WORD]
    call    XSetForeground

    mov     r12d, [minDistanceIndex]
    cmp     r12d, [center_count]
    jg      err_handler

    mov     r12d, [minDistanceIndex]
    cmp     r12d, [center_count]
    jae     err_handler

    imul    r12d, D_WORD
    mov     eax, [centerX + r12d]
    mov     [pt2_x], eax
    mov     eax, [centerY + r12d]
    mov     [pt2_y], eax

    mov     rdi, [dpy_ptr]
    test    rdi, rdi
    jz      cleanup
    mov     rsi, [win_ptr]
    test    rsi, rsi
    jz      cleanup
    mov     rdx, [gc_ptr]
    test    rdx, rdx
    jz      cleanup

    mov     ecx, [pt1_x]
    mov     r8d, [pt1_y]
    mov     r9d, [pt2_x]
    sub     rsp, 16
    mov     eax, [pt2_y]
    mov     [rsp], rax
    call    XDrawLine

    inc     r14
    cmp     r14d, [points_count]
    jl      points_loop
    jmp     flush_draw

update_min:
    mov     [minDistance], r12d
    mov     [minDistanceIndex], r15d
    jmp     update_next

flush_draw:
    mov     byte [drawDone], 1
    mov     rdi, [dpy_ptr]
    call    XFlush
    jmp     event_loop

err_handler:
    mov     rdi, index
    mov     rsi, r12
    xor     eax, eax
    call    printf

    mov     rdi, error
    xor     eax, eax
    call    printf
    jmp     cleanup

cleanup:
    mov     rax, [dpy_ptr]
    mov     rdi, rax
    call    XCloseDisplay
    xor     rdi, rdi
    call    exit

rand_gen:
    rdrand r12d
    jnc     rand_gen
    xor     edx, edx
    mov     eax, r12d
    div     ecx
    mov     r12d, edx
    ret

;----------------------------------------------------
; Fonction sq_distance
; Calcule la distance au carré entre deux points
; Entrées : rdi = x1, rsi = y1, rdx = x2, rcx = y2
; Sortie  : r12d = distance²
sq_distance:
    sub     rdi, rdx
    imul    rdi, rdi

    sub     rsi, rcx
    imul    rsi, rsi

    add     rdi, rsi
    mov     r12d, edi
    ret
