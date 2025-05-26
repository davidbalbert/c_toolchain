// aarch64 startup code

#include "syscall.h"

.global _start
.global syscall1
.global syscall3
.global syscall4

.global environ
.global auxv

// Mark stack as non-executable
.section .note.GNU-stack,"",@progbits

.bss
environ: .quad 0
auxv: .quad 0

.text

_start:
    // Stack layout: argc, argv[0], argv[1], ..., NULL, envp[0], ..., NULL, auxv[0], ...
    // sp points to argc

    // Load argc into x0 (first argument)
    ldr w0, [sp]

    // argv = sp + 8
    add x1, sp, #8

    // envp = sp + 8*(argc + 2)
    mov x2, x0
    add x2, x2, #2
    lsl x2, x2, #3
    add x2, sp, x2

    // environ = envp
    ldr x3, =environ
    str x2, [x3]

    // Find auxv: scan forward from envp until NULL, then skip to next
    mov x4, x2                   // Start from envp
1:
    ldr x5, [x4]                 // Load envp[i]
    cbz x5, 2f                   // Found end (NULL)
    add x4, x4, #8               // Move to next envp entry
    b 1b                         // Continue scanning
2:
    add x4, x4, #8               // Skip NULL
    ldr x3, =auxv
    str x4, [x3]                 // Store auxv pointer

    bl main

    // Exit with return value from main
    mov w8, #SYS_exit        // sys_exit
    // x0 already contains return value from main
    svc #0

syscall1:
syscall3:
syscall4:
    mov w8, w0               // Syscall number to w8
    mov x0, x1               // arg1 to x0
    mov x1, x2               // arg2 to x1
    mov x2, x3               // arg3 to x2
    mov x3, x4               // arg4 to x3
    svc #0
    ret                      // Return value already in x0
