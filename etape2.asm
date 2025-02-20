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

%define NOTIFY_MASK        131072
%define KEYPRESS_MASK      1
%define BUTTON_MASK        4
%define MAP_NOTIFY         19
%define KEY_PRESS          2
%define BUTTON_PRESS       4
%define EXPOSE_EVENT       12
%define CONFIG_NOTIFY      22
%define CREATE_NOTIFY      16
%define QWORD_SIZE         8
%define DWORD_SIZE         4
%define WORD_SIZE          2
%define BYTE_SIZE          1
%define NUM_CENTERS        2500
%define NUM_DOTS           10000
%define WIN_WIDTH          800
%define WIN_HEIGHT         800

global main

section .bss

disp_ptr:           resq 1
screen_num:         resd 1
col_depth:          resd 1
conn_id:            resd 1
win_ptr:            resq 1
gc_ptr:             resq 1

min_dist:           resd 1
min_idx:            resd 1
center_x_array:     resd NUM_CENTERS+1
center_y_array:     resd NUM_CENTERS+1
center_color_array: resd NUM_CENTERS+1
drawn_flag:         resb 1    

section .data

index:              db "Index : %d", 10, 0
error:              db "Erreur : supperieur au limites.", 0xA, 0
evt_buf:            times 24 dq 0

p1_x:               dd 0
p2_x:               dd 0
p1_y:               dd 0
p2_y:               dd 0

color_palette:      dd 0x8ff0a4, 0x82e0a6, 0x75d0a8, 0x68c0a9, 0x5bb0ab, 0x4e9fad, 0x418faf, 0x347fb0, 0x276fb2, 0x1a5fb4
num_colors:         dd 10
points_count:       dd NUM_DOTS
center_count:       dd NUM_CENTERS
win_width:          dd WIN_WIDTH
win_height:         dd WIN_HEIGHT

section .text

main:
    mov     byte [drawn_flag], 0

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
    mov     [disp_ptr], rax

    mov     rsp, rbp
    pop     rbp

    mov     rax, [disp_ptr]
    mov     eax, dword [rax+0xe0]
    mov     [screen_num], eax

    mov     rdi, qword [disp_ptr]
    mov     esi, dword [screen_num]
    call    XRootWindow
    mov     rbx, rax

    mov     rdi, qword [disp_ptr]
    mov     rsi, rbx
    mov     rdx, 10          
    mov     rcx, 10          
    mov     r8, [win_width]  
    mov     r9, [win_height] 
    push    0xFFFFFF         
    push    0x00FF00         
    push    1                
    call    XCreateSimpleWindow
    mov     qword [win_ptr], rax

    mov     rdi, qword [disp_ptr]
    mov     rsi, qword [win_ptr]
    mov     rdx, 131077      
    call    XSelectInput

    mov     rdi, qword [disp_ptr]
    mov     rsi, qword [win_ptr]
    call    XMapWindow

    mov     rdi, qword [disp_ptr]
    test    rdi, rdi
    jz      cleanup
    mov     rsi, qword [win_ptr]
    test    rsi, rsi
    jz      cleanup
    xor     rdx, rdx
    xor     rcx, rcx
    call    XCreateGC
    test    rax, rax
    jz      cleanup
    mov     qword [gc_ptr], rax

event_loop:
    mov     rdi, qword [disp_ptr]
    mov     rsi, evt_buf
    call    XNextEvent

    cmp     dword [evt_buf], CONFIG_NOTIFY
    je      gen_centers

    cmp     dword [evt_buf], KEY_PRESS
    je      cleanup
    jmp     event_loop

gen_centers:
    cmp     byte [drawn_flag], 1
    je      event_loop

    xor     r14, r14      ; compteur 

center_loop:
    mov     ecx, [win_width]
    call    rand_gen
    mov     [center_x_array + r14*4], r12

    mov     ecx, [win_height]
    call    rand_gen
    mov     [center_y_array + r14*4], r12

    mov     ecx, [num_colors]
    call    rand_gen
    mov     r12d, [color_palette + r12*4]
    mov     [center_color_array + r14*4], r12d

    inc     r14
    cmp     r14d, [center_count]
    jl      center_loop

    xor     r14, r14      ; réinitialiser le compteur 
    jmp     points_loop

points_loop:

    mov     ecx, [win_width]
    call    rand_gen
    mov     [p1_x], r12d

    mov     ecx, [win_height]
    call    rand_gen
    mov     [p1_y], r12d

    xor     r15d, r15d    ; compteur 
    mov     dword [min_dist], 0xffffff

center_point_loop:
    mov     rdi, [center_x_array + r15d*4]
    mov     rsi, [center_y_array + r15d*4]
    mov     rdx, [p1_x]
    mov     rcx, [p1_y]
    call    sq_distance

    cmp     r12d, [min_dist]
    jl      update_closest
next_center:
    inc     r15d
    cmp     r15d, [center_count]
    jl      center_point_loop

    mov     r12d, [min_idx]
    cmp     r12d, [center_count]
    jg      err_handler

    mov     rdi, qword [disp_ptr]
    mov     rsi, qword [gc_ptr]
    mov     edx, [center_color_array + r12d*4]
    call    XSetForeground

    cmp     r12d, [center_count]
    jae     err_handler

    imul    r12d, 4
    mov     eax, [center_x_array + r12d]
    mov     [p2_x], eax
    mov     eax, [center_y_array + r12d]
    mov     [p2_y], eax

    mov     rdi, qword [disp_ptr]
    test    rdi, rdi
    jz      cleanup

    mov     rsi, qword [win_ptr]
    test    rsi, rsi
    jz      cleanup

    mov     rdx, qword [gc_ptr]
    test    rdx, rdx
    jz      cleanup

    mov     ecx, dword [p1_x]
    mov     r8d, dword [p1_y]
    mov     r9d, dword [p2_x]
    sub     rsp, 16
    mov     eax, dword [p2_y]
    mov     [rsp], rax
    call    XDrawLine

    inc     r14
    cmp     r14d, [points_count]
    jl      points_loop
    jmp     flush_draw

update_closest:
    mov     [min_dist], r12
    mov     [min_idx], r15d
    jmp     next_center

flush_draw:
    mov     byte [drawn_flag], 1
    mov     rdi, qword [disp_ptr]
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
    mov     rax, qword [disp_ptr]
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
; sq_distance:
; Calcule la distance au carré entre deux points.
; Entrées :
;   rdi - x1, rsi - y1, rdx - x2, rcx - y2
; Sortie :
;   r12d - distance²
sq_distance:
    sub     rdi, rdx
    imul    rdi, rdi

    sub     rsi, rcx
    imul    rsi, rsi

    add     rdi, rsi
    mov     r12d, edi
    ret
