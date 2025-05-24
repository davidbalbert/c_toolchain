// Shim to load the Linux dynamic linker from a path relative to the
// current executable.

#include <stddef.h>

#define PATH_MAX 4096

#ifdef __x86_64__
typedef long ssize_t;

#define SYS_write 1
#define SYS_execve 59
#define SYS_exit 60
#define SYS_readlink 89
#define LINKER_NAME "ld-linux-x86-64.so.2"
#endif

#ifdef __aarch64__
typedef long ssize_t;

#define SYS_write 64
#define SYS_readlink 78
#define SYS_exit 93
#define SYS_execve 221
#define LINKER_NAME "ld-linux-aarch64.so.1"
#endif

extern long syscall3(long num, long arg1, long arg2, long arg3);

static ssize_t
readlink(const char *pathname, char *buf, size_t bufsiz) {
    return syscall3(SYS_readlink, (long)pathname, (long)buf, bufsiz);
}

static ssize_t
write(int fd, const void *buf, size_t count) {
    return syscall3(SYS_write, fd, (long)buf, count);
}

static int
execve(const char *pathname, char *const argv[], char *const envp[]) {
    return syscall3(SYS_execve, (long)pathname, (long)argv, (long)envp);
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
        if (*s == c) last = s;
        s++;
    }
    return (char*)last;
}

int
main(int argc, char **argv) {
    // Get absolute path of current executable using /proc/self/exe
    char exe_path[PATH_MAX];
    ssize_t exe_len = readlink("/proc/self/exe", exe_path, PATH_MAX - 1);
    if (exe_len <= 0) {
        const char err_msg[] = "failed to read /proc/self/exe\n";
        write(2, err_msg, sizeof(err_msg) - 1);
        return 1;
    }
    exe_path[exe_len] = '\0';  // Null terminate

    // Find directory of current executable
    char *last_slash = strrchr(exe_path, '/');
    if (!last_slash) {
        const char err_msg[] = "invalid executable path\n";
        write(2, err_msg, sizeof(err_msg) - 1);
        return 1;
    }

    // Build paths with bounds checking
    char ld_path[PATH_MAX];
    char real_path[PATH_MAX];

    // Copy directory part safely
    int dir_len = last_slash - exe_path;
    if (dir_len >= PATH_MAX - 50) {  // Leave room for suffixes
        const char err_msg[] = "path too long\n";
        write(2, err_msg, sizeof(err_msg) - 1);
        return 1;
    }

    if (strlcpy(ld_path, exe_path, PATH_MAX) >= PATH_MAX) {
        const char err_msg[] = "executable path too long\n";
        write(2, err_msg, sizeof(err_msg) - 1);
        return 1;
    }
    ld_path[dir_len] = '\0';  // Truncate to directory

    if (strlcpy(real_path, exe_path, PATH_MAX) >= PATH_MAX ||
        strlcat(real_path, ".real", PATH_MAX) >= PATH_MAX) {
        const char err_msg[] = "real path too long\n";
        write(2, err_msg, sizeof(err_msg) - 1);
        return 1;
    }

    // Add relative path to dynamic linker (architecture-specific)
    if (strlcat(ld_path, "/../lib/" LINKER_NAME, PATH_MAX) >= PATH_MAX) {
        const char err_msg[] = "linker path too long\n";
        write(2, err_msg, sizeof(err_msg) - 1);
        return 1;
    }

    // Prepare execve arguments
    char *new_argv[argc + 2];
    new_argv[0] = ld_path;           // Dynamic linker
    new_argv[1] = real_path;         // Real binary
    int i;
    for (i = 1; i < argc; i++) {
        new_argv[i + 1] = argv[i];   // Original arguments
    }
    new_argv[argc + 1] = NULL;

    // exec: replace current process (pass NULL for envp - inherit environment)
    execve(ld_path, new_argv, NULL);

    // If we get here, execve failed
    const char err_msg[] = "execve failed\n";
    write(2, err_msg, sizeof(err_msg) - 1);
    return 1;
}
