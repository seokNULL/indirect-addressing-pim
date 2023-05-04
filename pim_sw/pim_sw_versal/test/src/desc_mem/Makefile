CC=gcc
INC=
LIBS=-lpim_mem
CFLAGS = -g -O2
TARGET = ../../bin/pim_mem
TARGET2 = pim_mem
OBJS=main.o

OBJECTS = $(patsubst %.c,%.o, $(wildcard ${PWD}/*.c))

# Default target executed when no arguments are given to make.
.DEFAULT_GOAL=all

${TARGET}: ${OBJS}
	${CC} ${CFLAGS} -o $@ $^ ${LIBS}
${TARGET2}: ${OBJS}
	${CC} ${CFLAGS} -o $@ $^ ${LIBS}

all: ${TARGET2}
.PHONY: all

test: ${TARGET}
.PHONY: test

clean:
	rm -f *.o *.d ${TARGET2}
	rm -f *.o *.d ${TARGET}
