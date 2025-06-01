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
├── gcc-15.1.0.tar.gz
├── binutils-2.44.tar.gz
├── glibc-2.41.tar.gz
└── linux-6.6.89.tar.gz

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

# Top-level user-facing targets
toolchain: gcc glibc sysroot
sysroot: glibc linux-headers
bootstrap: bootstrap-libstdc++

# User-facing component targets
gcc: build/$(HOST)/$(TARGET)/.gcc.done
binutils: build/$(HOST)/$(TARGET)/.binutils.done
glibc: build/$(HOST)/$(TARGET)/.glibc.done
linux-headers: build/$(HOST)/$(TARGET)/.linux-headers.done
bootstrap-gcc: build/bootstrap/.gcc.done
bootstrap-binutils: build/bootstrap/.binutils.done
bootstrap-glibc: build/bootstrap/.glibc.done
bootstrap-libstdc++: build/bootstrap/.libstdc++.done

# Bootstrap phase sentinel files
build/bootstrap/.binutils.done: | src/binutils-$(BINUTILS_VERSION)/
	# Configure, build, install bootstrap binutils
	@mkdir -p $(dir $@) && touch $@

build/bootstrap/.gcc.done: bootstrap-binutils | src/gcc-$(GCC_VERSION)/
	# Configure, build, install bootstrap gcc
	@mkdir -p $(dir $@) && touch $@

build/bootstrap/.linux-headers.done: | src/linux-$(LINUX_VERSION)/
	# Install Linux headers
	@mkdir -p $(dir $@) && touch $@

build/bootstrap/.glibc.done: bootstrap-gcc linux-headers | src/glibc-$(GLIBC_VERSION)/
	# Configure, build, install bootstrap glibc
	@mkdir -p $(dir $@) && touch $@

build/bootstrap/.libstdc++.done: bootstrap-gcc bootstrap-glibc
	# Build and install libstdc++
	@mkdir -p $(dir $@) && touch $@

# Final phase sentinel files
build/$(HOST)/$(TARGET)/.binutils.done: bootstrap-libstdc++ | src/binutils-$(BINUTILS_VERSION)/
	# Configure, build, install final binutils
	@mkdir -p $(dir $@) && touch $@

build/$(HOST)/$(TARGET)/.gcc.done: binutils bootstrap-libstdc++ | src/gcc-$(GCC_VERSION)/
	# Configure, build, install final gcc
	@mkdir -p $(dir $@) && touch $@

build/$(HOST)/$(TARGET)/.glibc.done: gcc bootstrap-libstdc++ | src/glibc-$(GLIBC_VERSION)/
	# Configure, build, install final glibc (clean)
	@mkdir -p $(dir $@) && touch $@

build/$(HOST)/$(TARGET)/.linux-headers.done: | src/linux-$(LINUX_VERSION)/
	# Install Linux headers for target
	@mkdir -p $(dir $@) && touch $@

# Source extraction (version-specific patches)
src/binutils-$(BINUTILS_VERSION)/: dl/binutils-$(BINUTILS_VERSION).tar.gz patches/binutils-$(BINUTILS_VERSION)/
	# Extract tarball and apply binutils patches
	@touch $@

src/gcc-$(GCC_VERSION)/: dl/gcc-$(GCC_VERSION).tar.gz patches/gcc-$(GCC_VERSION)/
	# Extract tarball and apply gcc patches
	@touch $@

src/glibc-$(GLIBC_VERSION)/: dl/glibc-$(GLIBC_VERSION).tar.gz patches/glibc-$(GLIBC_VERSION)/
	# Extract tarball and apply glibc patches
	@touch $@

src/linux-$(LINUX_VERSION)/: dl/linux-$(LINUX_VERSION).tar.gz patches/linux-$(LINUX_VERSION)/
	# Extract tarball and apply linux patches
	@touch $@

# Download targets
dl/%.tar.gz: $(CONFIG)
	# Download and verify checksum
```

### Cross-Compilation Dependencies
True native builds require HOST == TARGET == build system. Otherwise we need explicit native targets:

```makefile
# Detect build system
BUILD := $(shell uname -s | tr A-Z a-z)/$(shell uname -m)

# Check if this is a native build (HOST and TARGET both equal build system)
IS_NATIVE := $(and $(filter $(HOST),$(BUILD)),$(filter $(TARGET),$(BUILD)))

# Bootstrap only allowed for native builds
bootstrap: bootstrap-libstdc++
bootstrap-libstdc++:
ifeq ($(IS_NATIVE),)
	$(error Bootstrap only supported for native builds. Use HOST=$(BUILD) TARGET=$(BUILD))
endif

# Handle native vs cross-compilation
ifeq ($(IS_NATIVE),)
  # Cross builds need native toolchain first
  gcc: native-gcc
  binutils: native-binutils

  # Native toolchain targets (only for cross builds)
  native-gcc: src/gcc-$(GCC_VERSION)/ native-binutils bootstrap-libstdc++
  native-binutils: src/binutils-$(BINUTILS_VERSION)/ bootstrap-libstdc++
else
  # For native builds, native-* targets are aliases to avoid duplication
  native-gcc: gcc
  native-binutils: binutils
endif
```

### Key Insights
1. **Bootstrap toolchain must complete** before any final phase builds
2. **Clean glibc rebuild** ensures final toolchain uses properly built glibc
3. **Cross-compilers depend on native toolchain** when HOST ≠ TARGET
4. **Parallel builds possible** within each phase but not across phases
5. **Source extraction** happens automatically via pattern rule
6. **Sysroot assembly** happens after final glibc is built
7. **Downloads can happen in parallel** and early

## Implementation Plan

### Phase 1: Core Infrastructure (Foundation)
1. **Create config.mk**
   - Extract versions and checksums from `script/common.sh`
   - Test with `include config.mk` in simple makefile

2. **Implement download system**
   - Port `script/download.sh` logic to makefile targets
   - Create `dl/%.tar.gz: $(CONFIG)` rule with checksum verification
   - Test downloading all packages

3. **Implement source extraction**
   - Create version-specific extraction rules
   - Port patch application logic from scripts
   - Test extraction of all packages with patches

### Phase 2: Bootstrap Build System (Native Only)
4. **Port bootstrap-binutils**
   - Convert `script/build-binutils.sh --bootstrap` to makefile rule
   - Create `build/bootstrap/.binutils.done` target
   - Test bootstrap binutils build

5. **Port bootstrap-gcc**
   - Convert `script/build-gcc.sh --bootstrap` to makefile rule
   - Create `build/bootstrap/.gcc.done` target
   - Test bootstrap gcc build

6. **Port linux-headers and bootstrap-glibc**
   - Convert `script/build-linux-headers.sh` and `script/build-glibc.sh`
   - Create header installation and bootstrap glibc targets
   - Test complete bootstrap toolchain

### Phase 3: Final Build System (Native Only)
7. **Port final binutils and gcc**
   - Convert final versions of build scripts
   - Create `build/$(HOST)/$(TARGET)/.gcc.done` targets
   - Test final toolchain build

8. **Port final glibc (clean rebuild)**
   - Implement clean glibc rebuild logic
   - Test complete native toolchain end-to-end

### Phase 4: Cross-Compilation Support
9. **Implement cross-compilation logic**
   - Add BUILD_SYSTEM detection and IS_NATIVE logic
   - Create native-* target aliases
   - Test cross-compilation dependencies

10. **Add sysroot assembly**
    - Implement sysroot target logic
    - Test complete cross-compilation workflow

### Phase 5: Polish and Testing
11. **Add convenience features**
    - Implement clean targets
    - Add parallel build optimizations
    - Test with `make -j`

12. **Comprehensive testing**
    - Test native builds (aarch64→aarch64)
    - Test cross-compilation (aarch64→x86_64)
    - Compare outputs with script-based builds
    - Test with different config files

### Phase 6: Documentation and Migration
13. **Update documentation**
    - Update README.md with makefile usage
    - Document config file format
    - Add troubleshooting guide

### Implementation Notes
- **Start simple**: Begin with native builds only, add cross-compilation later
- **Test incrementally**: Each phase should produce working results
- **Preserve scripts**: Keep scripts working during transition for comparison
- **Version compatibility**: Ensure config.mk format is extensible for future needs
