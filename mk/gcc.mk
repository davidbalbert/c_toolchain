bootstrap-gcc: $(BOOTSTRAP_BUILD_DIR)/.gcc.installed
gcc: $(TARGET_BUILD_DIR)/.gcc.installed

$(BOOTSTRAP_BUILD_DIR)/.gcc.installed: HOST_TRIPLE := $(BUILD_TRIPLE)
$(BOOTSTRAP_BUILD_DIR)/.gcc.installed: TARGET_TRIPLE := $(BUILD_TRIPLE)
$(BOOTSTRAP_BUILD_DIR)/.gcc.installed: PREFIX := $(BOOTSTRAP_PREFIX)
$(BOOTSTRAP_BUILD_DIR)/.gcc.installed: SYSROOT := $(BUILD_SYSROOT) # there's no bootstrap sysroot
$(BOOTSTRAP_BUILD_DIR)/.gcc.installed: PATH := $(BOOTSTRAP_PREFIX)/bin:$(ORIG_PATH)
$(BOOTSTRAP_BUILD_DIR)/.gcc.installed: CFLAGS := -g0 -O2 -ffile-prefix-map=$(SRC_DIR)=. -ffile-prefix-map=$(BOOTSTRAP_BUILD_DIR)=.
$(BOOTSTRAP_BUILD_DIR)/.gcc.installed: CXXFLAGS := -g0 -O2 -ffile-prefix-map=$(SRC_DIR)=. -ffile-prefix-map=$(BOOTSTRAP_BUILD_DIR)=.
$(BOOTSTRAP_BUILD_DIR)/.gcc.installed: SYSROOT_SYMLINK := ../../../$(HOST)/$(TOOLCHAIN_NAME)/sysroot
$(BOOTSTRAP_BUILD_DIR)/.gcc.installed: SYSROOT_SYMLINK_DIR := $(BOOTSTRAP_OUT_DIR)/toolchain

$(BOOTSTRAP_BUILD_DIR)/.gcc.installed: SOURCE_DATE_EPOCH = $(shell cat $(BOOTSTRAP_BUILD_DIR)/gcc/src/.timestamp 2>/dev/null || echo 1)
$(BOOTSTRAP_BUILD_DIR)/.gcc.installed: GCC_CONFIG = $(GCC_BASE_CONFIG) $(GCC_BOOTSTRAP_CONFIG)


$(BUILD_BUILD_DIR)/.gcc.installed: HOST_TRIPLE := $(BUILD_TRIPLE)
$(BUILD_BUILD_DIR)/.gcc.installed: TARGET_TRIPLE := $(BUILD_TRIPLE)
$(BUILD_BUILD_DIR)/.gcc.installed: PREFIX := $(BUILD_PREFIX)
$(BUILD_BUILD_DIR)/.gcc.installed: SYSROOT := $(BUILD_SYSROOT)
$(BUILD_BUILD_DIR)/.gcc.installed: PATH := $(BUILD_PREFIX)/bin:$(BOOTSTRAP_PREFIX)/bin:$(ORIG_PATH)
$(BUILD_BUILD_DIR)/.gcc.installed: CFLAGS := -g0 -O2 -ffile-prefix-map=$(SRC_DIR)=. -ffile-prefix-map=$(BUILD_BUILD_DIR)=.
$(BUILD_BUILD_DIR)/.gcc.installed: CXXFLAGS := -g0 -O2 -ffile-prefix-map=$(SRC_DIR)=. -ffile-prefix-map=$(BUILD_BUILD_DIR)=.
$(BUILD_BUILD_DIR)/.gcc.installed: SYSROOT_SYMLINK := ../sysroot
$(BUILD_BUILD_DIR)/.gcc.installed: SYSROOT_SYMLINK_DIR := $(BUILD_OUT_DIR)/toolchain
$(BUILD_BUILD_DIR)/.gcc.installed: BUILD_TIME_TOOLS := $(if $(wildcard $(BUILD_PREFIX)/bin/$(TARGET_TRIPLE)-gcc),,--with-build-time-tools=$(BUILD_PREFIX)/$(TARGET_TRIPLE)/bin)

$(BUILD_BUILD_DIR)/.gcc.installed: SOURCE_DATE_EPOCH = $(shell cat $(BUILD_BUILD_DIR)/gcc/src/.timestamp 2>/dev/null || echo 1)
$(BUILD_BUILD_DIR)/.gcc.installed: DYNAMIC_LINKER = $(shell find $(BUILD_SYSROOT)/usr/lib -name "ld-linux-*.so.*" -type f -printf "%f\n" | head -n 1 || (echo "Error: No dynamic linker found in $(BUILD_SYSROOT)/usr/lib" >&2; exit 1))
$(BUILD_BUILD_DIR)/.gcc.installed: LDFLAGS = -L$(BUILD_SYSROOT)/usr/lib -Wl,-rpath=$(BUILD_SYSROOT)/usr/lib -Wl,--dynamic-linker=$(BUILD_SYSROOT)/usr/lib/$(DYNAMIC_LINKER)
$(BUILD_BUILD_DIR)/.gcc.installed: GCC_CONFIG = $(GCC_BASE_CONFIG) $(GCC_FINAL_CONFIG) $(BUILD_TIME_TOOLS)


$(CROSS_BUILD_DIR)/.gcc.installed: PREFIX := $(HOST_PREFIX)
$(CROSS_BUILD_DIR)/.gcc.installed: SYSROOT := $(HOST_SYSROOT)
$(CROSS_BUILD_DIR)/.gcc.installed: PATH := $(HOST_PREFIX)/bin:$(ORIG_PATH)
$(CROSS_BUILD_DIR)/.gcc.installed: CFLAGS := -g0 -O2 -ffile-prefix-map=$(SRC_DIR)=. -ffile-prefix-map=$(CROSS_BUILD_DIR)=.
$(CROSS_BUILD_DIR)/.gcc.installed: CXXFLAGS := -g0 -O2 -ffile-prefix-map=$(SRC_DIR)=. -ffile-prefix-map=$(CROSS_BUILD_DIR)=.
$(CROSS_BUILD_DIR)/.gcc.installed: SYSROOT_SYMLINK := ../sysroot
$(CROSS_BUILD_DIR)/.gcc.installed: SYSROOT_SYMLINK_DIR := $(CROSS_OUT_DIR)/toolchain
$(CROSS_BUILD_DIR)/.gcc.installed: BUILD_TIME_TOOLS := $(if $(wildcard $(HOST_PREFIX)/bin/$(TARGET_TRIPLE)-gcc),,--with-build-time-tools=$(HOST_PREFIX)/$(TARGET_TRIPLE)/bin)

$(CROSS_BUILD_DIR)/.gcc.installed: SOURCE_DATE_EPOCH = $(shell cat $(CROSS_BUILD_DIR)/gcc/src/.timestamp 2>/dev/null || echo 1)
$(CROSS_BUILD_DIR)/.gcc.installed: DYNAMIC_LINKER = $(shell find $(SYSROOT)/usr/lib -name "ld-linux-*.so.*" -type f -printf "%f\n" | head -n 1 || (echo "Error: No dynamic linker found in $(SYSROOT)/usr/lib" >&2; exit 1))
$(CROSS_BUILD_DIR)/.gcc.installed: LDFLAGS = -L$(SYSROOT)/usr/lib -Wl,-rpath=$(SYSROOT)/usr/lib -Wl,--dynamic-linker=$(SYSROOT)/usr/lib/$(DYNAMIC_LINKER)
$(CROSS_BUILD_DIR)/.gcc.installed: GCC_CONFIG = $(GCC_BASE_CONFIG) $(GCC_FINAL_CONFIG) $(BUILD_TIME_TOOLS)

$(TARGET_BUILD_DIR)/.gcc.installed: PREFIX := $(TARGET_PREFIX)
$(TARGET_BUILD_DIR)/.gcc.installed: SYSROOT := $(SYSROOT)
$(TARGET_BUILD_DIR)/.gcc.installed: PATH := $(TARGET_PREFIX)/bin:$(BOOTSTRAP_PREFIX)/bin:$(ORIG_PATH)
$(TARGET_BUILD_DIR)/.gcc.installed: CFLAGS := -g0 -O2 -ffile-prefix-map=$(SRC_DIR)=. -ffile-prefix-map=$(TARGET_BUILD_DIR)=.
$(TARGET_BUILD_DIR)/.gcc.installed: CXXFLAGS := -g0 -O2 -ffile-prefix-map=$(SRC_DIR)=. -ffile-prefix-map=$(TARGET_BUILD_DIR)=.
$(TARGET_BUILD_DIR)/.gcc.installed: SOURCE_DATE_EPOCH = $(shell cat $(TARGET_BUILD_DIR)/gcc/src/.timestamp 2>/dev/null || echo 1)
$(TARGET_BUILD_DIR)/.gcc.installed: SYSROOT_SYMLINK := ../sysroot
$(TARGET_BUILD_DIR)/.gcc.installed: SYSROOT_SYMLINK_DIR := $(TARGET_OUT_DIR)/toolchain
$(TARGET_BUILD_DIR)/.gcc.installed: BUILD_TIME_TOOLS := $(if $(wildcard $(TARGET_PREFIX)/bin/$(TARGET_TRIPLE)-gcc),,--with-build-time-tools=$(TARGET_PREFIX)/$(TARGET_TRIPLE)/bin)

$(TARGET_BUILD_DIR)/.gcc.installed: DYNAMIC_LINKER = $(shell find $(SYSROOT)/usr/lib -name "ld-linux-*.so.*" -type f -printf "%f\n" | head -n 1 || (echo "Error: No dynamic linker found in $(SYSROOT)/usr/lib" >&2; exit 1))
$(TARGET_BUILD_DIR)/.gcc.installed: LDFLAGS = -L$(SYSROOT)/usr/lib -Wl,-rpath=$(SYSROOT)/usr/lib -Wl,--dynamic-linker=$(SYSROOT)/usr/lib/$(DYNAMIC_LINKER)
$(TARGET_BUILD_DIR)/.gcc.installed: GCC_CONFIG = $(GCC_BASE_CONFIG) $(GCC_FINAL_CONFIG) $(BUILD_TIME_TOOLS)

$(BOOTSTRAP_BUILD_DIR)/.gcc.configured: $(BOOTSTRAP_BUILD_DIR)/.binutils.installed
$(TARGET_BUILD_DIR)/.gcc.configured: $(TARGET_BUILD_DIR)/.binutils.installed $(BOOTSTRAP_BUILD_DIR)/.glibc.installed
$(CROSS_BUILD_DIR)/.gcc.configured: $(CROSS_BUILD_DIR)/.binutils.installed $(BOOTSTRAP_BUILD_DIR)/.glibc.installed

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

.PRECIOUS: %/.gcc.configured %/.gcc.compiled

%/.gcc.configured: $(SRC_DIR)/gcc-$(GCC_VERSION)
	mkdir -p $*/gcc/build $(PREFIX) $(SYSROOT) $(SYSROOT_SYMLINK_DIR)
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
