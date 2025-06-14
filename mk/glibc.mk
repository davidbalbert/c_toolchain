$(BB)/.glibc.installed: $(BB)/.gcc.installed $(BB)/.linux-headers.installed | $(BB)
	@sleep 1
	@touch $@

$(BO)/.libstdc++.installed: $(BB)/.glibc.installed | $(BO)
	@sleep 1
	@touch $@

$(O)/.glibc.installed: $(B)/.gcc.installed | $(O)
	@sleep 1
	@touch $@
