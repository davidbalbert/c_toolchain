# C/C++ Toolchain Project Memory

## Project Essentials

- **Goal**: Build reproducible, statically linked C/C++ toolchains for cross-compilation
- **Primary targets**: aarch64 Linux, x86_64 Linux
- **Components**: GCC 15.1, Binutils, glibc, Linux kernel headers

## Key Build Parameters

- **Reproducibility flags**: 
  - `-ffile-prefix-map=ACTUAL_PATH=FIXED_PATH`
  - `SOURCE_DATE_EPOCH=1`
  - `LC_ALL=C`

## Component Versions

- GCC: 15.1.0
- Binutils: latest stable (TBD)
- glibc: latest stable (TBD)
- Linux: latest LTS kernel (TBD)

## Build Command Reference

```bash
# Primary build command (when implemented)
./scripts/build.sh --target=aarch64-linux-gnu
```

## Special Notes

- Using bootstrap compiler approach for reproducibility
- No Docker dependency, using path normalization instead
- Will eventually need to support macOS builds