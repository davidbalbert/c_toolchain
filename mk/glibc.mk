bootstrap-glibc: $(BB)/.glibc.installed
bootstrap-glibc: PATH := $(BOOTSTRAP_PREFIX)/bin:$(ORIG_PATH)
bootstrap-glibc: CFLAGS := -O2 -g -ffile-prefix-map=$(SRC_DIR)=. -ffile-prefix-map=$(BB)=.
bootstrap-glibc: CXXFLAGS := -O2 -g -ffile-prefix-map=$(SRC_DIR)=. -ffile-prefix-map=$(BB)=.
bootstrap-glibc: SOURCE_DATE_EPOCH := $(shell cat $(BB)/glibc/src/.timestamp 2>/dev/null || echo 1)

glibc: $(B)/.glibc.installed
glibc: PATH := $(NATIVE_PREFIX)/bin:$(ORIG_PATH)
glibc: CFLAGS := -O2 -g -ffile-prefix-map=$(SRC_DIR)=. -ffile-prefix-map=$(B)=.
glibc: CXXFLAGS := -O2 -g -ffile-prefix-map=$(SRC_DIR)=. -ffile-prefix-map=$(B)=.
glibc: SOURCE_DATE_EPOCH := $(shell cat $(B)/glibc/src/.timestamp 2>/dev/null || echo 1)

GLIBC_CONFIG = \
	--prefix=/usr \
	--host=$(TARGET_TRIPLE) \
	--enable-kernel=$(GLIBC_KERNEL_VERSION) \
	--with-headers=$(SYSROOT)/usr/include \
	libc_cv_slibdir=/usr/lib

# Static pattern rules for both bootstrap and final builds
$(BB)/.glibc.configured: | bootstrap-gcc linux-headers
$(B)/.glibc.configured: | gcc linux-headers
$(BB)/.glibc.configured $(B)/.glibc.configured: %/.glibc.configured: $(SRC_DIR)/glibc-$(GLIBC_VERSION)
	mkdir -p $*/glibc/build $(SYSROOT)
	ln -sfn $(SRC_DIR)/glibc-$(GLIBC_VERSION) $*/glibc/src
	cd $*/glibc/build && \
		CFLAGS="$(CFLAGS)" \
		CXXFLAGS="$(CXXFLAGS)" \
		SOURCE_DATE_EPOCH=$(SOURCE_DATE_EPOCH) \
		../src/configure $(GLIBC_CONFIG)
	touch $@

$(BB)/.glibc.compiled $(B)/.glibc.compiled: %/.glibc.compiled: | %/.glibc.configured
	cd $*/glibc/build && $(MAKE)
	touch $@

$(BB)/.glibc.installed $(B)/.glibc.installed: %/.glibc.installed: | %/.glibc.compiled
	cd $*/glibc/build && \
		TMPDIR=$$(mktemp -d) && \
		$(MAKE) DESTDIR="$$TMPDIR" install && \
		find "$$TMPDIR" -exec touch -h -d "@$(SOURCE_DATE_EPOCH)" {} \; && \
		cp -a "$$TMPDIR"/* $(SYSROOT)/ && \
		rm -rf "$$TMPDIR"
	touch $@
