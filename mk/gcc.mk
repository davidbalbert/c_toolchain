bootstrap-gcc: $(BB)/.gcc.installed
bootstrap-gcc: HOST_TRIPLE := $(BUILD_TRIPLE)
bootstrap-gcc: TARGET_TRIPLE := $(BUILD_TRIPLE)
bootstrap-gcc: PREFIX := $(BOOTSTRAP_PREFIX)
bootstrap-gcc: PATH := $(BOOTSTRAP_PREFIX)/bin:$(ORIG_PATH)
bootstrap-gcc: CFLAGS := -g0 -O2 -ffile-prefix-map=$(SRC_DIR)=. -ffile-prefix-map=$(BB)=.
bootstrap-gcc: CXXFLAGS := -g0 -O2 -ffile-prefix-map=$(SRC_DIR)=. -ffile-prefix-map=$(BB)=.
bootstrap-gcc: LDFLAGS :=
bootstrap-gcc: SOURCE_DATE_EPOCH := $(shell cat $(BB)/gcc/src/.timestamp 2>/dev/null || echo 1)
bootstrap-gcc: GCC_CONFIG = $(GCC_BASE_CONFIG) $(GCC_BOOTSTRAP_CONFIG)

gcc: $(B)/.gcc.installed
gcc: PREFIX := $(NATIVE_PREFIX)
# Use native binutils and bootstrap gcc
gcc: PATH := $(NATIVE_PREFIX)/bin:$(BOOTSTRAP_PREFIX)/bin:$(ORIG_PATH)
gcc: DYNAMIC_LINKER := $(shell find $(SYSROOT)/usr/lib -name "ld-linux-*.so.*" -type f -printf "%f\n" | head -n 1 || (echo "Error: No dynamic linker found in $(SYSROOT)/usr/lib" >&2; exit 1))
gcc: CFLAGS := -g0 -O2 -ffile-prefix-map=$(SRC_DIR)=. -ffile-prefix-map=$(B)=.
gcc: CXXFLAGS := -g0 -O2 -ffile-prefix-map=$(SRC_DIR)=. -ffile-prefix-map=$(B)=.
gcc: LDFLAGS := -L$(SYSROOT)/usr/lib -Wl,-rpath=$(SYSROOT)/usr/lib -Wl,--dynamic-linker=$(SYSROOT)/usr/lib/$(DYNAMIC_LINKER)
gcc: SOURCE_DATE_EPOCH := $(shell cat $(B)/gcc/src/.timestamp 2>/dev/null || echo 1)
gcc: BUILD_TIME_TOOLS := $(if $(wildcard $(NATIVE_PREFIX)/bin/$(TARGET_TRIPLE)-gcc),,--with-build-time-tools=$(NATIVE_PREFIX)/$(TARGET_TRIPLE)/bin)
gcc: GCC_CONFIG = $(GCC_BASE_CONFIG) $(GCC_FINAL_CONFIG) $(BUILD_TIME_TOOLS)

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

GCC_FINAL_CONFIG = \
	--enable-host-pie \
	--disable-fixincludes

$(BB)/.gcc.configured: SYSROOT_SYMLINK = ../../../$(HOST)/$(TOOLCHAIN_NAME)/sysroot
$(BB)/.gcc.configured: SYSROOT_SYMLINK_DIR = $(BO)/toolchain
$(B)/.gcc.configured: SYSROOT_SYMLINK = ../sysroot
$(B)/.gcc.configured: SYSROOT_SYMLINK_DIR = $(O)/toolchain

$(BB)/.gcc.configured: $(SRC_DIR)/gcc-$(GCC_VERSION) | bootstrap-binutils
$(B)/.gcc.configured: $(SRC_DIR)/gcc-$(GCC_VERSION) | binutils bootstrap-glibc

$(BB)/.gcc.configured $(B)/.gcc.configured: %/.gcc.configured:
	mkdir -p $*/gcc/build $(PREFIX) $(O)/toolchain $(O)/sysroot $(SYSROOT_SYMLINK_DIR)
	ln -sfn $(SRC_DIR)/gcc-$(GCC_VERSION) $*/gcc/src
	ln -sfn $(SYSROOT_SYMLINK) $(SYSROOT_SYMLINK_DIR)/sysroot
	cd $*/gcc/build && \
		CFLAGS="$(CFLAGS)" \
		CXXFLAGS="$(CXXFLAGS)" \
		LDFLAGS="$(LDFLAGS)" \
		SOURCE_DATE_EPOCH=$(SOURCE_DATE_EPOCH) \
		../src/configure $(GCC_CONFIG)
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
