bootstrap-binutils: $(BOOTSTRAP_BUILD_DIR)/.binutils.installed
binutils: $(TARGET_BUILD_DIR)/.binutils.installed

%/.binutils.installed: CFLAGS := -g0 -O2 -ffile-prefix-map=$(SRC_DIR)=. -ffile-prefix-map=$*=.
%/.binutils.installed: CXXFLAGS := -g0 -O2 -ffile-prefix-map=$(SRC_DIR)=. -ffile-prefix-map=$*=.
%/.binutils.installed: SOURCE_DATE_EPOCH = $(shell cat $*/binutils/src/.timestamp 2>/dev/null || echo 1)

%/.binutils.installed: DYNAMIC_LINKER = $(shell find $(SYSROOT)/usr/lib -name "ld-linux-*.so.*" -type f -printf "%f\n" | head -n 1 || (echo "Error: No dynamic linker found in $(SYSROOT)/usr/lib" >&2; exit 1))
%/.binutils.installed: LDFLAGS = -L$(SYSROOT)/usr/lib -Wl,-rpath=$(SYSROOT)/usr/lib -Wl,--dynamic-linker=$(SYSROOT)/usr/lib/$(DYNAMIC_LINKER)
$(BOOTSTRAP_BUILD_DIR)/.binutils.installed $(BUILD_BUILD_DIR)/.binutils.installed: LDFLAGS :=

$(BOOTSTRAP_BUILD_DIR)/.binutils.installed: HOST_TRIPLE := $(BUILD_TRIPLE)
$(BOOTSTRAP_BUILD_DIR)/.binutils.installed: TARGET_TRIPLE := $(BUILD_TRIPLE)
$(BOOTSTRAP_BUILD_DIR)/.binutils.installed: PREFIX := $(BOOTSTRAP_PREFIX)
# there's no bootstrap sysroot
$(BOOTSTRAP_BUILD_DIR)/.binutils.installed: SYSROOT := $(BUILD_SYSROOT)
$(BOOTSTRAP_BUILD_DIR)/.binutils.installed: PATH := $(ORIG_PATH)

$(BUILD_BUILD_DIR)/.binutils.installed: HOST_TRIPLE := $(BUILD_TRIPLE)
$(BUILD_BUILD_DIR)/.binutils.installed: TARGET_TRIPLE := $(BUILD_TRIPLE)
$(BUILD_BUILD_DIR)/.binutils.installed: PREFIX := $(BUILD_PREFIX)
$(BUILD_BUILD_DIR)/.binutils.installed: SYSROOT := $(BUILD_SYSROOT)
$(BUILD_BUILD_DIR)/.binutils.installed: PATH := $(BOOTSTRAP_PREFIX)/bin:$(ORIG_PATH)

$(CROSS_BUILD_DIR)/.binutils.installed: HOST_TRIPLE := $(BUILD_TRIPLE)
$(CROSS_BUILD_DIR)/.binutils.installed: TARGET_TRIPLE := $(HOST_TRIPLE)
$(CROSS_BUILD_DIR)/.binutils.installed: PREFIX := $(CROSS_PREFIX)
$(CROSS_BUILD_DIR)/.binutils.installed: SYSROOT := $(CROSS_SYSROOT)
$(CROSS_BUILD_DIR)/.binutils.installed: PATH := $(BUILD_PREFIX)/bin:$(ORIG_PATH)

$(TARGET_BUILD_DIR)/.binutils.installed: PREFIX := $(TARGET_PREFIX)
$(TARGET_BUILD_DIR)/.binutils.installed: SYSROOT := $(TARGET_SYSROOT)
$(TARGET_BUILD_DIR)/.binutils.installed: PATH := $(BOOTSTRAP_PREFIX)/bin:$(ORIG_PATH)

BINUTILS_CONFIG = \
	--host=$(HOST_TRIPLE) \
	--target=$(TARGET_TRIPLE) \
	--prefix= \
	--with-sysroot=/sysroot \
	--program-prefix=$(TARGET_TRIPLE)- \
	--disable-shared \
	--enable-new-dtags \
	--disable-werror

.PRECIOUS: %/.binutils.configured %/.binutils.compiled

%/.binutils.configured: $(SRC_DIR)/binutils-$(BINUTILS_VERSION)
	mkdir -p $*/binutils/build
	ln -sfn $(SRC_DIR)/binutils-$(BINUTILS_VERSION) $*/binutils/src
	cd $*/binutils/build && \
		CFLAGS="$(CFLAGS)" \
		CXXFLAGS="$(CXXFLAGS)" \
		LDFLAGS="$(LDFLAGS)" \
		SOURCE_DATE_EPOCH=$(SOURCE_DATE_EPOCH) \
		../src/configure $(BINUTILS_CONFIG)
	touch $@

%/.binutils.compiled: %/.binutils.configured
	cd $*/binutils/build && $(MAKE)
	touch $@

%/.binutils.installed: %/.binutils.compiled
	cd $*/binutils/build && \
		TMPDIR=$$(mktemp -d) && \
		$(MAKE) DESTDIR="$$TMPDIR" install && \
		find "$$TMPDIR" -exec touch -h -d "@$(SOURCE_DATE_EPOCH)" {} \; && \
		$(PROJECT_ROOT)/script/replace-binutils-hardlinks.sh "$$TMPDIR" "$(TARGET_TRIPLE)" && \
		mkdir -p $(PREFIX) && \
		cp -a "$$TMPDIR"/* $(PREFIX)/ && \
		rm -rf "$$TMPDIR"
	touch $@
