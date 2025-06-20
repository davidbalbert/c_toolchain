# mktoolchain implementation plan

## Project Goal
Build statically linked C/C++ cross compilers and sysroots that don't depend on any system libraries. The toolchains will be used with Bazel, so sysroots need to contain only Linux kernel headers, libc + headers, and C++ standard library + headers.

## Current status
Migrating the various scripts that build the toolchain to a Makefile

## Decisions Made

### Configuration System
- **Start with**: `config.mk` (may evolve to `toolchain-name.mk` later)
- **Config file contains**: Package versions (GCC, binutils, glibc, etc.), libc choice (glibc/musl)
- **Command line variables**: HOST and TARGET architectures (GOOS/GOARCH pattern)
- **Multiple configs**: Eventually support multiple config files in different build hierarchies

### File Organization
- **Downloads**: `dl/` directory (currently `pkg/`)
- **Build artifacts**: `out/` directory for install prefixes
- **Future**: `dist/` directory for final tarballs
- **Architecture support**: Use existing structure from plan.md

### Build Strategy
- **Approach**: Keep same build techniques as scripts, change interface to makefile
- **Out-of-tree builds**: Optimize for builds outside source tree (maybe `make -f`)
- **Cross-compilation**: Support aarch64 and x86_64, keep architecture-agnostic
- **Parallel builds**: Support `make -j` with job server integration
- **ld-linux-shim**: Include as `.mk` file, avoid recursive make

### Scope Decisions
- **No backwards compatibility** with scripts needed
- **No automated testing** for now (manual testing continues)
- **No separate config files per target**
- **Keep existing reproducibility techniques**

## Proposed User Interface

### Primary Usage
```bash
# Build specific components (HOST and TARGET default to build system)
make gcc
make binutils
make glibc

# Build for different architectures
make gcc HOST=aarch64 TARGET=x86_64
make binutils HOST=x86_64 TARGET=x86_64
make glibc HOST=aarch64 TARGET=aarch64

# Use alternative config
make gcc HOST=x86_64 TARGET=x86_64 CONFIG=musl-toolchain.mk
```

### Alternative Targets
```bash
# Just download and verify sources
make download

# Bootstrap component targets
make bootstrap-gcc
make bootstrap-binutils
make bootstrap-glibc
make bootstrap-libstdc++

# Clean specific toolchain
make clean-toolchain HOST=aarch64 TARGET=aarch64

# Clean everything
make clean
```

### Variables
- `HOST` - Where the compiler runs (defaults to build system)
- `TARGET` - What the compiler builds for (defaults to HOST)
- `CONFIG` - Config file (default: config.mk)
- `BUILD_ROOT` - Build directory (default: current directory)

### File Structure Generated
```
out/
├── linux/
│   ├── aarch64/
│   │   ├── aarch64-linux-gnu-gcc-15.1.0/
│   │   │   ├── toolchain/     # Final toolchain (HOST=aarch64, TARGET=aarch64)
│   │   │   └── sysroot/       # Final sysroot
│   │   └── x86_64-linux-gnu-gcc-15.1.0/
│   │       ├── toolchain/     # Cross-compiler (HOST=aarch64, TARGET=x86_64)
│   │       └── sysroot/       # Cross-compiler sysroot
│   └── x86_64/
│       └── x86_64-linux-gnu-gcc-15.1.0/
│           ├── toolchain/     # Final toolchain (HOST=x86_64, TARGET=x86_64)
│           └── sysroot/       # Final sysroot
└── bootstrap/
    └── aarch64/
        └── aarch64-linux-gnu-gcc-15.1.0/
            └── toolchain/     # Bootstrap toolchain (minimal for build system)
```

### Key Design Principles
1. **Ease of use**: Multi-phase build happens automatically via dependencies
2. **Conditional phases**: Cross-compiler built only when HOST ≠ BUILD system
3. **Automatic naming**: Toolchain names constructed from TARGET + config suffix
4. **Granular control**: Individual component and bootstrap targets available
5. **Parallel safe**: All targets support `make -j`
6. **Resumable**: Can restart from any phase if previous phases complete

## Config File Design

### config.mk Example
```makefile
# Toolchain recipe identifier (architecture/OS/libc added automatically)
TOOLCHAIN_NAME := gcc-15.1.0
LIBC := glibc  # or musl

# Package versions
GCC_VERSION := 15.1.0
BINUTILS_VERSION := 2.44
GLIBC_VERSION := 2.41
LINUX_VERSION := 6.6.89

# Expected SHA256 checksums
GCC_SHA256 := 51b9919ea69c980d7a381db95d4be27edf73b21254eb13d752a08003b4d013b1
BINUTILS_SHA256 := 0cdd76777a0dfd3dd3a63f215f030208ddb91c2361d2bcc02acec0f1c16b6a2e
GLIBC_SHA256 := c7be6e25eeaf4b956f5d4d56a04d23e4db453fc07760f872903bb61a49519b80
LINUX_SHA256 := 724f68742eeccf26e090f03dd8dfbf9c159d65f91d59b049e41f996fa41d9bc1

# Full toolchain name constructed as: $(TARGET_ARCH)-$(TARGET_OS)-$(LIBC_NAME)-$(TOOLCHAIN_NAME)
# where LIBC_NAME maps: glibc → gnu, musl → musl
# Examples: aarch64-linux-gnu-gcc-15.1.0, x86_64-linux-gnu-gcc-15.1.0
```

### Future Config Variations
```makefile
# musl-toolchain.mk
TOOLCHAIN_NAME := gcc-15.1.0-musl
LIBC := musl

BINUTILS_VERSION := 2.44
MUSL_VERSION := 1.2.4
LINUX_VERSION := 6.6.89
GCC_VERSION := 15.1.0
# Results in: x86_64-linux-musl-gcc-15.1.0-musl

# clang-toolchain.mk
TOOLCHAIN_NAME := clang-18.0.0
LIBC := glibc
COMPILER := clang

BINUTILS_VERSION := 2.44
GLIBC_VERSION := 2.41
LINUX_VERSION := 6.6.89
LLVM_VERSION := 18.0.0
# Results in: x86_64-linux-gnu-clang-18.0.0
```

### Config File Rules
1. **Package versions and checksums** - Core responsibility
2. **Build tool selection** - LIBC, COMPILER choices
3. **Recipe suffix only** - Architecture/OS automatically added from TARGET
4. **No reproducibility settings** - Always set appropriately by makefile
5. **Makefile syntax** - Simple variable assignments for easy inclusion

## Dependency Graph

### Multi-Phase Build Flow

The number of phases depends on the relationship between BUILD system, HOST, and TARGET:

#### Case 1: BUILD = HOST = TARGET (Native build on build system)
```
Downloads & Sources → Bootstrap → Native Toolchain
```

#### Case 2: BUILD = HOST ≠ TARGET (Cross-compiler for build system)
```
Downloads & Sources → Bootstrap → Native Toolchain → Final Cross-Compiler
```

#### Case 3: BUILD ≠ HOST (Toolchain for different system)
```
Downloads & Sources → Bootstrap → Native → Cross-Compiler → Final Toolchain
```

### Detailed Phase Breakdown
```
Downloads & Checksums
├── gcc-15.1.0.tar.gz
├── binutils-2.44.tar.gz
├── glibc-2.41.tar.gz
└── linux-6.6.89.tar.gz

Source Extraction & Patching
├── src/gcc-15.1.0/
├── src/binutils-2.44/
├── src/glibc-2.41/
└── src/linux-6.6.89/

Phase 1: Bootstrap Toolchain (BUILD→BUILD, always required)
├── bootstrap-binutils    (needs: binutils sources)
├── bootstrap-gcc         (needs: gcc sources, bootstrap-binutils)
├── linux-headers         (needs: linux sources)
├── bootstrap-glibc       (needs: glibc sources, bootstrap-gcc, linux-headers)
└── bootstrap-libstdc++   (needs: bootstrap-gcc, bootstrap-glibc)

Phase 2: Build→Build Toolchain (full-featured, always required)
├── binutils              (needs: binutils sources, bootstrap toolchain)
├── gcc                   (needs: gcc sources, binutils, bootstrap toolchain)
└── glibc                 (needs: glibc sources, gcc, bootstrap toolchain)

Phase 3: Build→Host Cross-Compiler (only when build ≠ HOST)
├── binutils              (needs: binutils sources, build→build toolchain)
├── gcc                   (needs: gcc sources, binutils, build→build toolchain)
└── glibc                 (needs: glibc sources, gcc, build→build toolchain)

Phase 4: Host→Target Toolchain (built with appropriate compiler)
├── binutils              (needs: binutils sources, compiler for HOST)
├── gcc                   (needs: gcc sources, binutils, compiler for HOST)
└── glibc                 (needs: glibc sources, gcc, compiler for HOST)
```

### Make Target Dependencies
```makefile
# Default config file
CONFIG ?= config.mk

# Default HOST and TARGET to build system
HOST ?= $(BUILD)
TARGET ?= $(HOST)

# User-facing component targets (affected by HOST/TARGET)
gcc: build/linux/$(HOST)/$(TARGET_TOOLCHAIN_NAME)/.gcc.installed
binutils: build/linux/$(HOST)/$(TARGET_TOOLCHAIN_NAME)/.binutils.installed
glibc: build/linux/$(HOST)/$(TARGET_TOOLCHAIN_NAME)/.glibc.installed

# Bootstrap component targets (unaffected by HOST/TARGET)
bootstrap-gcc: build/bootstrap/$(BUILD)/$(BUILD_TOOLCHAIN_NAME)/.gcc.installed
bootstrap-binutils: build/bootstrap/$(BUILD)/$(BUILD_TOOLCHAIN_NAME)/.binutils.installed
bootstrap-glibc: build/bootstrap/$(BUILD)/$(BUILD_TOOLCHAIN_NAME)/.glibc.installed
bootstrap-libstdc++: build/bootstrap/$(BUILD)/$(BUILD_TOOLCHAIN_NAME)/.libstdc++.installed

# Conditional file dependencies based on HOST/TARGET relationship
ifeq ($(HOST),$(BUILD))
  # Native case: final depends directly on bootstrap
  build/linux/$(HOST)/$(TARGET_TOOLCHAIN_NAME)/.gcc.installed: bootstrap-libstdc++
else
  # Cross-compilation case: final depends on cross-compiler
  build/linux/$(HOST)/$(TARGET_TOOLCHAIN_NAME)/.gcc.installed: build/cross/$(BUILD)-to-$(HOST)/.gcc.installed
  # Cross-compiler depends on native toolchain
  build/cross/$(BUILD)-to-$(HOST)/.gcc.installed: build/linux/$(BUILD)/$(BUILD_TOOLCHAIN_NAME)/.gcc.installed
  # Native toolchain depends on bootstrap
  build/linux/$(BUILD)/$(BUILD_TOOLCHAIN_NAME)/.gcc.installed: bootstrap-libstdc++
endif
```

### Key Insights
1. **Simplified user interface** - `gcc`, `binutils`, `glibc` targets affected by HOST/TARGET variables
2. **Bootstrap targets unchanged** - always build for build system regardless of HOST/TARGET
3. **Conditional file dependencies** - same target names resolve to different dependency chains
4. **Cross-compiler conditional** - only built when build ≠ HOST
5. **Automatic toolchain naming** - TARGET architecture/OS/libc + config suffix
6. **Consistent file structure** - bootstrap and final toolchains have same arch/toolchain-name/ pattern
7. **Clean rebuilds at each phase** - ensures proper linking and dependencies
8. **Parallel builds possible** within each phase but not across phases
9. **Source extraction** happens automatically via pattern rule
10. **Sysroot assembly** happens after final glibc is built
11. **Downloads can happen in parallel** and early

## Implementation Plan
