// aarch64 startup code
.global _start
.global syscall1
.global syscall3
.global syscall4
.text

_start:
    // Stack layout: argc, argv[0], argv[1], ..., NULL, envp[0], ...
    // sp points to argc

    // Load argc into x0 (first argument)
    ldr w0, [sp]

    // Load argv pointer into x1 (second argument)
    // argv starts at sp + 8
    add x1, sp, #8

    // Compute envp pointer (third argument): envp = sp + 8 * (argc + 2)
    mov x2, x0
    add x2, x2, #2
    lsl x2, x2, #3
    add x2, sp, x2

    // Call main(argc, argv, envp)
    bl main

    // Exit with return value from main
    mov w8, #93              // sys_exit
    // x0 already contains return value from main
    svc #0

// syscall1(num, arg1) - AAPCS calling convention
// x0 = num, x1 = arg1
syscall1:
    mov w8, w0               // Syscall number to w8
    mov x0, x1               // arg1 to x0
    svc #0                   // Invoke system call
    ret                      // Return value already in x0

// syscall3(num, arg1, arg2, arg3) - AAPCS calling convention
// x0 = num, x1 = arg1, x2 = arg2, x3 = arg3
syscall3:
    mov w8, w0               // Syscall number to w8
    mov x0, x1               // arg1 to x0
    mov x1, x2               // arg2 to x1
    mov x2, x3               // arg3 to x2
    svc #0                   // Invoke system call
    ret                      // Return value already in x0

// syscall4(num, arg1, arg2, arg3, arg4) - AAPCS calling convention
// x0 = num, x1 = arg1, x2 = arg2, x3 = arg3, x4 = arg4
syscall4:
    mov w8, w0               // Syscall number to w8
    mov x0, x1               // arg1 to x0
    mov x1, x2               // arg2 to x1
    mov x2, x3               // arg3 to x2
    mov x3, x4               // arg4 to x3
    svc #0                   // Invoke system call
    ret                      // Return value already in x0
