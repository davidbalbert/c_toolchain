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
│   ├── components/      # Individual component build scripts
│   │   ├── binutils.sh
│   │   ├── gcc-bootstrap.sh
│   │   ├── kernel-headers.sh
│   │   ├── glibc.sh
│   │   └── gcc-final.sh
├── src/                 # Downloaded source code
├── build/               # Build directories
└── out/                 # Final toolchains and sysroots
```

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
3. Implement individual component build scripts
4. Create main orchestration script
5. Test aarch64 → aarch64 build
6. Verify reproducibility

## Future Expansion

- Multiple C libraries (musl, uclibc)
- Multiple compilers (LLVM/Clang)
- Additional architectures (arm, riscv64, etc.)
- Multiple linkers (gold, lld)
