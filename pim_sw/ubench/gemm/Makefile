CXX=g++ 
INC=
LIBS=-lpim
CXXFLAGS += ${INC} -std=c++11
TARGET2 = gemm
OBJS = main.o util.o matmul_cpu.o matmul_pim.o 

OBJECTS = $(patsubst %.cpp,%.o, $(wildcard ${PWD}/*.cpp))

# Default target executed when no arguments are given to make.
.DEFAULT_GOAL=all

${TARGET2}: ${OBJS}
	${CXX} ${CXXFLAGS} -o $@ $^ ${LIBS}

all: ${TARGET2}
.PHONY: all

test: ${TARGET}
.PHONY: test

clean:
	rm -f *.o *.d ${TARGET2}
