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

IS_NATIVE := $(and $(filter $(HOST),$(BUILD)),$(filter $(TARGET),$(BUILD)))

# BB = bootstrap build, B = target build
BB := $(BUILD_DIR)/bootstrap/$(TOOLCHAIN_NAME)
B := $(BUILD_DIR)/$(HOST)/$(TOOLCHAIN_NAME)

# BO = bootstrap out, O = target out
BO := $(OUT_DIR)/bootstrap/$(TOOLCHAIN_NAME)
O := $(OUT_DIR)/$(HOST)/$(TOOLCHAIN_NAME)

NATIVE_PREFIX := $(OUT_DIR)/$(BUILD)/$(TOOLCHAIN_NAME)/toolchain
BOOTSTRAP_PREFIX := $(BO)/toolchain
TARGET_PREFIX := $(O)/toolchain
SYSROOT := $(O)/sysroot

include $(PROJECT_ROOT)/mk/*.mk

$(DL_DIR) $(SRC_DIR):
	mkdir -p $@

$(BB) $(B):
	mkdir -p $@

$(BB)/binutils $(BB)/gcc $(B)/binutils $(B)/gcc:
	mkdir -p $@

$(BO)/toolchain $(O)/toolchain $(O)/sysroot:
	mkdir -p $@

$(BO)/toolchain/sysroot: $(O)/sysroot $(BO)/toolchain
	@if [ ! -L $@ ]; then \
		ln -sfn ../../../$(HOST)/$(TOOLCHAIN_NAME)/sysroot $@; \
	fi

$(BB)/linux-headers $(B)/linux-headers:
	mkdir -p $@

$(BB)/glibc $(B)/glibc:
	mkdir -p $@

$(O)/toolchain/sysroot: $(O)/sysroot $(O)/toolchain
	ln -sfn ../sysroot $@

.DEFAULT_GOAL := toolchain

.PHONY: toolchain bootstrap download clean test-parallel bootstrap-binutils bootstrap-gcc bootstrap-glibc bootstrap-libstdc++ linux-headers binutils gcc glibc

toolchain: $(O)/.toolchain.done

bootstrap: $(BO)/.bootstrap.done

$(BO)/.bootstrap.done: $(BO)/.libstdc++.installed | $(BO)
	@echo "Bootstrap toolchain complete"
	@touch $@

$(O)/.toolchain.done: $(B)/.gcc.done $(O)/.sysroot.done | $(O)
	@echo "Target toolchain complete"
	@touch $@

$(O)/.sysroot.done: $(B)/.glibc.installed $(B)/.linux-headers.installed | $(O)
	@sleep 1  # Simulate sysroot assembly
	@touch $@

clean:
	rm -rf $(BUILD_DIR) $(OUT_DIR)

clean-bootstrap:
	rm -rf $(BUILD_DIR)/bootstrap $(OUT_DIR)/bootstrap

clean-downloads:
	rm -rf $(DL_DIR)

clean-sources:
	rm -rf $(SRC_DIR)
