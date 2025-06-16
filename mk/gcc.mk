bootstrap-gcc: PATH := $(BOOTSTRAP_PREFIX)/bin:$(ORIG_PATH)
bootstrap-gcc: | $(BB)/.gcc.installed
bootstrap-gcc: CFLAGS := -g0 -O2 -ffile-prefix-map=$(SRC_DIR)=. -ffile-prefix-map=$(BB)=.
bootstrap-gcc: CXXFLAGS := -g0 -O2 -ffile-prefix-map=$(SRC_DIR)=. -ffile-prefix-map=$(BB)=.
bootstrap-gcc: SOURCE_DATE_EPOCH := $(shell cat $(BB)/gcc/src/.timestamp 2>/dev/null || echo 1)

# Use final binutils (NATIVE_PREFIX) and bootstrap gcc
gcc: PATH := $(NATIVE_PREFIX)/bin:$(BOOTSTRAP_PREFIX)/bin:$(ORIG_PATH)
gcc: | $(B)/.gcc.done
gcc: CFLAGS := -g0 -O2 -ffile-prefix-map=$(SRC_DIR)=. -ffile-prefix-map=$(B)=.
gcc: CXXFLAGS := -g0 -O2 -ffile-prefix-map=$(SRC_DIR)=. -ffile-prefix-map=$(B)=.
gcc: SOURCE_DATE_EPOCH := $(shell cat $(B)/gcc/src/.timestamp 2>/dev/null || echo 1)

GCC_BASE_CONFIG := \
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

GCC_BOOTSTRAP_CONFIG := \
	$(GCC_BASE_CONFIG) \
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

GCC_CONFIG := \
	$(GCC_BASE_CONFIG) \
	--enable-host-pie \
	--disable-fixincludes

# Bootstrap GCC

$(BB)/gcc/src: $(BB)/.gcc.linked
$(BB)/gcc/build:
	mkdir -p $@

$(BB)/.gcc.linked: $(SRC_DIR)/gcc-$(GCC_VERSION) | $(BB)/gcc
	ln -sfn $< $(BB)/gcc/src
	touch $@

$(BB)/.gcc.configured: | bootstrap-binutils $(BB)/gcc/src $(BB)/gcc/build $(BO)/toolchain/sysroot
	cd $(BB)/gcc/build && \
		CFLAGS="$(CFLAGS)" \
		CXXFLAGS="$(CXXFLAGS)" \
		SOURCE_DATE_EPOCH=$(SOURCE_DATE_EPOCH) \
		../src/configure $(GCC_BOOTSTRAP_CONFIG)
	touch $@

$(BB)/.gcc.compiled: | $(BB)/.gcc.configured
	cd $(BB)/gcc/build && \
		$(MAKE) configure-gcc && \
		sed -i 's/ --with-build-sysroot=[^ ]*//' gcc/configargs.h && \
		$(MAKE)
	touch $@

$(BB)/.gcc.installed: | $(BB)/.gcc.compiled
	cd $(BB)/gcc/build && \
		TMPDIR=$$(mktemp -d) && \
		$(MAKE) DESTDIR="$$TMPDIR" install && \
		find "$$TMPDIR" -exec touch -h -d "@$(SOURCE_DATE_EPOCH)" {} \; && \
		cp -a "$$TMPDIR"/* $(BO)/toolchain/ && \
		rm -rf "$$TMPDIR"
	touch $@


# Final GCC

$(B)/gcc/src: $(B)/.gcc.linked
$(B)/gcc/build:
	mkdir -p $@

$(B)/.gcc.linked: $(SRC_DIR)/gcc-$(GCC_VERSION) | $(B)/gcc
	ln -sfn $< $(B)/gcc/src
	touch $@

$(B)/.gcc.configured: | binutils bootstrap-glibc $(B)/gcc/src $(B)/gcc/build
	cd $(B)/gcc/build && \
		DYNAMIC_LINKER=$$(find $(SYSROOT)/usr/lib -name "ld-linux-*.so.*" -type f -printf "%f\n" | head -n 1) && \
		if [ -z "$$DYNAMIC_LINKER" ]; then echo "Error: No dynamic linker found in $(SYSROOT)/usr/lib"; exit 1; fi && \
		if [ ! -x "$(NATIVE_PREFIX)/bin/$(TARGET_TRIPLE)-gcc" ]; then \
			EXTRA_CONFIG="--with-build-time-tools=$(NATIVE_PREFIX)/$(TARGET_TRIPLE)/bin"; \
		else \
			EXTRA_CONFIG=""; \
		fi && \
		CFLAGS="$(CFLAGS)" \
		CXXFLAGS="$(CXXFLAGS)" \
		LDFLAGS="-L$(SYSROOT)/usr/lib -Wl,-rpath=$(SYSROOT)/usr/lib -Wl,--dynamic-linker=$(SYSROOT)/usr/lib/$$DYNAMIC_LINKER" \
		SOURCE_DATE_EPOCH=$(SOURCE_DATE_EPOCH) \
		../src/configure $(GCC_CONFIG) $$EXTRA_CONFIG
	touch $@

$(B)/.gcc.compiled: | $(B)/.gcc.configured
	cd $(B)/gcc/build && \
		$(MAKE) configure-gcc && \
		sed -i 's/ --with-build-sysroot=[^ ]*//' gcc/configargs.h && \
		$(MAKE)
	touch $@

$(B)/.gcc.installed: | $(B)/.gcc.compiled
	cd $(B)/gcc/build && \
		TMPDIR=$$(mktemp -d) && \
		$(MAKE) DESTDIR="$$TMPDIR" install && \
		find "$$TMPDIR" -exec touch -h -d "@$(SOURCE_DATE_EPOCH)" {} \; && \
		cp -a "$$TMPDIR"/* $(TARGET_PREFIX)/ && \
		rm -rf "$$TMPDIR"
	touch $@

$(B)/.gcc.done: | $(B)/.gcc.installed $(TARGET_PREFIX)/sysroot
	touch $@
