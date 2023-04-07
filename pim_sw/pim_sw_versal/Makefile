SHELL := /bin/bash # Use bash syntax

ARCH_NAME := $(shell uname -p)
ifeq ($(ARCH_NAME),x86_64)
	ARCH=X86
	ECHO=@echo
else #ifneq ($(filter aarch%,$(ARCH_NAME)),)
	ARCH=ARM
	ECHO=@echo -e
endif


DMA_DIR=${PWD}/src/drv_src
MEM_DIR=${PWD}/src/mem_src
MATH_DIR=${PWD}/src/pim_math_src

CC = gcc
#CC = aarch64-linux-gnu-gcc
CFLAGS = -fPIC -Wall -Wextra -O2 -g
LDFLAGS = -shared -O2 -g
 
ARM_CC=aarch64-linux-gnu-gcc
ARM_CFLAGS=${CFLAGS} -march=armv8-a -mtune=generic -Wno-unused-parameter -Wno-type-limits
ARM_LDFLAGS=${LDFLAGS} -march=armv8-a -mtune=generic -Wno-unused-parameter -Wno-type-limits

LIB_NAME = libpim.so

TARGET_LIB = ./lib/${LIB_NAME}  # target lib
TARGET_INC = ./include/pim.h

MEM_SRCS=$(wildcard ${MEM_DIR}/*.c)
MEM_OBJS=$(patsubst ${MEM_DIR}/%.c,${MEM_DIR}/%.o, $(wildcard ${MEM_DIR}/*.c))

MATH_SRCS=$(wildcard ${MATH_DIR}/*.c)
MATH_OBJS=$(patsubst ${MATH_DIR}/%.c,${MATH_DIR}/%.o, $(wildcard ${MATH_DIR}/*.c))

INSTALL_LIB = /usr/lib
INSTALL_INC = /usr/include

KDIR = /lib/modules/$(shell uname -r)/build

CMD = -I/usr/include
# INSMOD = $(shell ./insmod.sh)
# Default target executed when no arguments are given to make.
.DEFAULT_GOAL=all

all: ${MATH_OBJS} ${MEM_OBJS}
	${ECHO} "\033[33m Build PIM MemPool & Driver - Architecture:\033[31m ${ARCH} \033[0m"
	${CC} ${LDFLAGS} -o ./lib/${LIB_NAME} $^
	${ECHO} "\033[33m Completed PIM memory & math library to \033[31m${TARGET_LIB} \033[0m"
	${ECHO} "\033[33m \n Build PIM DMA Driver - Architecture:\033[31m ${ARCH} \033[0m"
	make ARCH=arm64 -C ${KDIR} CFLAGS_MODULE="${CMD}" M=${DMA_DIR} modules CFLAGS=-v
	${ECHO} "\033[33m Completed build PIM DMA driver \033[0m"
.PHONY: all

drv:
	${ECHO} "\033[33m Build PIM Driver - Architecture:\033[31m ${ARCH} \033[0m"
	make ARCH=arm64 -C ${KDIR} CFLAGS_MODULE="${CMD}" M=${DMA_DIR} modules CFLAGS=-v
.PHONY: drv

mem:
	${ECHO} "\033[33m Build only PIM MemPool - Architecture:\033[31m ${ARCH} \033[0m"
	${CC} ${CFLAGS} -c -o ${MEM_DIR}/pim_mem.o ${MEM_DIR}/pim_mem.c
	${CC} ${CFLAGS} -c -o ${MEM_DIR}/drv_interface.o ${MEM_DIR}/drv_interface.c
	${CC} ${LDFLAGS} -o ./lib/${LIB_NAME} ${MEM_OBJS}
	${ECHO} "\033[33m Completed PIM MemPool library to \033[31m${TARGET_LIB} \033[0m"	
.PHONY: mem_x86

mem_arm:
	${ECHO} "\033[33m Build only PIM MemPool - Architecture:\033[31m ARM (Cross compile) \033[0m"
	${ARM_CC} ${ARM_CFLAGS} -c -o ${MEM_DIR}/pim_mem.o ${MEM_DIR}/pim_mem.c
	${ARM_CC} ${ARM_CFLAGS} -c -o ${MEM_DIR}/drv_interface.o ${MEM_DIR}/drv_interface.c
	${ARM_CC} ${ARM_LDFLAGS} -o ./lib/${LIB_NAME} ${OBJS}
	${ECHO} "\033[33m Completed PIM MemPool library to \033[31m${TARGET_LIB} \033[0m"
.PHONY: mem_arm	

install:
	install -m 644 ${TARGET_LIB} ${INSTALL_LIB}
	install -m 644 ./include/pim.h ${INSTALL_INC}
	${ECHO} "\033[33m Completed install PIM MemPool library \033[0m"
	${INSMOD}
	${ECHO} "\033[33m Completed insmod PIM device driver \033[0m"
.PHONY: install


SUBDIRS = ${PWD}/test/src/matmul ${PWD}/test/src/elewise ${PWD}/test/src/bias_op ${PWD}/test/src/memcpy ${PWD}/test/src/matmul_decoupled ${PWD}/test/src/pim_mem
test:
	${ECHO} "\033[33m Build test code for PIM operations \033[0m"
	for dir in ${SUBDIRS}; do \
		${MAKE} ARCH=arm64 -C $$dir test; \
	done
	${ECHO} "\033[33m Completed build test code (./test/bin/) \033[0m"
.PHONY: test

uninstall:
	rm ${INSTALL_LIB}/${LIB_NAME}
	rm ${INSTALL_INC}/pim.h
.PHONY: uninstall

clean:
	${ECHO} "\033[33m Remove object files of PIM MemPool library and PIM DMA driver\n \033[0m"
	rm -rf ${DMA_DIR}/*.ko
	rm -rf ${DMA_DIR}/*.mod.*
	rm -rf ${DMA_DIR}/.*.cmd
	rm -rf ${DMA_DIR}/*.o
	rm -rf ${DMA_DIR}/pim_math/.*.o.cmd
	rm -rf ${DMA_DIR}/pim_math/*.o
	rm -rf ${DMA_DIR}/modules.order
	rm -rf ${DMA_DIR}/Module.symvers
	rm -rf ${DMA_DIR}/*.o.*
	rm -rf ${DMA_DIR}/.cache.mk
	rm -rf ./lib/${LIB_NAME} ${MEM_OBJS} ${MATH_OBJS}
	rm ./test/src/*/*.o
	rm ./test/bin/*
.PHONY: clean

help:
	@echo "The following are some of the valid targets for this Makefile:"
	@echo "... all (the default if no target is provied)"
	@echo "... clean"
	@echo "... drv"
	@echo "... mem_x86"
	@echo "... mem_arm"
	@echo "... test"
	@echo "... install"
	@echo "... uninstall"
