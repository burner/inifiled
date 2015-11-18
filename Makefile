all: *.d Makefile
	dmd *.d source/inifiled.d -ofinitest -Isource -unittest -g -w -cov
