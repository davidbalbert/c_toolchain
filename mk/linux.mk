%/.linux-headers.installed: PATH := $(ORIG_PATH)

$(BOOTSTRAP_BUILD_DIR)/.linux-headers.installed: BUILD_DIR := $(BOOTSTRAP_BUILD_DIR)
$(HOST_BUILD_DIR)/.linux-headers.installed: BUILD_DIR := $(HOST_BUILD_DIR)
$(TARGET_BUILD_DIR)/.linux-headers.installed: BUILD_DIR := $(TARGET_BUILD_DIR)

# override sysroot for bootstrap
$(BOOTSTRAP_BUILD_DIR)/.linux-headers.installed: SYSROOT := $(BUILD_SYSROOT)

%/.linux-headers.installed: TARGET_ARCH = $(word 1,$(subst -, ,$(TARGET_TRIPLE)))
%/.linux-headers.installed: KERNEL_ARCH = $(if $(filter x86_64,$(TARGET_ARCH)),x86_64,$(if $(filter aarch64,$(TARGET_ARCH)),arm64,$(error Unsupported architecture: $(TARGET_ARCH))))
%/.linux-headers.installed: SYSROOT = $(patsubst $(BUILD_DIR)/%,$(OUT_DIR)/%/sysroot,$(BUILD_DIR))

%/.linux-headers.installed: $(SRC_DIR)/linux-$(LINUX_VERSION)
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
