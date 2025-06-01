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

# Build only bootstrap phase
make bootstrap HOST=linux/aarch64 TARGET=linux/aarch64

# Build final sysroot only (assumes bootstrap exists)
make sysroot HOST=linux/aarch64 TARGET=linux/aarch64

# Clean specific toolchain
make clean-toolchain HOST=linux/aarch64 TARGET=linux/aarch64

# Clean everything
make clean
```

### Variables
- `HOST` - Optional: where the compiler runs (defaults to local system, e.g. linux/aarch64, linux/x86_64)
- `TARGET` - Optional: what the compiler builds for (defaults to HOST)
- `CONFIG` - Optional: config file (default: config.mk)
- `BUILD_ROOT` - Optional: build directory (default: current directory)

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

## Next Steps

1. **Model Dependencies** - Map two-phase build to make dependency graph
2. **Draft Makefile Structure** - Create initial makefile organization
3. **Implementation Plan** - Define migration steps from scripts
