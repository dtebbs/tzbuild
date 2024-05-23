# Copyright (c) 2012 Turbulenz Limited.
# Released under "Modified BSD License".  See COPYING for full text.

############################################################

$(info ____)
$(info ** Building for Android ARCH:$(ARCH))

############################################################
# Util Functions
############################################################

# 1 - tzbuild arch (armv7a, x86, etc)
_android_arch_name = $(strip                   \
  $(if $(filter armv7a,$(1)),armeabi-v7a,      \
    $(if $(filter arm64,$(1)),arm64-v8a,       \
      $(1)                                     \
    )                                          \
  ))

############################################################

android_build_host := $(BUILDHOST)
ifeq (linux64,$(BUILDHOST))
  android_build_host := linux
endif
ifeq (linux32,$(BUILDHOST))
  android_build_host := linux
endif

# SDK dir

ANDROID_SDK_PATH ?= $(external_path)/android
ANDROID_SDK_TARGET ?= android-15
ANDROID_SDK_TARGET_NUM ?= 15
ANDROID_SDK_VERSION ?= 8
ANDROID_SDK ?= $(ANDROID_SDK_PATH)/android-sdk-$(android_build_host)

# NDK dir

ANDROID_NDK ?= $(ANDROID_SDK_PATH)/android-ndk-r9d
NDK_CLANG_VER ?= 3.4
NDK_HOSTARCH ?= x86_64
NDK_STLPORT ?= 0

# Find toolset for this platfom

ifeq ($(BUILDHOST),macosx)
  NDK_HOSTOS := darwin
endif
ifeq ($(BUILDHOST),linux64)
  NDK_HOSTOS := linux
endif
ifneq (,$(filter win%,$(BUILDHOST)))
  NDK_HOSTOS := windows
endif
ifeq ($(NDK_HOSTOS),)
  $(error Couldnt find toolchain for BUILDHOST $(BUILDHOST))
endif

# Common toolchain path for all architectures
NDK_TOOLCHAIN := $(ANDROID_NDK)/toolchains/llvm/prebuilt/$(NDK_HOSTOS)-$(NDK_HOSTARCH)
NDK_SYSROOT := $(NDK_TOOLCHAIN)/sysroot
SYSROOT := $(NDK_SYSROOT)
# Check that the new dirs exist
ifeq ($(wildcard $(NDK_SYSROOT)/.*),)
  $(error NDK_SYSROOT does not exist: $(NDK_SYSROOT))
endif
$(info ** NDK_SYSROOT: $(NDK_SYSROOT))

ifeq ($(ARCH),armv7a)
    NDK_ARCHNAME := armeabi-v7a
    NDK_TRIPLE := armv7-linux-androideabi
    NDK_FLAGS := -target $(NDK_TRIPLE) -march=armv7-a -mfloat-abi=softfp -mfpu=vfp
    NDK_ARCH_DIR := arm-linux-androideabi
else ifeq ($(ARCH),arm64)
    NDK_ARCHNAME := arm64-v8a
    NDK_TRIPLE := aarch64-linux-android
    NDK_FLAGS := -target $(NDK_TRIPLE) -march=armv8-a
    NDK_ARCH_DIR := aarch64-linux-android
else
    $(error "Unsupported architecture: $(ARCH)")
endif
NDK_LIBDIR := $(NDK_SYSROOT)/usr/lib/$(NDK_ARCH_DIR)
ifeq ($(wildcard $(NDK_LIBDIR)/.*),)
  $(error NDK_LIBDIR does not exist: $(NDK_LIBDIR))
endif
$(info ** NDK_ARCHNAME: $(NDK_ARCHNAME))
$(info ** NDK_TRIPLE: $(NDK_TRIPLE))
$(info ** NDK_FLAGS: $(NDK_FLAGS))
$(info ** NDK_LIBDIR: $(NDK_LIBDIR))

# Toolset for which arch

ANDROID_ARCH_NAME := $(call _android_arch_name,$(ARCH))
$(info ** ANDROID_ARCH_NAME: $(ANDROID_ARCH_NAME))

NDK_TOOLBIN = $(NDK_TOOLCHAIN)/bin
NDK_TOOLPREFIX := $(NDK_ARCHNAME)-
$(info ** NDK_TOOLBIN: $(NDK_TOOLBIN))
$(info ** NDK_TOOLPREFIX: $(NDK_TOOLPREFIX))

# Compiler setup
CC := $(NDK_TOOLBIN)/clang
CXX := $(NDK_TOOLBIN)/clang++
AR := $(NDK_TOOLBIN)/llvm-ar

# Some include paths

NDK_LIBCPP_DIR = $(SYSROOT)/usr
NDK_LIBCPP_LIBS = $(NDK_LIBDIR)/libc++_static.a \
                  $(NDK_LIBDIR)/libc++abi.a

# NDK_LIBCPP_INCLUDES = $(NDK_LIBCPP_DIR)/libcxx/include
NDK_LIBCPP_INCLUDES = \
     $(NDK_LIBCPP_DIR)/include \
     $(NDK_LIBCPP_DIR)/include/$(NDK_ARCHNAME) \
     $(NDK_LIBCPP_DIR)/include/c++/v1

NDK_STL_DIR = $(NDK_LIBCPP_DIR)
NDK_STL_LIBS = $(NDK_LIBCPP_LIBS)

# Add NDK C++ standard library includes
NDK_STL_INCLUDES := \
    $(NDK_LIBCPP_INCLUDES) \
    $(ANDROID_NDK)/sources/cxx-stl/system/include \
    $(SYSROOT)/usr/include


NDK_PLATFORM_INCLUDES = \
    $(ANDROID_NDK)/sources/android/native_app_glue \
    $(ANDROID_NDK)/sysroot/usr/include

NDK_ISYSTEM = $(ANDROID_NDK)/sysroot/usr/include/$(NDK_ARCHNAME)

# Set the variant to include the arch

VARIANT:=$(strip $(VARIANT)-$(ARCH))

############################################################

#
# CXX
#

CC = $(NDK_TOOLBIN)/clang++
CFLAGSPOST += $(NDK_FLAGS)

CXX = $(CC)

CFLAGSPRE += \
  -ffunction-sections -funwind-tables -fstrict-aliasing \
  -Wall -Wno-unknown-pragmas -Wno-trigraphs \
  -Wno-unused-parameter \
  -DANDROID -DTZ_ANDROID -DTZ_USE_V8

# -fstack-protector

ifeq ($(ARCH),armv7a)
  CFLAGSPRE += -fpic -mthumb

  ifeq ($(TEGRA3),1)
    CFLAGSPRE += -mfpu=neon -mcpu=cortex-a9 -mfloat-abi=softfp
  else
    CFLAGSPRE += -march=armv7-a -mfloat-abi=softfp -mfpu=vfp
  endif
endif

ifeq ($(ARCH),x86)
  CFLAGSPRE += -Wa,--noexecstack
endif

#CFLAGSPOST += \
# $(addprefix -I,$(NDK_PLATFORM_INCLUDES)) \
# -DFASTCALL= -Wa,--noexecstack

CFLAGSPOST += \
 -v \
 --sysroot=$(SYSROOT) \
 -I$(SYSROOT)/usr/include \
 -isystem $(NDK_ISYSTEM) \
 -D__ANDROID_API__=$(ANDROID_SDK_TARGET_NUM)

ifeq ($(CONFIG),debug)
  CFLAGSPOST += -DDEBUG -D_DEBUG
endif
ifeq ($(CONFIG),release)
  CFLAGSPOST += -DNDEBUG
endif

ifeq ($(C_OPTIMIZE),1)
  CFLAGSPOST += -g -O3 -ffast-math -ftree-vectorize
  # CFLAGSPOST += -fomit-frame-pointer
else
  CFLAGSPOST += -O0
endif

ifeq ($(C_SYMBOLS),1)
  CFLAGSPOST += -g -funwind-tables
endif

dll-post = \
  $(NDK_TOOLBIN)/llvm-strip --strip-unneeded \
  $($(1)_dllfile)
CFLAGSPOST += -c

CXXFLAGSPRE := $(CFLAGSPRE) -std=c++11 -Wno-reorder -fno-rtti
CXXFLAGSPOST := $(CFLAGSPOST) -fexceptions $(addprefix -I,$(NDK_LIBCPP_INCLUDES))

CFLAGSPOST += -x c -std=gnu11

PCHFLAGS := -x c++-header

#
# AR
#

AR = $(NDK_TOOLBIN)/llvm-ar
$(info ** AR command path: $(AR))

ARFLAGSPRE := cr
arout :=
ARFLAGSPOST :=

libprefix := lib
libsuffix := .a

#
# OBJDUMP
#

OBJDUMP = $(NDK_TOOLBIN)/$(NDK_TOOLPREFIX)objdump
OBJDUMP_DISASS := -S -l

#
# OTHER TOOLS
#

NM = $(NDK_TOOLBIN)/$(NDK_TOOLPREFIX)nm
READELF = $(NDK_TOOLBIN)/$(NDK_TOOLPREFIX)readelf

#
# DLLS
#

DLL = $(NDK_TOOLBIN)/clang++
DLLFLAGSPOST += $(NDK_FLAGS)

# Obsolete
#ARCH_LIB_DIR := $(SYSROOT)/usr/lib/$(NDK_ARCHNAME)/$(ANDROID_SDK_TARGET_NUM)

$(info ** NDK version: $(shell $(NDK_TOOLBIN)/clang++ --version))
$(info ** SYSROOT: $(SYSROOT))
$(info ** NDK_TOOLCHAIN: $(NDK_TOOLCHAIN))

# NOTE: we need the -B path for the linker to find crtbegin_so.o and crtend_so.o .
#  Apparently it shouldn't be necessary, but this is what it's come down to.
DLLFLAGSPRE += -shared \
  --sysroot=$(SYSROOT) \
  -L$(NDK_LIBDIR)/$(ANDROID_SDK_TARGET_NUM) \
  -B$(NDK_LIBDIR)/$(ANDROID_SDK_TARGET_NUM) \
  -nostdlib++ \
  -Wl,-soname,$$(notdir $$@)
# -v  # For verbose
# -nostdlib
# -Wl,-shared,-Bsymbolic

DLLFLAGSPOST += \
  $(NDK_STL_LIBS) \
  -Wl,--no-undefined -Wl,-z,noexecstack \
  -ldl -llog -lc -lm
# Was: -L$(SYSROOT)/usr/lib
# -landroid -lEGL -lGLESv2

# NOTE: Doesn't help since the linker includes these itself without a path
#DLLFLAGSPOST += $(NDK_LIBDIR)/$(ANDROID_SDK_TARGET_NUM)/crtbegin_so.o
#DLLFLAGSPOST += $(NDK_LIBDIR)/$(ANDROID_SDK_TARGET_NUM)/crtend_so.o

ifeq ($(ARCH),armv7a)
  DLLFLAGSPOST += \
    -Wl,--fix-cortex-a8
endif

# -Wl,--no-whole-archive
# -Wl,-rpath-link=.

DLLFLAGS_LIBDIR := -L
DLLFLAGS_LIB := -l
dllprefix := lib
dllsuffix := .so

DLLKEEPSYM_PRE := -Wl,-whole-archive
DLLKEEPSYM_POST := -Wl,-no-whole-archive

#
# APPS
#

LD = $(DLL)
LDFLAGSPRE = $(DLLFLAGSPRE)
LDFLAGSPOST = $(DLLFLAGSPOST)
LDFLAGS_LIBDIR = $(DLLFLAGS_LIBDIR)
LDFLAGS_LIB = $(DLLFLAGS_LIB)
binsuffix = $(dllsuffix)

$(info ** CFLAGSPRE: $(CFLAGSPRE))
$(info ** CFLAGSPOST: $(CFLAGSPOST))
$(info ** LDFLAGSPRE: $(LDFLAGSPRE))
$(info ** LDFLAGSPOST: $(LDFLAGSPOST))

