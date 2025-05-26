ARCH ?= $(shell uname -m)
BUILDDIR ?= .
DESTDIR ?= /usr/local/bin
SRCDIR ?= .

CC := gcc
CFLAGS = -Os -g -ffreestanding -fno-stack-protector -fno-builtin -Wall -Wextra -Werror -nostdinc -isystem $(shell $(CC) -print-file-name=include) -MMD -MP
ASFLAGS = -MMD -MP
LDFLAGS = -static -nostdlib -nodefaultlibs

DEPS := $(wildcard $(BUILDDIR)/*.d)
-include $(DEPS)

$(BUILDDIR)/ld_linux_shim: $(BUILDDIR)/start_$(ARCH).o $(BUILDDIR)/ld_linux_shim.o

$(BUILDDIR)/ld_linux_shim.o: $(SRCDIR)/ld_linux_shim.c
$(BUILDDIR)/start_$(ARCH).o: $(SRCDIR)/start_$(ARCH).S

install: $(BUILDDIR)/ld_linux_shim
	cp $< $(DESTDIR)/

clean:
	rm -rf $(BUILDDIR)/*.o $(BUILDDIR)/*.d $(BUILDDIR)/ld_linux_shim

.PHONY: clean install
