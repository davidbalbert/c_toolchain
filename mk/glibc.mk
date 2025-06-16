bootstrap-glibc: PATH := $(BOOTSTRAP_PREFIX)/bin:$(ORIG_PATH)
bootstrap-glibc: $(BB)/.glibc.installed
bootstrap-glibc: CFLAGS := -O2 -g -ffile-prefix-map=$(SRC_DIR)=. -ffile-prefix-map=$(BB)=.
bootstrap-glibc: CXXFLAGS := -O2 -g -ffile-prefix-map=$(SRC_DIR)=. -ffile-prefix-map=$(BB)=.
bootstrap-glibc: SOURCE_DATE_EPOCH := $(shell cat $(BB)/glibc/src/.timestamp 2>/dev/null || echo 1)

glibc: PATH := $(NATIVE_PREFIX)/bin:$(ORIG_PATH)
glibc: $(B)/.glibc.installed
glibc: CFLAGS := -O2 -g -ffile-prefix-map=$(SRC_DIR)=. -ffile-prefix-map=$(B)=.
glibc: CXXFLAGS := -O2 -g -ffile-prefix-map=$(SRC_DIR)=. -ffile-prefix-map=$(B)=.
glibc: SOURCE_DATE_EPOCH := $(shell cat $(B)/glibc/src/.timestamp 2>/dev/null || echo 1)

GLIBC_CONFIG := \
	--prefix=/usr \
	--host=$(TARGET_TRIPLE) \
	--enable-kernel=$(GLIBC_KERNEL_VERSION) \
	--with-headers=$(SYSROOT)/usr/include \
	libc_cv_slibdir=/usr/lib

# Bootstrap glibc

$(BB)/glibc/src: $(BB)/.glibc.linked
$(BB)/glibc/build:
	mkdir -p $@

$(BB)/.glibc.linked: $(SRC_DIR)/glibc-$(GLIBC_VERSION) | $(BB)/glibc
	ln -sfn $< $(BB)/glibc/src
	touch $@

$(BB)/.glibc.configured: | bootstrap-gcc linux-headers $(BB)/glibc/src $(BB)/glibc/build
	cd $(BB)/glibc/build && \
		CFLAGS="$(CFLAGS)" \
		CXXFLAGS="$(CXXFLAGS)" \
		SOURCE_DATE_EPOCH=$(SOURCE_DATE_EPOCH) \
		../src/configure $(GLIBC_CONFIG)
	touch $@

$(BB)/.glibc.compiled: | $(BB)/.glibc.configured
	cd $(BB)/glibc/build && $(MAKE)
	touch $@

$(BB)/.glibc.installed: | $(BB)/.glibc.compiled
	cd $(BB)/glibc/build && \
		TMPDIR=$$(mktemp -d) && \
		$(MAKE) DESTDIR="$$TMPDIR" install && \
		find "$$TMPDIR" -exec touch -h -d "@$(SOURCE_DATE_EPOCH)" {} \; && \
		cp -a "$$TMPDIR"/* $(SYSROOT)/ && \
		rm -rf "$$TMPDIR"
	touch $@

# Final glibc

$(B)/glibc/src: $(B)/.glibc.linked
$(B)/glibc/build:
	mkdir -p $@

$(B)/.glibc.linked: $(SRC_DIR)/glibc-$(GLIBC_VERSION) | $(B)/glibc
	ln -sfn $< $(B)/glibc/src
	touch $@

$(B)/.glibc.configured: | gcc linux-headers $(B)/glibc/src $(B)/glibc/build
	cd $(B)/glibc/build && \
		CFLAGS="$(CFLAGS)" \
		CXXFLAGS="$(CXXFLAGS)" \
		SOURCE_DATE_EPOCH=$(SOURCE_DATE_EPOCH) \
		../src/configure $(GLIBC_CONFIG)
	touch $@

$(B)/.glibc.compiled: | $(B)/.glibc.configured
	cd $(B)/glibc/build && $(MAKE)
	touch $@

$(B)/.glibc.installed: | $(B)/.glibc.compiled
	cd $(B)/glibc/build && \
		TMPDIR=$$(mktemp -d) && \
		$(MAKE) DESTDIR="$$TMPDIR" install && \
		find "$$TMPDIR" -exec touch -h -d "@$(SOURCE_DATE_EPOCH)" {} \; && \
		cp -a "$$TMPDIR"/* $(SYSROOT)/ && \
		rm -rf "$$TMPDIR"
	touch $@
