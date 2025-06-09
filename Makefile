CONFIG ?= config.mk

MKTOOLCHAIN_ROOT := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))

# Reproducable build settings
export LC_ALL := C.UTF-8

ifeq ($(filter -j%,$(MAKEFLAGS)),)
  MAKEFLAGS += -j$(shell nproc)
endif

include $(CONFIG)

BUILD := $(shell uname -s | tr A-Z a-z)/$(shell uname -m)
HOST ?= $(BUILD)
TARGET ?= $(HOST)

# Convert os/arch to GNU triple (e.g., linux/aarch64 -> aarch64-linux-gnu)
os_arch_to_triple = $(word 2,$(subst /, ,$(1)))-$(word 1,$(subst /, ,$(1)))-gnu
BUILD_TRIPLE := $(call os_arch_to_triple,$(BUILD))
HOST_TRIPLE := $(call os_arch_to_triple,$(HOST))
TARGET_TRIPLE := $(call os_arch_to_triple,$(TARGET))

BUILD_ROOT ?= .
BUILD_ROOT := $(abspath $(BUILD_ROOT))
BUILD_DIR := $(BUILD_ROOT)/build
OUT_DIR := $(BUILD_ROOT)/out
DL_DIR := $(BUILD_ROOT)/dl
SRC_DIR := $(BUILD_ROOT)/src

IS_NATIVE := $(and $(filter $(HOST),$(BUILD)),$(filter $(TARGET),$(BUILD)))

# BB = bootstrap build, B = target build
BB := $(BUILD_DIR)/bootstrap/$(TOOLCHAIN_NAME)
B := $(BUILD_DIR)/$(HOST)/$(TOOLCHAIN_NAME)

# BO = bootstrap out, O = target out
BO := $(OUT_DIR)/bootstrap/$(TOOLCHAIN_NAME)
O := $(OUT_DIR)/$(HOST)/$(TOOLCHAIN_NAME)

# Global path setup based on script logic
NATIVE_PREFIX := $(OUT_DIR)/$(BUILD)/$(TOOLCHAIN_NAME)/toolchain
BOOTSTRAP_PREFIX := $(BO)/toolchain
TARGET_PREFIX := $(O)/toolchain
SYSROOT := $(O)/sysroot

ifeq ($(IS_NATIVE),)
  # Cross build: native prefix only
  export PATH := $(NATIVE_PREFIX)/bin:$(PATH)
else
  export PATH := $(NATIVE_PREFIX)/bin:$(BOOTSTRAP_PREFIX)/bin:$(PATH)
endif

$(DL_DIR) $(SRC_DIR):
	mkdir -p $@

$(BB) $(B):
	mkdir -p $@

$(BB)/binutils $(BB)/gcc:
	mkdir -p $@

$(BO)/toolchain $(O)/toolchain $(O)/sysroot:
	mkdir -p $@

$(BO)/toolchain/sysroot: $(O)/sysroot $(BO)/toolchain
	@if [ ! -L $@ ]; then \
		ln -sfn ../../../$(HOST)/$(TOOLCHAIN_NAME)/sysroot $@; \
	fi

$(B)/linux-headers:
	mkdir -p $@

$(O)/toolchain/sysroot: $(O)/sysroot
	ln -sfn ../sysroot $@

.DEFAULT_GOAL := toolchain

.PHONY: toolchain bootstrap download clean test-parallel bootstrap-binutils bootstrap-gcc linux-headers

toolchain: $(O)/.toolchain.done

bootstrap: $(BO)/.bootstrap.done

$(BO)/.bootstrap.done: $(BO)/.libstdc++.installed | $(BO)
	@echo "Bootstrap toolchain complete"
	@touch $@

$(O)/.toolchain.done: $(O)/.glibc.installed $(O)/.sysroot.done | $(O)
	@echo "Target toolchain complete"
	@touch $@

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
	cd $(BB)/binutils/build
	TMPDIR=$$(mktemp -d)
	$(MAKE) DESTDIR="$$TMPDIR" install
	find "$$TMPDIR" -exec touch -h -d "@$(SOURCE_DATE_EPOCH)" {} \;
	$(MKTOOLCHAIN_ROOT)script/replace-binutils-hardlinks.sh "$$TMPDIR" "$(BUILD_TRIPLE)"
	cp -a "$$TMPDIR"/* $(BO)/toolchain/
	rm -rf "$$TMPDIR"
	touch $@

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
	@echo "foo $(BB)/.gcc.linked"
	@echo "bar $<"
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
	cd $(BB)/gcc/build
	$(MAKE) configure-gcc
	sed -i 's/ --with-build-sysroot=[^ ]*//' gcc/configargs.h
	$(MAKE)
	touch $@

$(BB)/.gcc.installed: | $(BB)/.gcc.compiled
	cd $(BB)/gcc/build
	TMPDIR=$$(mktemp -d)
	$(MAKE) DESTDIR="$$TMPDIR" install
	find "$$TMPDIR" -exec touch -h -d "@$(SOURCE_DATE_EPOCH)" {} \;
	cp -a "$$TMPDIR"/* $(BO)/toolchain/
	rm -rf "$$TMPDIR"
	touch $@

$(BB)/.glibc.installed: $(BB)/.gcc.installed $(BB)/.linux-headers.installed | $(BB)
	@sleep 2  # Simulate build time
	@touch $@

$(BO)/.libstdc++.installed: $(BB)/.glibc.installed | $(BO)
	@sleep 1  # Simulate build time
	@touch $@

$(B)/.binutils.installed: $(BO)/.bootstrap.done | $(B)
	@sleep 1  # Simulate build time
	@touch $@

$(O)/.glibc.installed: $(B)/.gcc.installed | $(O)
	@sleep 2  # Simulate build time
	@touch $@

$(O)/.sysroot.done: $(O)/.glibc.installed $(O)/.linux-headers.installed | $(O)
	@sleep 1  # Simulate sysroot assembly
	@touch $@

linux-headers: $(B)/.linux-headers.installed

$(B)/linux-headers/src: $(B)/.linux-headers.linked
$(B)/linux-headers/build:
	mkdir -p $@

$(B)/.linux-headers.linked: $(SRC_DIR)/linux-$(LINUX_VERSION) | $(B)/linux-headers
	ln -sfn $< $(B)/linux-headers/src
	touch $@

$(B)/.linux-headers.installed: $(B)/.linux-headers.linked | $(B)/linux-headers/build $(SYSROOT)
	$(eval TARGET_ARCH := $(word 1,$(subst -, ,$(TARGET_TRIPLE))))
	$(eval KERNEL_ARCH := $(if $(filter x86_64,$(TARGET_ARCH)),x86_64,$(if $(filter aarch64,$(TARGET_ARCH)),arm64,$(error Unsupported architecture: $(TARGET_ARCH)))))

	$(eval TMPDIR := $(shell mktemp -d))

	cd $(B)/linux-headers/build
	$(MAKE) -f $(B)/linux-headers/src/Makefile \
		ARCH="$(KERNEL_ARCH)" \
		INSTALL_HDR_PATH="$(TMPDIR)/usr" \
		O=$(B)/linux-headers/build \
		headers_install
	find "$(TMPDIR)" -exec touch -h -d "@$(shell cat $(SRC_DIR)/linux-$(LINUX_VERSION)/.timestamp 2>/dev/null || echo 1)" {} \;
	cp -a "$(TMPDIR)"/* $(SYSROOT)/
	rm -rf "$(TMPDIR)"
	touch $@

download: $(SRC_DIR)/gcc-$(GCC_VERSION) $(SRC_DIR)/binutils-$(BINUTILS_VERSION) $(SRC_DIR)/glibc-$(GLIBC_VERSION) $(SRC_DIR)/linux-$(LINUX_VERSION)

GNU_BASE_URL := https://ftp.gnu.org/gnu
GCC_URL := $(GNU_BASE_URL)/gcc/gcc-$(GCC_VERSION)/gcc-$(GCC_VERSION).tar.gz
BINUTILS_URL := $(GNU_BASE_URL)/binutils/binutils-$(BINUTILS_VERSION).tar.gz
GLIBC_URL := $(GNU_BASE_URL)/glibc/glibc-$(GLIBC_VERSION).tar.gz

LINUX_MAJOR := $(shell echo $(LINUX_VERSION) | cut -d. -f1)
LINUX_URL := https://cdn.kernel.org/pub/linux/kernel/v$(LINUX_MAJOR).x/linux-$(LINUX_VERSION).tar.gz

$(SRC_DIR)/gcc-$(GCC_VERSION) $(SRC_DIR)/binutils-$(BINUTILS_VERSION) $(SRC_DIR)/glibc-$(GLIBC_VERSION) $(SRC_DIR)/linux-$(LINUX_VERSION): | $(SRC_DIR) $(DL_DIR)
	$(eval PACKAGE_LC := $(shell echo $(notdir $@) | sed 's/\([^-]*\)-.*/\1/'))
	$(eval PACKAGE := $(shell echo $(PACKAGE_LC) | tr a-z A-Z))
	$(eval URL := $($(PACKAGE)_URL))
	$(eval SHA256 := $($(PACKAGE)_SHA256))
	$(eval TARBALL := $(DL_DIR)/$(notdir $@).tar.gz)
	@if ! [ -f "$(TARBALL)" ] || ! echo "$(SHA256) $(TARBALL)" | sha256sum -c - >/dev/null 2>&1; then \
		[ -f "$(TARBALL)" ] && rm -f "$(TARBALL)"; \
		echo "Downloading $(PACKAGE)..."; \
		curl -L "$(URL)" -o "$(TARBALL)" && \
		printf "Verifying $(PACKAGE) checksum... "; \
		echo "$(SHA256) $(TARBALL)" | sha256sum -c - >/dev/null && echo "verified"; \
	fi
	@echo "Extracting $(TARBALL)..."
	@tar -xf "$(TARBALL)" -C "$(SRC_DIR)"
	@timestamp=$$(tar -tvf "$(TARBALL)" | awk '{print $$4" "$$5}' | sort -r | head -1 | xargs -I {} date -d "{}" +%s 2>/dev/null || echo 1); \
	echo "$$timestamp" > "$@/.timestamp"
	@if [ -d "$(MKTOOLCHAIN_ROOT)patches/$(notdir $@)" ]; then \
		for patch in $(MKTOOLCHAIN_ROOT)patches/$(notdir $@)/*; do \
			[ -f "$$patch" ] && echo "Applying: $$(basename $$patch)" && (cd "$@" && patch -p1 < "$$patch"); \
		done; \
	fi
	@if echo "$(notdir $@)" | grep -q "^gcc-"; then \
		echo "Downloading GCC dependencies..."; \
		(cd "$@" && ./contrib/download_prerequisites); \
	fi

clean:
	rm -rf $(BUILD_DIR) $(OUT_DIR)

clean-bootstrap:
	rm -rf $(BUILD_DIR)/bootstrap $(OUT_DIR)/bootstrap

clean-downloads:
	rm -rf $(DL_DIR)

clean-sources:
	rm -rf $(SRC_DIR)
