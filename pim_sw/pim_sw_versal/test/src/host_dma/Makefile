CXX=g++ 
INC=
LIBS=-lpim
CXXFLAGS += ${INC} -std=c++11 -g
TARGET = ../../bin/host_dma
TARGET2= host_dma
OBJS = host_dma.o convert_numeric.o \

# Default target executed when no arguments are given to make.
.DEFAULT_GOAL=all

${TARGET}: ${OBJS}
	g++ ${CXXFLAGS} -o $@ $^ ${LIBS}
${TARGET2}: ${OBJS}
	g++ ${CXXFLAGS} -o $@ $^ ${LIBS}

all: ${TARGET2}
.PHONY: all

test: ${TARGET}
.PHONY: test

clean:
	rm -f *.o *.d ${TARGET2}
	rm -f *.o *.d ${TARGET}