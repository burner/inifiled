all: *.d Makefile
	dmd *.d -ofinitest -Isource -unittest -g -w
