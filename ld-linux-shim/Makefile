ARCH ?= $(shell uname -m)
BUILDDIR ?= .
DESTDIR ?= /usr/local/libexec
SRCDIR = $(dir $(abspath $(lastword $(MAKEFILE_LIST))))

CC := $(ARCH)-linux-gnu-gcc
AS := $(ARCH)-linux-gnu-as
LD := $(ARCH)-linux-gnu-ld

CFLAGS = -Os -g -ffreestanding -fno-stack-protector -fno-builtin -MMD -MP -Wall -Wextra -Werror -nostdinc -isystem $(shell $(CC) -print-file-name=include)
ASFLAGS = -MMD -MP
LDFLAGS = -static -nostdlib -nodefaultlibs

# Separate source directory from build directory
vpath %.c $(SRCDIR)
vpath %.S $(SRCDIR)

$(BUILDDIR)/ld-linux-shim: $(BUILDDIR)/start_$(ARCH).o $(BUILDDIR)/ld-linux-shim.o

DEPS := $(wildcard $(BUILDDIR)/*.d)
-include $(DEPS)

install: $(BUILDDIR)/ld-linux-shim
	cp $< $(DESTDIR)/

clean:
	rm -rf $(BUILDDIR)/*.o $(BUILDDIR)/*.d $(BUILDDIR)/ld-linux-shim

.PHONY: clean install
