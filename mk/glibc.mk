bootstrap-glibc: $(BOOTSTRAP_OUT_DIR)/.glibc.installed
glibc: $(TARGET_OUT_DIR)/.glibc.installed

$(BOOTSTRAP_BUILD_DIR)/.glibc.installed: PATH := $(BOOTSTRAP_PREFIX)/bin:$(ORIG_PATH)
$(BOOTSTRAP_BUILD_DIR)/.glibc.installed: CFLAGS := -O2 -g -ffile-prefix-map=$(SRC_DIR)=. -ffile-prefix-map=$(BOOTSTRAP_BUILD_DIR)=.
$(BOOTSTRAP_BUILD_DIR)/.glibc.installed: CXXFLAGS := -O2 -g -ffile-prefix-map=$(SRC_DIR)=. -ffile-prefix-map=$(BOOTSTRAP_BUILD_DIR)=.
$(BOOTSTRAP_BUILD_DIR)/.glibc.installed: SOURCE_DATE_EPOCH := $(shell cat $(BOOTSTRAP_BUILD_DIR)/glibc/src/.timestamp 2>/dev/null || echo 1)
$(BOOTSTRAP_BUILD_DIR)/.glibc.installed: SYSROOT := $(BOOTSTRAP_SYSROOT)

$(CROSS_BUILD_DIR)/.glibc.installed: PATH := $(CROSS_PREFIX)/bin:$(ORIG_PATH)
$(CROSS_BUILD_DIR)/.glibc.installed: CFLAGS := -O2 -g -ffile-prefix-map=$(SRC_DIR)=. -ffile-prefix-map=$(CROSS_BUILD_DIR)=.
$(CROSS_BUILD_DIR)/.glibc.installed: CXXFLAGS := -O2 -g -ffile-prefix-map=$(SRC_DIR)=. -ffile-prefix-map=$(CROSS_BUILD_DIR)=.
$(CROSS_BUILD_DIR)/.glibc.installed: SOURCE_DATE_EPOCH := $(shell cat $(CROSS_BUILD_DIR)/glibc/src/.timestamp 2>/dev/null || echo 1)
$(CROSS_BUILD_DIR)/.glibc.installed: SYSROOT := $(CROSS_SYSROOT)

$(TARGET_BUILD_DIR)/.glibc.installed: PATH := $(TARGET_PREFIX)/bin:$(ORIG_PATH)
$(TARGET_BUILD_DIR)/.glibc.installed: CFLAGS := -O2 -g -ffile-prefix-map=$(SRC_DIR)=. -ffile-prefix-map=$(TARGET_BUILD_DIR)=.
$(TARGET_BUILD_DIR)/.glibc.installed: CXXFLAGS := -O2 -g -ffile-prefix-map=$(SRC_DIR)=. -ffile-prefix-map=$(TARGET_BUILD_DIR)=.
$(TARGET_BUILD_DIR)/.glibc.installed: SOURCE_DATE_EPOCH := $(shell cat $(TARGET_BUILD_DIR)/glibc/src/.timestamp 2>/dev/null || echo 1)
$(TARGET_BUILD_DIR)/.glibc.installed: SYSROOT := $(TARGET_SYSROOT)

$(BOOTSTRAP_BUILD_DIR)/.glibc.configured: $(BOOTSTRAP_OUT_DIR)/.gcc.installed $(BOOTSTRAP_OUT_DIR)/.linux-headers.installed
$(CROSS_BUILD_DIR)/.glibc.configured: $(CROSS_OUT_DIR)/.gcc.installed $(BOOTSTRAP_OUT_DIR)/.linux-headers.installed
$(TARGET_BUILD_DIR)/.glibc.configured: $(TARGET_OUT_DIR)/.gcc.installed $(BOOTSTRAP_OUT_DIR)/.linux-headers.installed

GLIBC_CONFIG = \
	--prefix=/usr \
	--host=$(TARGET_TRIPLE) \
	--enable-kernel=$(GLIBC_KERNEL_VERSION) \
	--with-headers=$(SYSROOT)/usr/include \
	libc_cv_slibdir=/usr/lib

%/.glibc.configured: $(SRC_DIR)/glibc-$(GLIBC_VERSION)
	mkdir -p $*/glibc/build $(SYSROOT)
	ln -sfn $(SRC_DIR)/glibc-$(GLIBC_VERSION) $*/glibc/src
	cd $*/glibc/build && \
		CFLAGS="$(CFLAGS)" \
		CXXFLAGS="$(CXXFLAGS)" \
		SOURCE_DATE_EPOCH=$(SOURCE_DATE_EPOCH) \
		../src/configure $(GLIBC_CONFIG)
	touch $@

%/.glibc.compiled: %/.glibc.configured
	cd $*/glibc/build && $(MAKE)
	touch $@

%/.glibc.installed: %/.glibc.compiled
	cd $*/glibc/build && \
		TMPDIR=$$(mktemp -d) && \
		$(MAKE) DESTDIR="$$TMPDIR" install && \
		find "$$TMPDIR" -exec touch -h -d "@$(SOURCE_DATE_EPOCH)" {} \; && \
		cp -a "$$TMPDIR"/* $(SYSROOT)/ && \
		rm -rf "$$TMPDIR"
	touch $@
