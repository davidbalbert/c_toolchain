linux-headers: $(B)/.linux-headers.installed
linux-headers: PATH := $(ORIG_PATH)

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
