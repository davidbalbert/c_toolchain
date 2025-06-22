$(BUILD_ROOT)/build/%/.linux-headers.installed: PATH := $(ORIG_PATH)

$(BUILD_ROOT)/build/%/.linux-headers.installed: BUILD_DIR = $(abspath $(BUILD_ROOT)/build/$*)
$(BUILD_ROOT)/build/%/.linux-headers.installed: TARGET_ARCH = $(word 1,$(subst -, ,$(TARGET_TRIPLE)))
$(BUILD_ROOT)/build/%/.linux-headers.installed: KERNEL_ARCH = $(if $(filter x86_64,$(TARGET_ARCH)),x86_64,$(if $(filter aarch64,$(TARGET_ARCH)),arm64,$(error Unsupported architecture: $(TARGET_ARCH))))
$(BUILD_ROOT)/build/%/.linux-headers.installed: SYSROOT = $(OUT_DIR)/$*/sysroot

.PRECIOUS: build/%/.linux-headers.installed

$(BUILD_ROOT)/build/%/.linux-headers.installed: $(SRC_DIR)/linux-$(LINUX_VERSION)
	$(eval TMPDIR := $(shell mktemp -d))

	mkdir -p $(BUILD_DIR)/linux-headers/build $(SYSROOT)
	ln -sfn $(SRC_DIR)/linux-$(LINUX_VERSION) $(BUILD_DIR)/linux-headers/src
	$(MAKE) -f $(BUILD_DIR)/linux-headers/src/Makefile \
		ARCH="$(KERNEL_ARCH)" \
		INSTALL_HDR_PATH="$(TMPDIR)/usr" \
		O=$(BUILD_DIR)/linux-headers/build \
		headers_install
	find "$(TMPDIR)" -exec touch -h -d "@$(shell cat $(SRC_DIR)/linux-$(LINUX_VERSION)/.timestamp 2>/dev/null || echo 1)" {} \;
	cp -a "$(TMPDIR)"/* $(SYSROOT)/
	rm -rf "$(TMPDIR)"
	touch $@
