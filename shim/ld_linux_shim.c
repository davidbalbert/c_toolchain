// Shim to load the Linux dynamic linker from a path relative to the
// current executable.

#include <stddef.h>
#include <stdnoreturn.h>

#include "syscall.h"

#define PATH_MAX 4096

#ifdef __x86_64__
typedef long ssize_t;

#define LD_LINUX "ld-linux-x86-64.so.2"
#endif

#ifdef __aarch64__
typedef long ssize_t;

#define LD_LINUX "ld-linux-aarch64.so.1"
#endif

extern char **environ;
extern unsigned long *auxv;

extern long syscall1(long num, long arg1);
extern long syscall3(long num, long arg1, long arg2, long arg3);
extern long syscall4(long num, long arg1, long arg2, long arg3, long arg4);

#define AT_FDCWD -100

static ssize_t
readlink(const char *pathname, char *buf, size_t bufsiz) {
    return syscall4(SYS_readlinkat, AT_FDCWD, (long)pathname, (long)buf, bufsiz);
}

static ssize_t
write(int fd, const void *buf, size_t count) {
    return syscall3(SYS_write, fd, (long)buf, count);
}

static int
execve(const char *pathname, char *const argv[], char *const envp[]) {
    return syscall3(SYS_execve, (long)pathname, (long)argv, (long)envp);
}

static noreturn void
exit(int status) {
    syscall1(SYS_exit, status);
    __builtin_unreachable();
}

// From linux/auxvec.h
#define AT_NULL   0  /* end of vector */
#define AT_EXECFN 31 /* filename of program */

// Get auxiliary vector value
static unsigned long
getauxval(unsigned long type) {
    if (!auxv) {
        return 0;
    }

    for (unsigned long *p = auxv; p[0] != AT_NULL; p += 2) {
        if (p[0] == type) {
            return p[1];
        }
    }

    return 0;
}

// String length
static size_t
strlen(const char *s) {
    size_t len = 0;
    while (s[len]) len++;
    return len;
}

// strlcpy: copy string with size limit
// Always null-terminates (if size > 0)
// Returns total length of src (for truncation detection)
static size_t
strlcpy(char *dst, const char *src, size_t size) {
    size_t src_len = strlen(src);
    if (size > 0) {
        size_t copy_len = (src_len >= size) ? size - 1 : src_len;
        size_t i;
        for (i = 0; i < copy_len; i++) {
            dst[i] = src[i];
        }
        dst[copy_len] = '\0';
    }
    return src_len;
}

// strlcat: concatenate string with size limit
// Always null-terminates (if size > 0)
// Returns total length of string it tried to create
static size_t
strlcat(char *dst, const char *src, size_t size) {
    size_t dst_len = strlen(dst);
    size_t src_len = strlen(src);

    if (dst_len >= size) {
        return dst_len + src_len;  // dst already too long
    }

    return dst_len + strlcpy(dst + dst_len, src, size - dst_len);
}

// Find last occurrence of character
static char *
strrchr(const char *s, int c) {
    const char *last = NULL;
    while (*s) {
        if (*s == c) {
            last = s;
        }
        s++;
    }
    return (char*)last;
}

// Strip directory from end of path, return pointer to last '/' or NULL on error
static char *
strip_dir(char *path) {
    char *pos = strrchr(path, '/');
    if (!pos || pos == path) {
        return NULL;
    }
    *pos = '\0';
    return pos;
}

// Build path by concatenating parts, return 0 on success, -1 if too long
static int
build_path(char *dst, size_t size, const char *part1, const char *part2) {
    if (strlcpy(dst, part1, size) >= size ||
        strlcat(dst, part2, size) >= size) {
        return -1;
    }
    return 0;
}

static noreturn void
panic(char *s) {
    write(2, s, strlen(s));
    exit(1);
}

int
main(int argc, char *argv[]) {
    // Get absolute path of $TOOLCHAIN/libexec/ld_linux_shim
    char shim_path[PATH_MAX];
    ssize_t shim_len = readlink("/proc/self/exe", shim_path, PATH_MAX - 1);
    if (shim_len <= 0) {
        panic("failed to read /proc/self/exe\n");
    }
    shim_path[shim_len] = '\0';

    // Find toolchain root by stripping "/libexec/ld_linux_shim" from shim_path
    if (!strip_dir(shim_path) || !strip_dir(shim_path)) {
        panic("invalid executable path\n");
    }

    // Get AT_EXECFN for the real binary path
    char *execfn = (char *)getauxval(AT_EXECFN);
    if (!execfn) {
        panic("AT_EXECFN not found\n");
    }

    // Build paths
    char ld_path[PATH_MAX];
    char bin_path[PATH_MAX];
    if (build_path(ld_path, PATH_MAX, shim_path, "/sysroot/usr/lib/" LD_LINUX) ||
        build_path(bin_path, PATH_MAX, execfn, ".real")) {
        panic("path too long\n");
    }

    char *new_argv[argc + 2];
    new_argv[0] = ld_path;
    new_argv[1] = bin_path;
    for (int i = 1; i < argc; i++) {
        new_argv[i + 1] = argv[i];
    }
    new_argv[argc + 1] = NULL;

    execve(ld_path, new_argv, environ);
    panic("execve failed\n");
}
