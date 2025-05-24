ARCH ?= $(shell uname -m)
BUILDDIR ?= .
DESTDIR ?= /usr/local/bin

CFLAGS = -Os -fno-stack-protector -fno-builtin -Wall -Wextra -Werror
ASFLAGS =
LDFLAGS = -nostdlib -static

$(BUILDDIR)/ld_linux_shim: $(BUILDDIR)/start_$(ARCH).o $(BUILDDIR)/ld_linux_shim.o

install: $(BUILDDIR)/ld_linux_shim
	cp $< $(DESTDIR)/

clean:
	rm -rf $(BUILDDIR)/*.o $(BUILDDIR)/ld_linux_shim

.PHONY: clean install
