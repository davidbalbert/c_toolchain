CONFIG ?= config.mk

include $(CONFIG)

BUILD := $(shell uname -s | tr A-Z a-z)/$(shell uname -m)
HOST ?= $(BUILD)
TARGET ?= $(HOST)

BUILD_ROOT ?= .
BUILD_DIR := $(BUILD_ROOT)/build
OUT_DIR := $(BUILD_ROOT)/out
DL_DIR := $(BUILD_ROOT)/dl
SRC_DIR := $(BUILD_ROOT)/src

IS_NATIVE := $(and $(filter $(HOST),$(BUILD)),$(filter $(TARGET),$(BUILD)))

BOOTSTRAP_BUILD_DIR := $(BUILD_DIR)/bootstrap
TARGET_BUILD_DIR := $(BUILD_DIR)/$(HOST)/$(TARGET)

BOOTSTRAP_OUT := $(OUT_DIR)/bootstrap/$(TOOLCHAIN_NAME)
TARGET_OUT := $(OUT_DIR)/$(HOST)/$(TOOLCHAIN_NAME)

$(BUILD_DIR) $(OUT_DIR) $(DL_DIR) $(SRC_DIR):
	mkdir -p $@

$(BOOTSTRAP_BUILD_DIR) $(TARGET_BUILD_DIR):
	mkdir -p $@

$(BOOTSTRAP_OUT) $(TARGET_OUT):
	mkdir -p $@

.DEFAULT_GOAL := toolchain

.PHONY: toolchain bootstrap download clean test-parallel

toolchain: $(TARGET_OUT)/.toolchain.done

bootstrap: $(BOOTSTRAP_OUT)/.bootstrap.done

# Test target for parallel builds
test-parallel: $(DL_DIR) $(SRC_DIR) $(BUILD_DIR) $(OUT_DIR)
	@echo "Testing parallel infrastructure..."
	@echo "Build system: $(BUILD)"
	@echo "Host: $(HOST)"
	@echo "Target: $(TARGET)"
	@echo "Is native: $(IS_NATIVE)"
	@echo "Bootstrap build dir: $(BOOTSTRAP_BUILD_DIR)"
	@echo "Target build dir: $(TARGET_BUILD_DIR)"
	@echo "Config: $(CONFIG)"
	@echo "GCC Version: $(GCC_VERSION)"

$(BOOTSTRAP_OUT)/.bootstrap.done: $(BOOTSTRAP_OUT)/.libstdc++.installed | $(BOOTSTRAP_OUT)
	@echo "Bootstrap toolchain complete"
	@touch $@

$(TARGET_OUT)/.toolchain.done: $(TARGET_OUT)/.glibc.installed $(TARGET_OUT)/.sysroot.done | $(TARGET_OUT)
	@echo "Target toolchain complete"
	@touch $@

$(BOOTSTRAP_BUILD_DIR)/.binutils.installed: | $(BOOTSTRAP_BUILD_DIR)
	@echo "Building bootstrap binutils..."
	@sleep 1  # Simulate build time
	@touch $@

$(BOOTSTRAP_BUILD_DIR)/.gcc.installed: $(BOOTSTRAP_BUILD_DIR)/.binutils.installed | $(BOOTSTRAP_BUILD_DIR)
	@echo "Building bootstrap GCC..."
	@sleep 2  # Simulate build time
	@touch $@

$(BOOTSTRAP_BUILD_DIR)/.linux-headers.installed: | $(BOOTSTRAP_BUILD_DIR)
	@echo "Installing Linux headers..."
	@sleep 1  # Simulate build time
	@touch $@

$(BOOTSTRAP_BUILD_DIR)/.glibc.installed: $(BOOTSTRAP_BUILD_DIR)/.gcc.installed $(BOOTSTRAP_BUILD_DIR)/.linux-headers.installed | $(BOOTSTRAP_BUILD_DIR)
	@echo "Building bootstrap glibc..."
	@sleep 2  # Simulate build time
	@touch $@

$(BOOTSTRAP_OUT)/.libstdc++.installed: $(BOOTSTRAP_BUILD_DIR)/.glibc.installed | $(BOOTSTRAP_OUT)
	@echo "Building bootstrap libstdc++..."
	@sleep 1  # Simulate build time
	@touch $@

$(TARGET_BUILD_DIR)/.binutils.installed: $(BOOTSTRAP_OUT)/.bootstrap.done | $(TARGET_BUILD_DIR)
	@echo "Building target binutils..."
	@sleep 1  # Simulate build time
	@touch $@

$(TARGET_BUILD_DIR)/.gcc.installed: $(TARGET_BUILD_DIR)/.binutils.installed $(BOOTSTRAP_OUT)/.bootstrap.done | $(TARGET_BUILD_DIR)
	@echo "Building target GCC..."
	@sleep 2  # Simulate build time
	@touch $@

$(TARGET_OUT)/.glibc.installed: $(TARGET_BUILD_DIR)/.gcc.installed | $(TARGET_OUT)
	@echo "Building target glibc..."
	@sleep 2  # Simulate build time
	@touch $@

$(TARGET_OUT)/.sysroot.done: $(TARGET_OUT)/.glibc.installed $(TARGET_BUILD_DIR)/.linux-headers.installed | $(TARGET_OUT)
	@echo "Assembling sysroot..."
	@sleep 1  # Simulate sysroot assembly
	@touch $@

$(TARGET_BUILD_DIR)/.linux-headers.installed: | $(TARGET_BUILD_DIR)
	@echo "Installing Linux headers for target..."
	@sleep 1  # Simulate build time
	@touch $@

# Download system
download: $(DL_DIR)/gcc-$(GCC_VERSION).tar.gz $(DL_DIR)/binutils-$(BINUTILS_VERSION).tar.gz $(DL_DIR)/glibc-$(GLIBC_VERSION).tar.gz $(DL_DIR)/linux-$(LINUX_VERSION).tar.gz

# Base URLs
GNU_BASE_URL := https://ftp.gnu.org/gnu

# Package URLs
GCC_URL := $(GNU_BASE_URL)/gcc/gcc-$(GCC_VERSION)/gcc-$(GCC_VERSION).tar.gz
BINUTILS_URL := $(GNU_BASE_URL)/binutils/binutils-$(BINUTILS_VERSION).tar.gz
GLIBC_URL := $(GNU_BASE_URL)/glibc/glibc-$(GLIBC_VERSION).tar.gz
LINUX_MAJOR := $(shell echo $(LINUX_VERSION) | cut -d. -f1)
LINUX_URL := https://cdn.kernel.org/pub/linux/kernel/v$(LINUX_MAJOR).x/linux-$(LINUX_VERSION).tar.gz

# Download and verify specific packages
$(DL_DIR)/gcc-$(GCC_VERSION).tar.gz: | $(DL_DIR)
	@echo "Downloading GCC $(GCC_VERSION)..."
	@if [ -f "$@" ] && echo "$(GCC_SHA256) $@" | sha256sum -c - >/dev/null 2>&1; then \
		echo "GCC tarball already exists and verified"; \
	else \
		echo "Downloading $(GCC_URL)..."; \
		curl -L "$(GCC_URL)" -o "$@.tmp" && \
		echo "Verifying GCC checksum..."; \
		echo "$(GCC_SHA256) $@.tmp" | sha256sum -c - && \
		mv "$@.tmp" "$@"; \
	fi

$(DL_DIR)/binutils-$(BINUTILS_VERSION).tar.gz: | $(DL_DIR)
	@echo "Downloading binutils $(BINUTILS_VERSION)..."
	@if [ -f "$@" ] && echo "$(BINUTILS_SHA256) $@" | sha256sum -c - >/dev/null 2>&1; then \
		echo "Binutils tarball already exists and verified"; \
	else \
		echo "Downloading $(BINUTILS_URL)..."; \
		curl -L "$(BINUTILS_URL)" -o "$@.tmp" && \
		echo "Verifying binutils checksum..."; \
		echo "$(BINUTILS_SHA256) $@.tmp" | sha256sum -c - && \
		mv "$@.tmp" "$@"; \
	fi

$(DL_DIR)/glibc-$(GLIBC_VERSION).tar.gz: | $(DL_DIR)
	@echo "Downloading glibc $(GLIBC_VERSION)..."
	@if [ -f "$@" ] && echo "$(GLIBC_SHA256) $@" | sha256sum -c - >/dev/null 2>&1; then \
		echo "Glibc tarball already exists and verified"; \
	else \
		echo "Downloading $(GLIBC_URL)..."; \
		curl -L "$(GLIBC_URL)" -o "$@.tmp" && \
		echo "Verifying glibc checksum..."; \
		echo "$(GLIBC_SHA256) $@.tmp" | sha256sum -c - && \
		mv "$@.tmp" "$@"; \
	fi

$(DL_DIR)/linux-$(LINUX_VERSION).tar.gz: | $(DL_DIR)
	@echo "Downloading Linux $(LINUX_VERSION)..."
	@if [ -f "$@" ] && echo "$(LINUX_SHA256) $@" | sha256sum -c - >/dev/null 2>&1; then \
		echo "Linux tarball already exists and verified"; \
	else \
		echo "Downloading $(LINUX_URL)..."; \
		curl -L "$(LINUX_URL)" -o "$@.tmp" && \
		echo "Verifying Linux checksum..."; \
		echo "$(LINUX_SHA256) $@.tmp" | sha256sum -c - && \
		mv "$@.tmp" "$@"; \
	fi

clean:
	rm -rf $(BUILD_DIR) $(OUT_DIR)

clean-bootstrap:
	rm -rf $(BUILD_DIR)/bootstrap $(OUT_DIR)/bootstrap

clean-downloads:
	rm -rf $(DL_DIR)

clean-sources:
	rm -rf $(SRC_DIR)
