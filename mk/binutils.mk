bootstrap-binutils: $(BB)/.binutils.installed
bootstrap-binutils: HOST_TRIPLE := $(BUILD_TRIPLE)
bootstrap-binutils: TARGET_TRIPLE := $(BUILD_TRIPLE)
bootstrap-binutils: PREFIX := $(BOOTSTRAP_PREFIX)
bootstrap-binutils: PATH := $(ORIG_PATH)
bootstrap-binutils: CFLAGS := -g0 -O2 -ffile-prefix-map=$(SRC_DIR)=. -ffile-prefix-map=$(BB)=.
bootstrap-binutils: CXXFLAGS := -g0 -O2 -ffile-prefix-map=$(SRC_DIR)=. -ffile-prefix-map=$(BB)=.
bootstrap-binutils: LDFLAGS :=
bootstrap-binutils: SOURCE_DATE_EPOCH := $(shell cat $(BB)/binutils/src/.timestamp 2>/dev/null || echo 1)
bootstrap-binutils: DYNAMIC_LINKER_SETUP := true

binutils: $(B)/.binutils.installed
binutils: PREFIX := $(NATIVE_PREFIX)
binutils: PATH := $(BOOTSTRAP_PREFIX)/bin:$(ORIG_PATH)
binutils: CFLAGS := -g0 -O2 -ffile-prefix-map=$(SRC_DIR)=. -ffile-prefix-map=$(B)=.
binutils: CXXFLAGS := -g0 -O2 -ffile-prefix-map=$(SRC_DIR)=. -ffile-prefix-map=$(B)=.
binutils: LDFLAGS := -L$(SYSROOT)/usr/lib -Wl,-rpath=$(SYSROOT)/usr/lib -Wl,--dynamic-linker=$(SYSROOT)/usr/lib/$$DYNAMIC_LINKER
binutils: SOURCE_DATE_EPOCH := $(shell cat $(B)/binutils/src/.timestamp 2>/dev/null || echo 1)
binutils: DYNAMIC_LINKER_SETUP := DYNAMIC_LINKER=$$(find $(SYSROOT)/usr/lib -name "ld-linux-*.so.*" -type f -printf "%f\n" | head -n 1) && if [ -z "$$DYNAMIC_LINKER" ]; then echo "Error: No dynamic linker found in $(SYSROOT)/usr/lib"; exit 1; fi

BINUTILS_CONFIG = \
	--host=$(HOST_TRIPLE) \
	--target=$(TARGET_TRIPLE) \
	--prefix= \
	--with-sysroot=/sysroot \
	--program-prefix=$(TARGET_TRIPLE)- \
	--disable-shared \
	--enable-new-dtags \
	--disable-werror

$(BB)/.binutils.configured $(B)/.binutils.configured: %/.binutils.configured: $(SRC_DIR)/binutils-$(BINUTILS_VERSION)
	mkdir -p $*/binutils/build
	ln -sfn $(SRC_DIR)/binutils-$(BINUTILS_VERSION) $*/binutils/src
	cd $*/binutils/build && \
		$(DYNAMIC_LINKER_SETUP) && \
		CFLAGS="$(CFLAGS)" \
		CXXFLAGS="$(CXXFLAGS)" \
		LDFLAGS="$(LDFLAGS)" \
		SOURCE_DATE_EPOCH=$(SOURCE_DATE_EPOCH) \
		../src/configure $(BINUTILS_CONFIG)
	touch $@

$(BB)/.binutils.compiled $(B)/.binutils.compiled: %/.binutils.compiled: | %/.binutils.configured
	cd $*/binutils/build && $(MAKE)
	touch $@

$(BB)/.binutils.installed $(B)/.binutils.installed: %/.binutils.installed: | %/.binutils.compiled
	cd $*/binutils/build && \
		TMPDIR=$$(mktemp -d) && \
		$(MAKE) DESTDIR="$$TMPDIR" install && \
		find "$$TMPDIR" -exec touch -h -d "@$(SOURCE_DATE_EPOCH)" {} \; && \
		$(PROJECT_ROOT)/script/replace-binutils-hardlinks.sh "$$TMPDIR" "$(TARGET_TRIPLE)" && \
		mkdir -p $(PREFIX) && \
		cp -a "$$TMPDIR"/* $(PREFIX)/ && \
		rm -rf "$$TMPDIR"
	touch $@
