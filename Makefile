all: *.d Makefile
	dmd *.d -ofinitest -unittest -debug -gc
