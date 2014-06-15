all: *.d Makefile
	dmd *.d -ofinitest -Isource -unittest -gc -w
