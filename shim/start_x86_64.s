# x86_64 startup code

.global _start
.global syscall1
.global syscall3
.global syscall4

.global environ
.global auxv

# Mark stack as non-executable
.section .note.GNU-stack,"",@progbits

.bss
environ: .quad 0
auxv: .quad 0

.text
_start:
    # Stack layout: argc, argv[0], argv[1], ..., NULL, envp[0], ...
    # rsp points to argc

    # Load argc into rdi (first argument)
    movq (%rsp), %rdi

    # Load argv pointer into rsi (second argument)
    # argv starts at rsp + 8
    leaq 8(%rsp), %rsi

    # Compute envp pointer: envp = rsp + 8 * (argc + 2)
    movq %rdi, %rdx
    addq $2, %rdx
    salq $3, %rdx
    leaq (%rsp,%rdx), %rdx

    # Store envp in environ global
    movq %rdx, environ(%rip)

    # Find auxv: scan forward from envp until NULL, then skip to next
    movq %rdx, %rcx              # Start from envp
1:
    movq (%rcx), %rax            # Load envp[i]
    testq %rax, %rax             # Check if NULL
    jz 2f                        # Jump if NULL (end of envp)
    addq $8, %rcx                # Move to next envp entry
    jmp 1b                       # Continue scanning
2:
    addq $8, %rcx                # Skip NULL terminator
    movq %rcx, auxv(%rip)        # Store auxv pointer

    # Align stack to 16-byte boundary (ABI requirement)
    andq $-16, %rsp

    # Call main(argc, argv)
    call main

    # Exit with return value from main
    movq %rax, %rdi          # Return value becomes exit code
    movq $60, %rax           # sys_exit
    syscall

syscall1:
syscall3:
syscall4:
    movq %rdi, %rax          # Syscall number to rax
    movq %rsi, %rdi          # arg1 to rdi
    movq %rdx, %rsi          # arg2 to rsi
    movq %rcx, %rdx          # arg3 to rdx
    movq %r8, %r10           # arg4 to r10
    syscall
    ret                      # Return value already in rax
