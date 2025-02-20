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

%define StructureNotifyMask 131072
%define KeyPressMask         1
%define ButtonPressMask      4
%define MapNotify           19
%define KeyPress             2
%define ButtonPress          4
%define Expose              12
%define ConfigureNotify     22
%define CreateNotify        16

%define QWORD                8
%define DWORD                4
%define WORD                 2
%define BYTE                 1

%define NB_CENTERS           500
%define WIN_W                800
%define WIN_H                800

global main

section .bss

dpyHandle:            resq 1
scrNumber:            resd 1
pixDepth:             resd 1
connValue:            resd 1
winHandle:            resq 1
gcHandle:             resq 1

closestDist:          resd 1
closestIdx:           resd 1

centersX:             resd NB_CENTERS+1
centersY:             resd NB_CENTERS+1
foyersColors:         resd NB_CENTERS

doneFlag:             resb 1  

section .data

index:        db "Index : %d", 10, 0
error:        db "Erreur : supperieur au limites", 0xA, 0

evtBuffer:    times 24 dq 0

tmpX1:        dd 0
tmpX2:        dd 0
tmpY1:        dd 0
tmpY2:        dd 0

colorTable:   dd 0xFF0000, 0xFF7F00, 0xFFFF00, 0x00FF00, 0x00FFFF, \
                  0x0000FF, 0x8B00FF, 0xFFC0CB, 0x964B00, 0xFFFFFF

colorCount:   dd 10

centerCount:  dd NB_CENTERS
winWidth:     dd WIN_W
winHeight:    dd WIN_H

section .text

main:
    mov     byte [doneFlag], 0

    push    rbp
    mov     rbp, rsp

    xor     rdi, rdi
    call    XDisplayName
    test    rax, rax
    jz      closeDisplay

    xor     rdi, rdi
    call    XOpenDisplay
    test    rax, rax
    jz      closeDisplay
    mov     [dpyHandle], rax

    mov     rsp, rbp
    pop     rbp

    mov     rax, [dpyHandle]
    mov     eax, dword [rax + 0xe0]
    mov     [scrNumber], eax

    mov     rdi, [dpyHandle]
    mov     esi, [scrNumber]
    call    XRootWindow
    mov     rbx, rax

    mov     rdi, [dpyHandle]
    mov     rsi, rbx
    mov     rdx, 10
    mov     rcx, 10
    mov     r8, [winWidth]
    mov     r9, [winHeight]
    push    0x000000      
    push    0x00FF00      
    push    1             
    call    XCreateSimpleWindow
    mov     [winHandle], rax

    mov     rdi, [dpyHandle]
    mov     rsi, [winHandle]
    mov     rdx, 131077
    call    XSelectInput

    mov     rdi, [dpyHandle]
    mov     rsi, [winHandle]
    call    XMapWindow

    mov     rdi, [dpyHandle]
    test    rdi, rdi
    jz      closeDisplay

    mov     rsi, [winHandle]
    test    rsi, rsi
    jz      closeDisplay

    xor     rdx, rdx
    xor     rcx, rcx
    call    XCreateGC
    test    rax, rax
    jz      closeDisplay
    mov     [gcHandle], rax

eventLoop:
    mov     rdi, [dpyHandle]
    mov     rsi, evtBuffer
    call    XNextEvent

    cmp     dword [evtBuffer], ConfigureNotify
    je      initCenters

    cmp     dword [evtBuffer], KeyPress
    je      closeDisplay
    jmp     eventLoop

initCenters:
    cmp     byte [doneFlag], 1
    je      eventLoop

    ; r14 servira de compteur
    xor     r14, r14

generateFoyers:
    mov     ecx, [winWidth]
    call    randGen
    mov     [centersX + r14 * 4], r12

    mov     ecx, [winHeight]
    call    randGen
    mov     [centersY + r14 * 4], r12

    mov     ecx, [colorCount]
    call    randGen
    mov     r12d, [colorTable + r12 * 4]
    mov     [foyersColors + r14 * 4], r12d

    inc     r14
    cmp     r14d, [centerCount]
    jl      generateFoyers

    ; Une fois tous les foyers générés, on passe au dessin
    xor     r13, r13  ; x => Compteur
    xor     r14, r14  ; y => Compteur
    xor     r15, r15  ; foyer => Compteur
    jmp     drawLoopX

drawLoopX:
    xor     r15, r15

drawLoopY:
    xor     r14, r14
    mov     dword [closestDist], 0xffffff

findClosestFoyer:
    mov     rdi, r13
    mov     rsi, r15
    mov     rdx, [centersX + r14 * 4]
    mov     rcx, [centersY + r14 * 4]
    call    distSquared

    cmp     r12d, [closestDist]
    jl      updateDistance

nextFoyer:
    inc     r14
    cmp     r14d, [centerCount]
    jl      findClosestFoyer

    xor     r14, r14
    mov     r14d, [closestIdx]

    mov     rdi, [dpyHandle]
    mov     rsi, [gcHandle]
    mov     edx, [foyersColors + r14d * 4]
    call    XSetForeground

    mov     rdi, [dpyHandle]
    mov     rsi, [winHandle]
    mov     rdx, [gcHandle]
    mov     rcx, r15   ; x
    mov     r8,  r13   ; y
    call    XDrawPoint

    inc     r15d
    cmp     r15d, [winWidth]
    jl      drawLoopY

    inc     r13d
    cmp     r13d, [winHeight]
    jl      drawLoopX

    jmp     finalFlush

updateDistance:
    mov     [closestDist], r12
    mov     [closestIdx], r14
    jmp     nextFoyer

finalFlush:
    mov     byte [doneFlag], 1
    mov     rdi, [dpyHandle]
    call    XFlush
    jmp     eventLoop
    mov     rax, 34
    syscall

closeDisplay:
    mov     rax, [dpyHandle]
    mov     rdi, rax
    call    XCloseDisplay
    xor     rdi, rdi
    call    exit

errorHandler:
    mov     rdi, index
    mov     rsi, r12
    xor     eax, eax
    call    printf

    mov     rdi, error
    xor     eax, eax
    call    printf
    jmp     closeDisplay

randGen:
    rdrand  r12d
    jnc     randGen

    xor     edx, edx
    mov     eax, r12d
    div     ecx
    mov     r12d, edx
    ret

distSquared:
    sub     rdi, rdx
    imul    rdi, rdi

    sub     rsi, rcx
    imul    rsi, rsi

    add     rdi, rsi
    mov     r12d, edi
    ret
