bootstrap-gcc: $(BOOTSTRAP_OUT_DIR)/.gcc.installed
gcc: $(TARGET_OUT_DIR)/.gcc.installed

$(BOOTSTRAP_BUILD_DIR)/.gcc.installed: HOST_TRIPLE := $(BUILD_TRIPLE)
$(BOOTSTRAP_BUILD_DIR)/.gcc.installed: TARGET_TRIPLE := $(BUILD_TRIPLE)
$(BOOTSTRAP_BUILD_DIR)/.gcc.installed: PREFIX := $(BOOTSTRAP_PREFIX)
$(BOOTSTRAP_BUILD_DIR)/.gcc.installed: OUT_DIR := $(BOOTSTRAP_OUT_DIR)
$(BOOTSTRAP_BUILD_DIR)/.gcc.installed: SYSROOT := $(BOOTSTRAP_SYSROOT)
$(BOOTSTRAP_BUILD_DIR)/.gcc.installed: PATH := $(BOOTSTRAP_PREFIX)/bin:$(ORIG_PATH)
$(BOOTSTRAP_BUILD_DIR)/.gcc.installed: CFLAGS := -g0 -O2 -ffile-prefix-map=$(SRC_DIR)=. -ffile-prefix-map=$(BOOTSTRAP_BUILD_DIR)=.
$(BOOTSTRAP_BUILD_DIR)/.gcc.installed: CXXFLAGS := -g0 -O2 -ffile-prefix-map=$(SRC_DIR)=. -ffile-prefix-map=$(BOOTSTRAP_BUILD_DIR)=.
$(BOOTSTRAP_BUILD_DIR)/.gcc.installed: SOURCE_DATE_EPOCH := $(shell if [ -f $(SRC_DIR)/gcc-$(GCC_VERSION)/.timestamp ]; then cat $(SRC_DIR)/gcc-$(GCC_VERSION)/.timestamp; else echo 1; fi)
$(BOOTSTRAP_BUILD_DIR)/.gcc.installed: SYSROOT_SYMLINK := ../../../$(HOST)/$(TOOLCHAIN_NAME)/sysroot
$(BOOTSTRAP_BUILD_DIR)/.gcc.installed: SYSROOT_SYMLINK_DIR := $(BOOTSTRAP_OUT_DIR)/toolchain
$(BOOTSTRAP_BUILD_DIR)/.gcc.installed: GCC_CONFIG := $(GCC_BASE_CONFIG) $(GCC_BOOTSTRAP_CONFIG)

$(HOST_BUILD_DIR)/.gcc.installed: PREFIX := $(HOST_PREFIX)
$(HOST_BUILD_DIR)/.gcc.installed: OUT_DIR := $(HOST_OUT_DIR)
$(HOST_BUILD_DIR)/.gcc.installed: SYSROOT := $(SYSROOT)
$(HOST_BUILD_DIR)/.gcc.installed: PATH := $(HOST_PREFIX)/bin:$(BOOTSTRAP_PREFIX)/bin:$(ORIG_PATH)
$(HOST_BUILD_DIR)/.gcc.installed: CFLAGS := -g0 -O2 -ffile-prefix-map=$(SRC_DIR)=. -ffile-prefix-map=$(HOST_BUILD_DIR)=.
$(HOST_BUILD_DIR)/.gcc.installed: CXXFLAGS := -g0 -O2 -ffile-prefix-map=$(SRC_DIR)=. -ffile-prefix-map=$(HOST_BUILD_DIR)=.
$(HOST_BUILD_DIR)/.gcc.installed: SOURCE_DATE_EPOCH := $(shell if [ -f $(SRC_DIR)/gcc-$(GCC_VERSION)/.timestamp ]; then cat $(SRC_DIR)/gcc-$(GCC_VERSION)/.timestamp; else echo 1; fi)
$(HOST_BUILD_DIR)/.gcc.installed: SYSROOT_SYMLINK := ../sysroot
$(HOST_BUILD_DIR)/.gcc.installed: SYSROOT_SYMLINK_DIR := $(HOST_OUT_DIR)/toolchain
$(HOST_BUILD_DIR)/.gcc.installed: BUILD_TIME_TOOLS := $(if $(wildcard $(HOST_PREFIX)/bin/$(TARGET_TRIPLE)-gcc),,--with-build-time-tools=$(HOST_PREFIX)/$(TARGET_TRIPLE)/bin)
$(HOST_BUILD_DIR)/.gcc.installed: GCC_CONFIG := $(GCC_BASE_CONFIG) $(GCC_FINAL_CONFIG) $(BUILD_TIME_TOOLS)

$(HOST_BUILD_DIR)/.gcc.installed: DYNAMIC_LINKER = $(shell find $(SYSROOT)/usr/lib -name "ld-linux-*.so.*" -type f -printf "%f\n" | head -n 1 || (echo "Error: No dynamic linker found in $(SYSROOT)/usr/lib" >&2; exit 1))
$(HOST_BUILD_DIR)/.gcc.installed: LDFLAGS = -L$(SYSROOT)/usr/lib -Wl,-rpath=$(SYSROOT)/usr/lib -Wl,--dynamic-linker=$(SYSROOT)/usr/lib/$(DYNAMIC_LINKER)

$(TARGET_BUILD_DIR)/.gcc.installed: PREFIX := $(TARGET_PREFIX)
$(TARGET_BUILD_DIR)/.gcc.installed: OUT_DIR := $(TARGET_OUT_DIR)
$(TARGET_BUILD_DIR)/.gcc.installed: SYSROOT := $(SYSROOT)
$(TARGET_BUILD_DIR)/.gcc.installed: PATH := $(TARGET_PREFIX)/bin:$(BOOTSTRAP_PREFIX)/bin:$(ORIG_PATH)
$(TARGET_BUILD_DIR)/.gcc.installed: CFLAGS := -g0 -O2 -ffile-prefix-map=$(SRC_DIR)=. -ffile-prefix-map=$(TARGET_BUILD_DIR)=.
$(TARGET_BUILD_DIR)/.gcc.installed: CXXFLAGS := -g0 -O2 -ffile-prefix-map=$(SRC_DIR)=. -ffile-prefix-map=$(TARGET_BUILD_DIR)=.
$(TARGET_BUILD_DIR)/.gcc.installed: SOURCE_DATE_EPOCH := $(shell cat $(TARGET_BUILD_DIR)/gcc/src/.timestamp 2>/dev/null || echo 1)
$(TARGET_BUILD_DIR)/.gcc.installed: SYSROOT_SYMLINK := ../sysroot
$(TARGET_BUILD_DIR)/.gcc.installed: SYSROOT_SYMLINK_DIR := $(TARGET_OUT_DIR)/toolchain
$(TARGET_BUILD_DIR)/.gcc.installed: BUILD_TIME_TOOLS := $(if $(wildcard $(TARGET_PREFIX)/bin/$(TARGET_TRIPLE)-gcc),,--with-build-time-tools=$(TARGET_PREFIX)/$(TARGET_TRIPLE)/bin)
$(TARGET_BUILD_DIR)/.gcc.installed: GCC_CONFIG := $(GCC_BASE_CONFIG) $(GCC_FINAL_CONFIG) $(BUILD_TIME_TOOLS)

$(TARGET_BUILD_DIR)/.gcc.installed: DYNAMIC_LINKER = $(shell find $(SYSROOT)/usr/lib -name "ld-linux-*.so.*" -type f -printf "%f\n" | head -n 1 || (echo "Error: No dynamic linker found in $(SYSROOT)/usr/lib" >&2; exit 1))
$(TARGET_BUILD_DIR)/.gcc.installed: LDFLAGS = -L$(SYSROOT)/usr/lib -Wl,-rpath=$(SYSROOT)/usr/lib -Wl,--dynamic-linker=$(SYSROOT)/usr/lib/$(DYNAMIC_LINKER)

$(BOOTSTRAP_BUILD_DIR)/.gcc.configured: $(BOOTSTRAP_OUT_DIR)/.binutils.installed
$(TARGET_BUILD_DIR)/.gcc.configured: $(TARGET_OUT_DIR)/.binutils.installed $(BOOTSTRAP_OUT_DIR)/.glibc.installed
$(HOST_BUILD_DIR)/.gcc.configured: $(HOST_OUT_DIR)/.binutils.installed $(BOOTSTRAP_OUT_DIR)/.glibc.installed

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

%/.gcc.configured: $(SRC_DIR)/gcc-$(GCC_VERSION)
	mkdir -p $*/gcc/build $(PREFIX) $(OUT_DIR)/toolchain $(OUT_DIR)/sysroot $(SYSROOT_SYMLINK_DIR)
	ln -sfn $(SRC_DIR)/gcc-$(GCC_VERSION) $*/gcc/src
	ln -sfn $(SYSROOT_SYMLINK) $(SYSROOT_SYMLINK_DIR)/sysroot
	cd $*/gcc/build && \
		CFLAGS="$(CFLAGS)" \
		CXXFLAGS="$(CXXFLAGS)" \
		LDFLAGS="$(LDFLAGS)" \
		SOURCE_DATE_EPOCH=$(SOURCE_DATE_EPOCH) \
		../src/configure $(GCC_CONFIG)
	touch $@

%/.gcc.compiled: %/.gcc.configured
	cd $*/gcc/build && \
		$(MAKE) configure-gcc && \
		sed -i 's/ --with-build-sysroot=[^ ]*//' gcc/configargs.h && \
		$(MAKE)
	touch $@

%/.gcc.installed: %/.gcc.compiled
	cd $*/gcc/build && \
		TMPDIR=$$(mktemp -d) && \
		$(MAKE) DESTDIR="$$TMPDIR" install && \
		find "$$TMPDIR" -exec touch -h -d "@$(SOURCE_DATE_EPOCH)" {} \; && \
		mkdir -p $(PREFIX) && \
		cp -a "$$TMPDIR"/* $(PREFIX)/ && \
		rm -rf "$$TMPDIR"
	touch $@
