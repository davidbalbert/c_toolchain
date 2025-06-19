bootstrap-gcc: $(BB)/.gcc.installed
bootstrap-gcc: HOST_TRIPLE := $(BUILD_TRIPLE)
bootstrap-gcc: TARGET_TRIPLE := $(BUILD_TRIPLE)
bootstrap-gcc: PREFIX := $(BOOTSTRAP_PREFIX)
bootstrap-gcc: PATH := $(BOOTSTRAP_PREFIX)/bin:$(ORIG_PATH)
bootstrap-gcc: CFLAGS := -g0 -O2 -ffile-prefix-map=$(SRC_DIR)=. -ffile-prefix-map=$(BB)=.
bootstrap-gcc: CXXFLAGS := -g0 -O2 -ffile-prefix-map=$(SRC_DIR)=. -ffile-prefix-map=$(BB)=.
bootstrap-gcc: LDFLAGS :=
bootstrap-gcc: SOURCE_DATE_EPOCH := $(shell cat $(BB)/gcc/src/.timestamp 2>/dev/null || echo 1)
bootstrap-gcc: EXTRA_CONFIG := true
bootstrap-gcc: GCC_CONFIG = $(GCC_BASE_CONFIG) $(GCC_BOOTSTRAP_CONFIG)

gcc: $(B)/.gcc.installed
gcc: PREFIX := $(NATIVE_PREFIX)
# Use native binutils and bootstrap gcc
gcc: PATH := $(NATIVE_PREFIX)/bin:$(BOOTSTRAP_PREFIX)/bin:$(ORIG_PATH)
gcc: CFLAGS := -g0 -O2 -ffile-prefix-map=$(SRC_DIR)=. -ffile-prefix-map=$(B)=.
gcc: CXXFLAGS := -g0 -O2 -ffile-prefix-map=$(SRC_DIR)=. -ffile-prefix-map=$(B)=.
gcc: SOURCE_DATE_EPOCH := $(shell cat $(B)/gcc/src/.timestamp 2>/dev/null || echo 1)
gcc: DYNAMIC_LINKER := $(shell find $(SYSROOT)/usr/lib -name "ld-linux-*.so.*" -type f -printf "%f\n" | head -n 1 || (echo "Error: No dynamic linker found in $(SYSROOT)/usr/lib" >&2; exit 1))
gcc: EXTRA_CONFIG := if [ ! -x "$(NATIVE_PREFIX)/bin/$(TARGET_TRIPLE)-gcc" ]; then EXTRA_CONFIG_VAL="--with-build-time-tools=$(NATIVE_PREFIX)/$(TARGET_TRIPLE)/bin"; else EXTRA_CONFIG_VAL=""; fi
gcc: LDFLAGS := -L$(SYSROOT)/usr/lib -Wl,-rpath=$(SYSROOT)/usr/lib -Wl,--dynamic-linker=$(SYSROOT)/usr/lib/$(DYNAMIC_LINKER)
gcc: GCC_CONFIG = $(GCC_BASE_CONFIG) $(GCC_FINAL_CONFIG)

# Base config shared by both bootstrap and final
GCC_BASE_CONFIG = \
	--host=$(HOST_TRIPLE) \
	--target=$(TARGET_TRIPLE) \
	--prefix= \
	--with-sysroot=/sysroot \
	--with-build-sysroot=$(SYSROOT) \
	--enable-default-pie \
	--enable-default-ssp \
	--disable-multilib \
	--disable-bootstrap \
	--enable-languages=c,c++

# Additional config for bootstrap build
GCC_BOOTSTRAP_CONFIG = \
	--with-glibc-version=$(GLIBC_VERSION) \
	--with-newlib \
	--disable-nls \
	--disable-shared \
	--disable-threads \
	--disable-libatomic \
	--disable-libgomp \
	--disable-libquadmath \
	--disable-libssp \
	--disable-libvtv \
	--disable-libstdcxx \
	--without-headers \
	--with-gxx-include-dir=/sysroot/usr/include/c++/$(GCC_VERSION)

# Additional config for final build
GCC_FINAL_CONFIG = \
	--enable-host-pie \
	--disable-fixincludes

# Config variables are now set as target-specific assignments above

# Static pattern rules for both bootstrap and final builds
$(BB)/.gcc.configured: | bootstrap-binutils $(BO)/toolchain/sysroot
$(B)/.gcc.configured: | binutils bootstrap-glibc
$(BB)/.gcc.configured $(B)/.gcc.configured: %/.gcc.configured: $(SRC_DIR)/gcc-$(GCC_VERSION)
	mkdir -p $*/gcc/build
	ln -sfn $(SRC_DIR)/gcc-$(GCC_VERSION) $*/gcc/src
	cd $*/gcc/build && \
		$(EXTRA_CONFIG) && \
		CFLAGS="$(CFLAGS)" \
		CXXFLAGS="$(CXXFLAGS)" \
		LDFLAGS="$(LDFLAGS)" \
		SOURCE_DATE_EPOCH=$(SOURCE_DATE_EPOCH) \
		../src/configure $(GCC_CONFIG) $$EXTRA_CONFIG_VAL
	touch $@

$(BB)/.gcc.compiled $(B)/.gcc.compiled: %/.gcc.compiled: | %/.gcc.configured
	cd $*/gcc/build && \
		$(MAKE) configure-gcc && \
		sed -i 's/ --with-build-sysroot=[^ ]*//' gcc/configargs.h && \
		$(MAKE)
	touch $@

$(BB)/.gcc.installed $(B)/.gcc.installed: %/.gcc.installed: | %/.gcc.compiled
	cd $*/gcc/build && \
		TMPDIR=$$(mktemp -d) && \
		$(MAKE) DESTDIR="$$TMPDIR" install && \
		find "$$TMPDIR" -exec touch -h -d "@$(SOURCE_DATE_EPOCH)" {} \; && \
		mkdir -p $(PREFIX) && \
		cp -a "$$TMPDIR"/* $(PREFIX)/ && \
		rm -rf "$$TMPDIR"
	touch $@
