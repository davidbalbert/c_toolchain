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
│   ├── bootstrap/
│   │   └── $TARGET-gcc-$GCC_VERSION/
│   │       ├── binutils/
│   │       ├── gcc/
│   │       └── [other components]
│   └── $HOST/
│       └── $TARGET-gcc-$GCC_VERSION/
│           ├── binutils/
│           ├── gcc/
│           └── [other components]
└── out/                 # Output directories
    ├── bootstrap/
    │   └── $TARGET-gcc-$GCC_VERSION/
    │       └── toolchain/
    └── $HOST/
        └── $TARGET-gcc-$GCC_VERSION/
            |── toolchain/
            └-- sysroot/
```

## Directory Structure Explanation

### Build Directories
- `build/bootstrap/$TARGET-gcc-$GCC_VERSION/binutils/` - Bootstrap components
- `build/$HOST/$TARGET-gcc-$GCC_VERSION/binutils/` - Final toolchain components

### Output Directories
- `out/bootstrap/$TARGET-gcc-$GCC_VERSION/toolchain` - Bootstrap toolchain
- `out/$HOST/$TARGET-gcc-$GCC_VERSION/toolchain` - Final toolchain
- `out/$HOST/$TARGET-gcc-$GCC_VERSION/sysroot` - Final sysroot

### Key Variables
- `$HOST` - Host architecture (where the compiler runs)
- `$TARGET` - Target architecture (what the compiler builds for)
- `$GCC_VERSION` - GCC version (e.g., "15.1.0")
- `$GLIBC_VERSION` - glibc version (e.g., "2.41")

## Build Sequence (aarch64 Linux Non-Cross Compiler)

1. **Download & Verify Sources**
```bash
script/download.sh --build-root=/path/to/buildroot
   ```

2. **Bootstrap Phase**
```bash
script/build-binutils.sh --build-root=/path/to/buildroot --bootstrap
script/build-gcc.sh --build-root=/path/to/buildroot --bootstrap
script/build-linux-headers.sh --build-root=/path/to/buildroot
script/build-glibc.sh --build-root=/path/to/buildroot
script/build-libstdc++.sh --build-root=/path/to/buildroot
```

3. **Final Phase**
```bash
script/build-binutils.sh --build-root=/path/to/buildroot
script/build-gcc.sh --build-root=/path/to/buildroot
script/build-glibc.sh --build-root=/path/to/buildroot --clean
script/build-gcc.sh --build-root=/path/to/buildroot --clean
```

4. **Make Relocatable**
```bash
script/make-reloc.sh /path/to/buildroot/out/$(uname -m)-linux-gnu/$(uname -m)-linux-gnu-gcc-15.1.0/toolchain
```

## Cross-Compilation Strategy

For building x86_64 toolchain on aarch64:
1. Build aarch64 → aarch64 compiler (non-cross, described above)
2. Build aarch64 → x86_64 compiler (cross)
3. Build x86_64 → x86_64 compiler (non-cross, using cross compiler)

## Reproducibility Considerations

- **Path Normalization**: Use `-ffile-prefix-map=ACTUAL_PATH=FIXED_PATH` for both debug info and macros
- **Timestamp Control**: Set `SOURCE_DATE_EPOCH=1` for deterministic timestamps
- **Deterministic Ordering**: Use `LC_ALL=C.UTF-8` during configuration and builds
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
   - 3.1. ✅ Bootstrap Binutils
   - 3.2. ✅ Bootstrap GCC
   - 3.3. ✅ Linux kernel headers
   - 3.4. ✅ bootstrap glibc
   - 3.5  ✅ libstdc++
   - 3.6. ✅ Binutils (final)
   - 3.7. ✅ GCC (final)
   - 3.8. ✅ glibc
4. ✅ Test aarch64 → aarch64 build
5. ✅ Make sure all files have a created at/modified at date equal to the timestamp of the latest commit.
6. Switch from scripts to makefiles (see makefile_plan.md).
7. Create tar.gz files in out/ that are reproducible.
8. Build in a different directory and verify that we can create identical tar.gz files.
9. Build with clang and verify that we can create identical tar.gz files.

## Future Expansion

- Multiple C libraries (musl, uclibc)
- Multiple compilers (LLVM/Clang)
- Additional architectures (arm, riscv64, etc.)
- Multiple linkers (gold, lld)
