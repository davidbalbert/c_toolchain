// aarch64 startup code
.global _start
.global syscall3
.text

_start:
    // Stack layout: argc, argv[0], argv[1], ..., NULL, envp[0], ...
    // sp points to argc

    // Load argc into x0 (first argument)
    ldr w0, [sp]

    // Load argv pointer into x1 (second argument)
    // argv starts at sp + 8
    add x1, sp, #8

    // Call main(argc, argv)
    bl main

    // Exit with return value from main
    mov w8, #93              // sys_exit
    // x0 already contains return value from main
    svc #0

// syscall3(num, arg1, arg2, arg3) - AAPCS calling convention
// x0 = num, x1 = arg1, x2 = arg2, x3 = arg3
syscall3:
    mov w8, w0               // Syscall number to w8
    mov x0, x1               // arg1 to x0
    mov x1, x2               // arg2 to x1
    mov x2, x3               // arg3 to x2
    svc #0                   // Invoke system call
    ret                      // Return value already in x0
