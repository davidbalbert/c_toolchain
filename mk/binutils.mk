bootstrap-binutils: $(BB)/.binutils.installed
bootstrap-binutils: CFLAGS := -g0 -O2 -ffile-prefix-map=$(SRC_DIR)=. -ffile-prefix-map=$(BB)=.
bootstrap-binutils: CXXFLAGS := -g0 -O2 -ffile-prefix-map=$(SRC_DIR)=. -ffile-prefix-map=$(BB)=.
bootstrap-binutils: SOURCE_DATE_EPOCH := $(shell cat $(BB)/binutils/src/.timestamp 2>/dev/null || echo 1)

binutils: $(B)/.binutils.installed
binutils: CFLAGS := -g0 -O2 -ffile-prefix-map=$(SRC_DIR)=. -ffile-prefix-map=$(B)=.
binutils: CXXFLAGS := -g0 -O2 -ffile-prefix-map=$(SRC_DIR)=. -ffile-prefix-map=$(B)=.
binutils: SOURCE_DATE_EPOCH := $(shell cat $(B)/binutils/src/.timestamp 2>/dev/null || echo 1)

BINUTILS_CONFIG := \
	--host=$(BUILD_TRIPLE) \
	--target=$(BUILD_TRIPLE) \
	--prefix= \
	--with-sysroot=/sysroot \
	--program-prefix=$(BUILD_TRIPLE)- \
	--disable-shared \
	--enable-new-dtags \
	--disable-werror

FINAL_BINUTILS_CONFIG := \
	--host=$(HOST_TRIPLE) \
	--target=$(TARGET_TRIPLE) \
	--prefix= \
	--with-sysroot=/sysroot \
	--program-prefix=$(TARGET_TRIPLE)- \
	--disable-shared \
	--enable-new-dtags \
	--disable-werror

$(BB)/binutils/src: $(BB)/.binutils.linked
$(BB)/binutils/build:
	mkdir -p $@

$(BB)/.binutils.linked: $(SRC_DIR)/binutils-$(BINUTILS_VERSION) | $(BB)/binutils
	ln -sfn $< $(BB)/binutils/src
	touch $@

$(BB)/.binutils.configured: | $(BB)/binutils/src $(BB)/binutils/build $(BO)/toolchain/sysroot
	cd $(BB)/binutils/build && \
		CFLAGS="$(CFLAGS)" \
		CXXFLAGS="$(CXXFLAGS)" \
		SOURCE_DATE_EPOCH=$(SOURCE_DATE_EPOCH) \
		../src/configure $(BINUTILS_CONFIG)
	touch $@

$(BB)/.binutils.compiled: | $(BB)/.binutils.configured
	cd $(BB)/binutils/build && $(MAKE)
	touch $@

$(BB)/.binutils.installed: | $(BB)/.binutils.compiled
	cd $(BB)/binutils/build && \
		TMPDIR=$$(mktemp -d) && \
		$(MAKE) DESTDIR="$$TMPDIR" install && \
		find "$$TMPDIR" -exec touch -h -d "@$(SOURCE_DATE_EPOCH)" {} \; && \
		$(PROJECT_ROOT)/script/replace-binutils-hardlinks.sh "$$TMPDIR" "$(BUILD_TRIPLE)" && \
		cp -a "$$TMPDIR"/* $(BO)/toolchain/ && \
		rm -rf "$$TMPDIR"
	touch $@

# Final binutils targets
$(B)/binutils/src: $(B)/.binutils.linked
$(B)/binutils/build:
	mkdir -p $@

$(B)/.binutils.linked: $(SRC_DIR)/binutils-$(BINUTILS_VERSION) | $(B)/binutils
	ln -sfn $< $(B)/binutils/src
	touch $@

$(B)/.binutils.configured: | $(B)/binutils/src $(B)/binutils/build $(O)/toolchain/sysroot
	cd $(B)/binutils/build && \
		DYNAMIC_LINKER=$$(find $(SYSROOT)/usr/lib -name "ld-linux-*.so.*" -type f -printf "%f\n" | head -n 1) && \
		if [ -z "$$DYNAMIC_LINKER" ]; then echo "Error: No dynamic linker found in $(SYSROOT)/usr/lib"; exit 1; fi && \
		CFLAGS="$(CFLAGS)" \
		CXXFLAGS="$(CXXFLAGS)" \
		SOURCE_DATE_EPOCH=$(SOURCE_DATE_EPOCH) \
		../src/configure $(FINAL_BINUTILS_CONFIG) \
		LDFLAGS="-L$(SYSROOT)/usr/lib -Wl,-rpath=$(SYSROOT)/usr/lib -Wl,--dynamic-linker=$(SYSROOT)/usr/lib/$$DYNAMIC_LINKER"
	touch $@

$(B)/.binutils.compiled: | $(B)/.binutils.configured
	cd $(B)/binutils/build && $(MAKE)
	touch $@

$(B)/.binutils.installed: | $(B)/.binutils.compiled
	cd $(B)/binutils/build && \
		TMPDIR=$$(mktemp -d) && \
		$(MAKE) DESTDIR="$$TMPDIR" install && \
		find "$$TMPDIR" -exec touch -h -d "@$(SOURCE_DATE_EPOCH)" {} \; && \
		$(PROJECT_ROOT)/script/replace-binutils-hardlinks.sh "$$TMPDIR" "$(TARGET_TRIPLE)" && \
		cp -a "$$TMPDIR"/* $(O)/toolchain/ && \
		rm -rf "$$TMPDIR"
	touch $@
