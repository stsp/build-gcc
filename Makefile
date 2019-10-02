export PREFIX ?= /usr/local/cross
export TARGET = i586-pc-msdosdjgpp
export BLDSUF = build
TMPDIR = $(BLDSUF)/tmp

all:
	mkdir -p $(TMPDIR)
	destdir=`pwd`/$(TMPDIR) ./build-djgpp.sh gcc-9.2.0

install:
	cp -r $(TMPDIR)/usr $(DESTDIR)

deb:
	debuild -i -us -uc -b
