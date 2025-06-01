# Makefile Migration Plan

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

## Questions Still To Answer

### 1. User Interface Design - PRIMARY FOCUS
- What are the primary make targets users will run?
- What's the overall command structure?
- How do we model the two-phase build (bootstrap -> native) in make dependencies?
- How do we handle the "clean" rebuilds of glibc and gcc in phase 2?

### 2. Technical Details (After UI Design)
- How do we handle checksums and downloads in make?
- How do we integrate `make-reloc.sh` into the makefile structure?
- What are the precise dependencies between each component?
- Should intermediate artifacts be preserved or cleaned up?

## Proposed User Interface

### Primary Usage
```bash
# The default target is toolchain
make

# Build native toolchain (HOST and TARGET default to build system)
make toolchain

# Build cross-compiler
make toolchain TARGET=linux/x86_64

# Build cross-compiler with explicit HOST
make toolchain HOST=linux/aarch64 TARGET=linux/x86_64

# Use default config.mk, or specify alternative
make toolchain TARGET=linux/x86_64 CONFIG=clang-toolchain.mk
```

### Alternative Targets
```bash
# Just download and verify sources
make download

# Build only bootstrap phase (specifying HOST or TARGET other than)
make bootstrap

# Build final sysroot only (assumes bootstrap exists)
make sysroot HOST=linux/aarch64 TARGET=linux/aarch64

# Clean specific toolchain
make clean-toolchain HOST=linux/aarch64 TARGET=linux/aarch64

# Clean everything
make clean
```

### Variables
- `HOST` - Where the compiler runs (defaults to system)
- `TARGET` - What the compiler builds for (defaults to HOST)
- `CONFIG` - Config file (default: config.mk)
- `BUILD_ROOT` - Build directory (default: current directory)

### File Structure Generated
```
out/
├── linux/
│   └── aarch64/
│       └── aarch64-linux-gcc-15.1.0/
│           ├── toolchain/     # Final toolchain
│           └── sysroot/       # Final sysroot
└── bootstrap/
    └── aarch64-linux-gcc-15.1.0/
        └── toolchain/     # Bootstrap toolchain
```

### Key Design Principles
1. **Simple common case**: `make toolchain` builds native toolchain for current system
2. **Hidden complexity**: Two-phase build happens automatically via dependencies
3. **Granular control**: Individual phase targets available when needed
4. **Parallel safe**: All targets support `make -j`
5. **Resumable**: Can restart from any phase if previous phases complete

## Config File Design

### config.mk Example
```makefile
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
```

### Future Config Variations
```makefile
# clang-toolchain.mk
COMPILER := clang
LIBC := musl

BINUTILS_VERSION := 2.44
MUSL_VERSION := 1.2.4
LINUX_VERSION := 6.6.89
LLVM_VERSION := 18.0.0
```

### Config File Rules
1. **Package versions and checksums** - Core responsibility
2. **Build tool selection** - LIBC, COMPILER choices
3. **No architecture info** - HOST/TARGET stay on command line
4. **No reproducibility settings** - Always set appropriately by makefile
5. **Makefile syntax** - Simple variable assignments for easy inclusion

## Dependency Graph

### Two-Phase Build Flow
```
Downloads & Checksums
├── gcc-15.1.0.tar.xz
├── binutils-2.44.tar.xz  
├── glibc-2.41.tar.xz
└── linux-6.6.89.tar.xz

Source Extraction & Patching
├── src/gcc-15.1.0/
├── src/binutils-2.44/
├── src/glibc-2.41/
└── src/linux-6.6.89/

Phase 1: Bootstrap Toolchain
├── bootstrap-binutils    (needs: binutils sources)
├── bootstrap-gcc         (needs: gcc sources, bootstrap-binutils)
├── linux-headers         (needs: linux sources)
├── bootstrap-glibc       (needs: glibc sources, bootstrap-gcc, linux-headers)
└── bootstrap-libstdc++   (needs: bootstrap-gcc, bootstrap-glibc)

Phase 2: Final Toolchain
├── binutils              (needs: binutils sources, bootstrap toolchain)
├── gcc                   (needs: gcc sources, binutils, bootstrap toolchain)
└── glibc                 (needs: glibc sources, gcc, bootstrap toolchain)
```

### Make Target Dependencies
```makefile
# Default config file
CONFIG ?= config.mk

# Top-level targets
toolchain: gcc sysroot
sysroot: glibc linux-headers
bootstrap: bootstrap-libstdc++

# Bootstrap phase dependencies
bootstrap-binutils: src/binutils-$(BINUTILS_VERSION)/
bootstrap-gcc: src/gcc-$(GCC_VERSION)/ bootstrap-binutils  
linux-headers: src/linux-$(LINUX_VERSION)/
bootstrap-glibc: src/glibc-$(GLIBC_VERSION)/ bootstrap-gcc linux-headers
bootstrap-libstdc++: bootstrap-gcc bootstrap-glibc

# Final phase dependencies (all need bootstrap toolchain)
binutils: src/binutils-$(BINUTILS_VERSION)/ bootstrap-libstdc++
gcc: src/gcc-$(GCC_VERSION)/ binutils bootstrap-libstdc++
glibc: src/glibc-$(GLIBC_VERSION)/ gcc bootstrap-libstdc++

# Source extraction (pattern rule)
src/%/: dl/%.tar.xz
	# Extract tarball and apply patches

# Download targets
dl/%.tar.xz: $(CONFIG)
	# Download and verify checksum
```

### Key Insights
1. **Bootstrap toolchain must complete** before any final phase builds
2. **Clean glibc rebuild** ensures final toolchain uses properly built glibc
3. **Parallel builds possible** within each phase but not across phases
4. **Source extraction** happens automatically via pattern rule
5. **Sysroot assembly** happens after final glibc is built
6. **Downloads can happen in parallel** and early

## Next Steps

1. **Draft Makefile Structure** - Create initial makefile organization
2. **Implementation Plan** - Define migration steps from scripts
