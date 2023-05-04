CXX=g++ 
INC=
LIBS=-lpim_mem
CXXFLAGS += ${INC} -std=c++11 -g
TARGET = gemm
OBJS = gemm.o convert_numeric.o

OBJECTS = $(patsubst %.cpp,%.o, $(wildcard ${PWD}/*.cpp))

${TARGET}: ${OBJS}
	${CXX} ${CXXFLAGS} -o $@ $^ ${LIBS}

clean:
	rm -f *.o *.d ${TARGET}
