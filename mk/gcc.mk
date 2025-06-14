bootstrap-gcc: | $(BB)/.gcc.installed
bootstrap-gcc: CFLAGS := -g0 -O2 -ffile-prefix-map=$(SRC_DIR)=. -ffile-prefix-map=$(BB)=.
bootstrap-gcc: CXXFLAGS := -g0 -O2 -ffile-prefix-map=$(SRC_DIR)=. -ffile-prefix-map=$(BB)=.
bootstrap-gcc: SOURCE_DATE_EPOCH := $(shell cat $(BB)/gcc/src/.timestamp 2>/dev/null || echo 1)

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
	--with-gxx-include-dir=$(SYSROOT)/usr/include/c++/$(GCC_VERSION)

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
