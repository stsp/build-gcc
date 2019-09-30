export PREFIX ?= /usr/local/cross
export TARGET = i586-pc-msdosdjgpp
export BLDSUF = build

all:
	./build-djgpp.sh gcc-9.2.0
