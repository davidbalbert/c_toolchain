bootstrap-libstdc++: $(BB)/.libstdc++.installed
bootstrap-libstdc++: PATH := $(BOOTSTRAP_PREFIX)/bin:$(ORIG_PATH)
bootstrap-libstdc++: CFLAGS := -g0 -O2 -ffile-prefix-map=$(SRC_DIR)=. -ffile-prefix-map=$(BB)=.
bootstrap-libstdc++: CXXFLAGS := -g0 -O2 -ffile-prefix-map=$(SRC_DIR)=. -ffile-prefix-map=$(BB)=.
bootstrap-libstdc++: SOURCE_DATE_EPOCH := $(shell cat $(SRC_DIR)/gcc-$(GCC_VERSION)/.timestamp 2>/dev/null || echo 1)

LIBSTDCXX_CONFIG := \
	--prefix=/usr \
	--host=$(TARGET_TRIPLE) \
	--disable-multilib \
	--disable-nls \
	--disable-libstdcxx-pch \
	--with-gxx-include-dir=/usr/include/c++/$(GCC_VERSION)

$(BB)/libstdc++/src: $(BB)/.libstdc++.linked
$(BB)/libstdc++/build:
	mkdir -p $@

$(BB)/.libstdc++.linked: $(SRC_DIR)/gcc-$(GCC_VERSION) | $(BB)/libstdc++
	ln -sfn $</libstdc++-v3 $(BB)/libstdc++/src
	touch $@

$(BB)/.libstdc++.configured: | bootstrap-gcc bootstrap-glibc $(BB)/libstdc++/src $(BB)/libstdc++/build
	cd $(BB)/libstdc++/build && \
		CFLAGS="$(CFLAGS)" \
		CXXFLAGS="$(CXXFLAGS)" \
		SOURCE_DATE_EPOCH=$(SOURCE_DATE_EPOCH) \
		../src/configure $(LIBSTDCXX_CONFIG)
	touch $@

$(BB)/.libstdc++.compiled: | $(BB)/.libstdc++.configured
	cd $(BB)/libstdc++/build && $(MAKE)
	touch $@

$(BB)/.libstdc++.installed: | $(BB)/.libstdc++.compiled
	cd $(BB)/libstdc++/build && \
		TMPDIR=$$(mktemp -d) && \
		$(MAKE) DESTDIR="$$TMPDIR" install && \
		find "$$TMPDIR" -exec touch -h -d "@$(SOURCE_DATE_EPOCH)" {} \; && \
		cp -a "$$TMPDIR"/* $(SYSROOT)/ && \
		rm -rf "$$TMPDIR"
	touch $@

$(BB)/libstdc++:
	mkdir -p $@
