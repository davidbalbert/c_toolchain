CONFIG ?= config.mk

PROJECT_ROOT := $(patsubst %/,%,$(dir $(abspath $(lastword $(MAKEFILE_LIST)))))

export LC_ALL := C.UTF-8

ifeq ($(filter -j%,$(MAKEFLAGS)),)
  MAKEFLAGS += -j$(shell nproc)
endif

include $(CONFIG)

BUILD := $(shell uname -s | tr A-Z a-z)/$(shell uname -m)
HOST ?= $(BUILD)
TARGET ?= $(HOST)

ORIG_PATH := $(PATH)

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

# Extract architecture from os/arch format
BUILD_ARCH := $(word 2,$(subst /, ,$(BUILD)))
HOST_ARCH := $(word 2,$(subst /, ,$(HOST)))
TARGET_ARCH := $(word 2,$(subst /, ,$(TARGET)))

# Computed toolchain names following $(TARGET_TRIPLE)-$(TOOLCHAIN_NAME) pattern
BUILD_TOOLCHAIN_NAME := $(BUILD_TRIPLE)-$(TOOLCHAIN_NAME)
HOST_TOOLCHAIN_NAME := $(HOST_TRIPLE)-$(TOOLCHAIN_NAME)
TARGET_TOOLCHAIN_NAME := $(TARGET_TRIPLE)-$(TOOLCHAIN_NAME)

# Computed build directories
BOOTSTRAP_BUILD_DIR := $(BUILD_DIR)/bootstrap/$(BUILD_ARCH)/$(BUILD_TOOLCHAIN_NAME)
BUILD_BUILD_DIR := $(BUILD_DIR)/linux/$(BUILD_ARCH)/$(BUILD_TOOLCHAIN_NAME)
HOST_BUILD_DIR := $(BUILD_DIR)/linux/$(BUILD_ARCH)/$(HOST_TOOLCHAIN_NAME)
TARGET_BUILD_DIR := $(BUILD_DIR)/linux/$(HOST_ARCH)/$(TARGET_TOOLCHAIN_NAME)

# Computed output directories
BOOTSTRAP_OUT_DIR := $(OUT_DIR)/bootstrap/$(BUILD_ARCH)/$(BUILD_TOOLCHAIN_NAME)
BUILD_OUT_DIR := $(OUT_DIR)/linux/$(BUILD_ARCH)/$(BUILD_TOOLCHAIN_NAME)
HOST_OUT_DIR := $(OUT_DIR)/linux/$(BUILD_ARCH)/$(HOST_TOOLCHAIN_NAME)
TARGET_OUT_DIR := $(OUT_DIR)/linux/$(HOST_ARCH)/$(TARGET_TOOLCHAIN_NAME)

# Computed prefixes
BOOTSTRAP_PREFIX := $(BOOTSTRAP_OUT_DIR)/toolchain
BUILD_PREFIX := $(BUILD_OUT_DIR)/toolchain
HOST_PREFIX := $(HOST_OUT_DIR)/toolchain
TARGET_PREFIX := $(TARGET_OUT_DIR)/toolchain

# Computed sysroots
BOOTSTRAP_SYSROOT := $(BOOTSTRAP_OUT_DIR)/sysroot
BUILD_SYSROOT := $(BUILD_OUT_DIR)/sysroot
HOST_SYSROOT := $(HOST_OUT_DIR)/sysroot
TARGET_SYSROOT := $(TARGET_OUT_DIR)/sysroot

# Determine final toolchain directory based on build scenario
ifeq ($(BUILD)_$(HOST)_$(TARGET),$(BUILD)_$(BUILD)_$(BUILD))
  # Case 1: BUILD = HOST = TARGET (Native build)
  FINAL_TOOLCHAIN := $(BUILD_OUT_DIR)
else ifeq ($(BUILD)_$(HOST),$(BUILD)_$(BUILD))
  # Case 2: BUILD = HOST ≠ TARGET (Cross-compiler for build system)
  FINAL_TOOLCHAIN := $(TARGET_OUT_DIR)
else
  # Case 3: BUILD ≠ HOST (Cross-compilation to different host)
  FINAL_TOOLCHAIN := $(TARGET_OUT_DIR)
endif

# Legacy variables for compatibility during transition (will be removed)
BB := $(BOOTSTRAP_BUILD_DIR)
B := $(TARGET_BUILD_DIR)
BO := $(BOOTSTRAP_OUT_DIR)
O := $(TARGET_OUT_DIR)
NATIVE_PREFIX := $(BUILD_PREFIX)
SYSROOT := $(TARGET_SYSROOT)

include $(PROJECT_ROOT)/mk/*.mk

# Conditional dependency chains based on build scenario
# User-facing phony targets (convenience aliases)
gcc: $(FINAL_TOOLCHAIN)/.gcc.installed
binutils: $(FINAL_TOOLCHAIN)/.binutils.installed
glibc: $(FINAL_TOOLCHAIN)/.glibc.installed

bootstrap-gcc: $(BOOTSTRAP_OUT_DIR)/.gcc.installed
bootstrap-binutils: $(BOOTSTRAP_OUT_DIR)/.binutils.installed
bootstrap-glibc: $(BOOTSTRAP_OUT_DIR)/.glibc.installed
bootstrap-libstdc++: $(BOOTSTRAP_OUT_DIR)/.libstdc++.installed
linux-headers: $(BOOTSTRAP_OUT_DIR)/.linux-headers.installed

# Phase dependency chains
# Case 1: Native build (BUILD = HOST = TARGET)
ifeq ($(BUILD)_$(HOST)_$(TARGET),$(BUILD)_$(BUILD)_$(BUILD))
  $(BUILD_OUT_DIR)/.gcc.installed: $(BOOTSTRAP_OUT_DIR)/.libstdc++.installed
  $(BUILD_OUT_DIR)/.binutils.installed: $(BOOTSTRAP_OUT_DIR)/.libstdc++.installed
  $(BUILD_OUT_DIR)/.glibc.installed: $(BOOTSTRAP_OUT_DIR)/.libstdc++.installed
# Case 2: Cross-compiler for build system (BUILD = HOST ≠ TARGET)
else ifeq ($(BUILD)_$(HOST),$(BUILD)_$(BUILD))
  $(TARGET_OUT_DIR)/.gcc.installed: $(BUILD_OUT_DIR)/.gcc.installed
  $(TARGET_OUT_DIR)/.binutils.installed: $(BUILD_OUT_DIR)/.gcc.installed
  $(TARGET_OUT_DIR)/.glibc.installed: $(BUILD_OUT_DIR)/.gcc.installed
  $(BUILD_OUT_DIR)/.gcc.installed: $(BOOTSTRAP_OUT_DIR)/.libstdc++.installed
  $(BUILD_OUT_DIR)/.binutils.installed: $(BOOTSTRAP_OUT_DIR)/.libstdc++.installed
  $(BUILD_OUT_DIR)/.glibc.installed: $(BOOTSTRAP_OUT_DIR)/.libstdc++.installed
# Case 3: Cross-compilation to different host (BUILD ≠ HOST)
else
  $(TARGET_OUT_DIR)/.gcc.installed: $(HOST_OUT_DIR)/.gcc.installed
  $(TARGET_OUT_DIR)/.binutils.installed: $(HOST_OUT_DIR)/.gcc.installed
  $(TARGET_OUT_DIR)/.glibc.installed: $(HOST_OUT_DIR)/.gcc.installed
  $(HOST_OUT_DIR)/.gcc.installed: $(BUILD_OUT_DIR)/.gcc.installed
  $(HOST_OUT_DIR)/.binutils.installed: $(BUILD_OUT_DIR)/.gcc.installed
  $(HOST_OUT_DIR)/.glibc.installed: $(BUILD_OUT_DIR)/.gcc.installed
  $(BUILD_OUT_DIR)/.gcc.installed: $(BOOTSTRAP_OUT_DIR)/.libstdc++.installed
  $(BUILD_OUT_DIR)/.binutils.installed: $(BOOTSTRAP_OUT_DIR)/.libstdc++.installed
  $(BUILD_OUT_DIR)/.glibc.installed: $(BOOTSTRAP_OUT_DIR)/.libstdc++.installed
endif

.PHONY: download clean test-parallel bootstrap-binutils bootstrap-gcc bootstrap-glibc bootstrap-libstdc++ linux-headers binutils gcc glibc

clean:
	rm -rf $(BUILD_DIR) $(OUT_DIR)

clean-bootstrap:
	rm -rf $(BUILD_DIR)/bootstrap $(OUT_DIR)/bootstrap

clean-downloads:
	rm -rf $(DL_DIR)

clean-sources:
	rm -rf $(SRC_DIR)
