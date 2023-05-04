cmd_/home/petalinux/pim_sw_versal/src/drv_src/dma_fops_host_x86.o := gcc -Wp,-MMD,/home/petalinux/pim_sw_versal/src/drv_src/.dma_fops_host_x86.o.d -nostdinc -isystem /usr/lib/gcc/aarch64-xilinx-linux/11.2.0/include -I./arch/arm64/include -I./arch/arm64/include/generated  -I./include -I./arch/arm64/include/uapi -I./arch/arm64/include/generated/uapi -I./include/uapi -I./include/generated/uapi -include ./include/linux/compiler-version.h -include ./include/linux/kconfig.h -include ./include/linux/compiler_types.h -D__KERNEL__ -mlittle-endian -DKASAN_SHADOW_SCALE_SHIFT= -fmacro-prefix-map=./= -Wall -Wundef -Werror=strict-prototypes -Wno-trigraphs -fno-strict-aliasing -fno-common -fshort-wchar -fno-PIE -Werror=implicit-function-declaration -Werror=implicit-int -Werror=return-type -Wno-format-security -std=gnu89 -mgeneral-regs-only -DCONFIG_CC_HAS_K_CONSTRAINT=1 -Wno-psabi -mabi=lp64 -fno-asynchronous-unwind-tables -fno-unwind-tables -mbranch-protection=pac-ret+leaf+bti -Wa,-march=armv8.5-a -DARM64_ASM_ARCH='"armv8.5-a"' -DKASAN_SHADOW_SCALE_SHIFT= -fno-delete-null-pointer-checks -Wno-frame-address -Wno-format-truncation -Wno-format-overflow -Wno-address-of-packed-member -O2 -fno-allow-store-data-races -Wframe-larger-than=2048 -fstack-protector-strong -Wimplicit-fallthrough=5 -Wno-main -Wno-unused-but-set-variable -Wno-unused-const-variable -fno-omit-frame-pointer -fno-optimize-sibling-calls -fno-stack-clash-protection -g -Wdeclaration-after-statement -Wvla -Wno-pointer-sign -Wno-stringop-truncation -Wno-zero-length-bounds -Wno-array-bounds -Wno-stringop-overflow -Wno-restrict -Wno-maybe-uninitialized -fno-strict-overflow -fno-stack-check -fconserve-stack -Werror=date-time -Werror=incompatible-pointer-types -Werror=designated-init -Wno-packed-not-aligned -mstack-protector-guard=sysreg -mstack-protector-guard-reg=sp_el0 -mstack-protector-guard-offset=1016  -DMODULE -I/usr/include -DKBUILD_BASENAME='"dma_fops_host_x86"' -DKBUILD_MODNAME='"pim_drv"' -D__KBUILD_MODNAME=kmod_pim_drv -c -o /home/petalinux/pim_sw_versal/src/drv_src/dma_fops_host_x86.o /home/petalinux/pim_sw_versal/src/drv_src/dma_fops_host_x86.c

source_/home/petalinux/pim_sw_versal/src/drv_src/dma_fops_host_x86.o := /home/petalinux/pim_sw_versal/src/drv_src/dma_fops_host_x86.c

deps_/home/petalinux/pim_sw_versal/src/drv_src/dma_fops_host_x86.o := \
  include/linux/compiler-version.h \
    $(wildcard include/config/CC_VERSION_TEXT) \
  include/linux/kconfig.h \
    $(wildcard include/config/CPU_BIG_ENDIAN) \
    $(wildcard include/config/BOOGER) \
    $(wildcard include/config/FOO) \
  include/linux/compiler_types.h \
    $(wildcard include/config/HAVE_ARCH_COMPILER_H) \
    $(wildcard include/config/CC_HAS_ASM_INLINE) \
  include/linux/compiler_attributes.h \
  include/linux/compiler-gcc.h \
    $(wildcard include/config/RETPOLINE) \
    $(wildcard include/config/ARCH_USE_BUILTIN_BSWAP) \
    $(wildcard include/config/KCOV) \
  arch/arm64/include/asm/compiler.h \
    $(wildcard include/config/CFI_CLANG) \

/home/petalinux/pim_sw_versal/src/drv_src/dma_fops_host_x86.o: $(deps_/home/petalinux/pim_sw_versal/src/drv_src/dma_fops_host_x86.o)

$(deps_/home/petalinux/pim_sw_versal/src/drv_src/dma_fops_host_x86.o):
