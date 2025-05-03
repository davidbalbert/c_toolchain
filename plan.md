# C/C++ Toolchain Build Plan

## Project Goal
Build statically linked C/C++ cross compilers and sysroots that don't depend on any system libraries. The toolchains will be used with Bazel, so sysroots need to contain only Linux kernel headers, libc + headers, and C++ standard library + headers.

## Target Platforms (Initial)
- aarch64 Linux
- x86_64 Linux

## Components
- Compilers: GCC 15.1 (initially)
- Binutils (linker, assembler)
- C Library: glibc
- Linux kernel headers

## Project Structure
```
/
├── scripts/
│   ├── download.sh      # Download and verify source tarballs
│   ├── build.sh         # Main build orchestration
│   ├── build-binutils.sh # Binutils build script
│   ├── [other component scripts]
├── src/                 # Downloaded source code
├── build/               # Build directories
│   ├── toolchains/      # Final toolchain build directories
│   │   └── $HOST/
│   │       └── $TARGET-gcc-$GCC_VERSION/
│   │           ├── binutils/
│   │           ├── gcc/
│   │           └── [other components]
│   ├── sysroots/        # Final sysroot build directories
│   │   └── $TARGET-glibc-$GLIBC_VERSION/
│   │       ├── kernel-headers/
│   │       ├── glibc/
│   │       └── [other components]
│   └── bootstrap/       # Bootstrap build directories
│       ├── toolchains/
│       │   └── $TARGET-gcc-$GCC_VERSION/
│       │       ├── binutils/
│       │       ├── gcc/
│       │       └── [other components]
│       └── sysroots/
│           └── $TARGET-glibc-$GLIBC_VERSION/
└── out/                 # Final output directories
    ├── toolchains/      # Final toolchains
    │   └── $HOST/
    │       └── $TARGET-gcc-$GCC_VERSION/
    ├── sysroots/        # Final sysroots
    │   └── $TARGET-glibc-$GLIBC_VERSION/
    └── bootstrap/       # Bootstrap artifacts
        ├── toolchains/
        │   └── $TARGET-gcc-$GCC_VERSION/
        └── sysroots/
            └── $TARGET-glibc-$GLIBC_VERSION/
```

## Directory Structure Explanation

### Build Directories
- `build/toolchains/$HOST/$TARGET-gcc-$GCC_VERSION/binutils/` - Final toolchain components
- `build/sysroots/$TARGET-glibc-$GLIBC_VERSION/` - Final sysroot components
- `build/bootstrap/toolchains/$TARGET-gcc-$GCC_VERSION/binutils/` - Bootstrap components
- `build/bootstrap/sysroots/$TARGET-glibc-$GLIBC_VERSION/` - Bootstrap sysroot components

### Output Directories
- `out/toolchains/$HOST/$TARGET-gcc-$GCC_VERSION/` - Final toolchains
- `out/sysroots/$TARGET-glibc-$GLIBC_VERSION/` - Final sysroots
- `out/bootstrap/toolchains/$TARGET-gcc-$GCC_VERSION/` - Bootstrap toolchains
- `out/bootstrap/sysroots/$TARGET-glibc-$GLIBC_VERSION/` - Bootstrap sysroots

### Key Variables
- `$HOST` - Host architecture (where the compiler runs)
- `$TARGET` - Target architecture (what the compiler builds for)
- `$GCC_VERSION` - GCC version (e.g., "15.1.0")
- `$GLIBC_VERSION` - glibc version (e.g., "2.41")

## Build Sequence (aarch64 Linux Non-Cross Compiler)

1. **Prepare Environment**
   - Set up build environment variables
   - Install minimal build dependencies

2. **Download & Verify Sources**
   - GCC 15.1
   - Binutils
   - glibc
   - Linux kernel

3. **Build Binutils**
   - Configure with static linking
   - Install to temporary prefix

4. **Build Bootstrap GCC**
   - Build minimal GCC with C compiler only
   - No dependencies on target libraries

5. **Install Linux Kernel Headers**
   - Prepare minimal kernel headers

6. **Build Minimal glibc Headers**
   - Install C library headers only

7. **Build Bootstrap GCC with C++ Support**
   - Enable C++ features
   - Link against temporary glibc headers

8. **Build Complete glibc**
   - Build full C library against bootstrap compiler

9. **Build Final GCC Toolchain**
   - Complete compiler with all languages
   - Statically linked against final glibc

## Cross-Compilation Strategy

For building x86_64 toolchain on aarch64:
1. Build aarch64 → aarch64 compiler (non-cross, described above)
2. Build aarch64 → x86_64 compiler (cross)
3. Build x86_64 → x86_64 compiler (non-cross, using cross compiler)

## Reproducibility Considerations

- **Path Normalization**: Use `-ffile-prefix-map=ACTUAL_PATH=FIXED_PATH` for both debug info and macros
- **Timestamp Control**: Set `SOURCE_DATE_EPOCH=1` for deterministic timestamps
- **Deterministic Ordering**: Use `LC_ALL=C` during configuration and builds
- **Binutils Configuration**: Use `--with-build-sysroot` during configure
- **Controlled Environment**: Clear/set specific environment variables for builds
- **Specific Versions**: Pin exact versions of all source packages
- **Verification**: Hash verification of sources and outputs
- **Documentation**: Document all build dependencies and host requirements

Note: Since final builds will use the identical bootstrap toolchain, we don't need extensive optimization controls - the bootstrap process itself provides consistency.

## Initial Implementation Plan

1. ✅ Create directory structure
2. ✅ Implement download script with checksums
3. Implement individual component build scripts:
   - 3.1. Binutils (bootstrap)
   - 3.2. Bootstrap GCC (C only)
   - 3.3. Linux kernel headers
   - 3.4. Minimal glibc headers
   - 3.5. Bootstrap GCC with C++ support
   - 3.6. Complete glibc
   - 3.7. Binutils (final)
   - 3.8. Final GCC toolchain
4. Create main orchestration script
5. Test aarch64 → aarch64 build
6. Verify reproducibility

## Future Expansion

- Multiple C libraries (musl, uclibc)
- Multiple compilers (LLVM/Clang)
- Additional architectures (arm, riscv64, etc.)
- Multiple linkers (gold, lld)
