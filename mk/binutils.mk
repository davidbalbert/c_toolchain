bootstrap-binutils: $(BB)/.binutils.installed
bootstrap-binutils: CFLAGS := -g0 -O2 -ffile-prefix-map=$(SRC_DIR)=. -ffile-prefix-map=$(BB)=.
bootstrap-binutils: CXXFLAGS := -g0 -O2 -ffile-prefix-map=$(SRC_DIR)=. -ffile-prefix-map=$(BB)=.
bootstrap-binutils: SOURCE_DATE_EPOCH := $(shell cat $(BB)/binutils/src/.timestamp 2>/dev/null || echo 1)

BINUTILS_CONFIG := \
	--host=$(BUILD_TRIPLE) \
	--target=$(BUILD_TRIPLE) \
	--prefix= \
	--with-sysroot=/sysroot \
	--program-prefix=$(BUILD_TRIPLE)- \
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
