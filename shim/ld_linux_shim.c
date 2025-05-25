// Shim to load the Linux dynamic linker from a path relative to the
// current executable.

#include <stddef.h>

#define PATH_MAX 4096

#ifdef __x86_64__
typedef long ssize_t;

#define SYS_write 1
#define SYS_execve 59
#define SYS_exit 60
#define SYS_readlinkat 267
#define LD_LINUX "ld-linux-x86-64.so.2"
#endif

#ifdef __aarch64__
typedef long ssize_t;

#define SYS_write 64
#define SYS_readlinkat 78
#define SYS_exit 93
#define SYS_execve 221
#define LD_LINUX "ld-linux-aarch64.so.1"
#endif

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
main(int argc, char *argv[], char *envp[]) {
    // Get absolute path of current executable using /proc/self/exe
    char exe_path[PATH_MAX];
    ssize_t exe_len = readlink("/proc/self/exe", exe_path, PATH_MAX - 1);
    if (exe_len <= 0) {
        const char err[] = "failed to read /proc/self/exe\n";
        write(2, err, sizeof(err) - 1);
        return 1;
    }
    exe_path[exe_len] = '\0';

    // Find directory of current executable
    char *last_slash = strrchr(exe_path, '/');
    if (!last_slash) {
        const char err[] = "invalid executable path\n";
        write(2, err, sizeof(err) - 1);
        return 1;
    }

    char ld_path[PATH_MAX];
    char real_path[PATH_MAX];

    int dir_len = last_slash - exe_path;
    if (dir_len >= PATH_MAX - 50) {  // Leave room for suffixes
        const char err[] = "path too long\n";
        write(2, err, sizeof(err) - 1);
        return 1;
    }

    if (strlcpy(ld_path, exe_path, PATH_MAX) >= PATH_MAX) {
        const char err[] = "executable path too long\n";
        write(2, err, sizeof(err) - 1);
        return 1;
    }
    ld_path[dir_len] = '\0';

    if (strlcpy(real_path, exe_path, PATH_MAX) >= PATH_MAX ||
        strlcat(real_path, ".real", PATH_MAX) >= PATH_MAX) {
        const char err[] = "real path too long\n";
        write(2, err, sizeof(err) - 1);
        return 1;
    }

    if (strlcat(ld_path, "/../lib/" LD_LINUX, PATH_MAX) >= PATH_MAX) {
        const char err[] = "linker path too long\n";
        write(2, err, sizeof(err) - 1);
        return 1;
    }

    char *new_argv[argc + 2];
    new_argv[0] = ld_path;
    new_argv[1] = real_path;
    int i;
    for (i = 1; i < argc; i++) {
        new_argv[i + 1] = argv[i];
    }
    new_argv[argc + 1] = NULL;

    execve(ld_path, new_argv, envp);

    const char err[] = "execve failed\n";
    write(2, err, sizeof(err) - 1);
    return 1;
}
