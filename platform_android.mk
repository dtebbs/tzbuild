
############################################################

# NDK dir

ANDROID_NDK ?= external/android/android-ndk-r8
ANDROID_NDK_PLATFORM ?= android-9

# Toolset for which arch

ifeq ($(ARCH),armv7a)
  ANDROID_NDK_ARCHDIR := $(ANDROID_NDK)/toolchains/arm-linux-androideabi-4.4.3
  ANDROID_NDK_TOOLPREFIX := arm-linux-androideabi-
  ANDROID_NDK_PLATFORMDIR := \
    $(ANDROID_NDK)/platforms/$(ANDROID_NDK_PLATFORM)/arch-arm
  ANDROID_NDK_STL_LIBS += \
    $(ANDROID_NDK)/sources/cxx-stl/gnu-libstdc++/libs/armeabi-v7a
endif
ifeq ($(ARCH),x86)
  ANDROID_NDK_ARCHDIR := $(ANDROID_NDK)/toolchains/x86-4.4.3
  ANDROID_NDK_TOOLPREFIX := i686-android-linux-
  ANDROID_NDK_PLATFORMDIR := \
    $(ANDROID_NDK)/platforms/$(ANDROID_NDK_PLATFORM)/arch-x86
  ANDROID_NDK_STL_LIBS += \
    $(ANDROID_NDK)/sources/cxx-stl/gnu-libstdc++/libs/x86
endif
ifeq ($(ANDROID_NDK_ARCHDIR),)
  $(error Couldnt determine toolchain for android ARCH $(ARCH))
endif

# Find toolset for this platfom

ifeq ($(BUILDHOST),macosx)
  ANDROID_NDK_TOOLBIN := $(ANDROID_NDK_ARCHDIR)/prebuilt/darwin-x86/bin
endif
ifeq ($(BUILDHOST),linux64)
  ANDROID_NDK_TOOLBIN := $(error set this) \
	$(ANDROID_NDK_ARCHDIR)/prebuilt/linux-x86/bin
endif
ifeq ($(ANDROID_NDK_TOOLBIN),)
  $(error Couldnt find toolchain for BUILDHOST $(BUILDHOST))
endif

# Some include paths

ANDROID_NDK_STL_INCLUDES := \
  $(ANDROID_NDK_STL_LIBS)/include \
  $(ANDROID_NDK)/sources/cxx-stl/gnu-libstdc++/include
ANDROID_NDK_PLATFORM_INCLUDES := \
  $(ANDROID_NDK)/sources/android/native_app_glue \
  $(ANDROID_NDK_PLATFORMDIR)/usr/include

# Set the variant to incldue the arch

VARIANT:=$(strip $(VARIANT)-$(ARCH))

############################################################

#
# CXX
#

# From NDK_BUILD:
# /Users/dtebbs/turbulenz/external/android/android-ndk-r8/toolchains/arm-linux-androideabi-4.4.3/prebuilt/darwin-x86/bin/arm-linux-androideabi-g++
# -MMD -MP -MF
# /Users/dtebbs/turbulenz/build/android/obj/local/armeabi-v7a/objs/turbulenz/__/__/__/src/engine/android/androideventhandler.o.d
# -fpic -ffunction-sections -funwind-tables -fstack-protector
# -D__ARM_ARCH_5__ -D__ARM_ARCH_5T__ -D__ARM_ARCH_5E__ -D__ARM_ARCH_5TE__
# -Wno-psabi
# -march=armv7-a -mfloat-abi=softfp -mfpu=vfp
# -fno-exceptions -fno-rtti -mthumb -Os -fomit-frame-pointer
# -fno-strict-aliasing -finline-limit=64
# -I../../../src/core ...
#  -I/Users/dtebbs/turbulenz/build/android/jni
# -DANDROID -DTZ_USE_V8 -DTZ_ANDROID -DTZ_STANDALONE -DFASTCALL=
# -DTZ_NO_TRACK_REFERENCES -finline-limit=256
# -O3 -Wa,--noexecstack   -O2
# -DNDEBUG -g
# -fexceptions
# -I/Users/dtebbs/turbulenz/external/android/android-ndk-r8/sources/cxx-stl/gnu-libstdc++/include
# -I/Users/dtebbs/turbulenz/external/android/android-ndk-r8/sources/cxx-stl/gnu-libstdc++/libs/armeabi-v7a/include
# -I/Users/dtebbs/turbulenz/external/android/android-ndk-r8/platforms/android-9/arch-arm/usr/include
# -c  /Users/dtebbs/turbulenz/build/android/jni/../../../src/engine/android/androideventhandler.cpp
# -o /Users/dtebbs/turbulenz/build/android/obj/local/armeabi-v7a/objs/turbulenz/__/__/__/src/engine/android/androideventhandler.o

CXX := $(ANDROID_NDK_TOOLBIN)/$(ANDROID_NDK_TOOLPREFIX)g++
CXXFLAGSPRE := \
  -fpic -ffunction-sections -funwind-tables -fstack-protector \
  -D__ARM_ARCH_5__ -D__ARM_ARCH_5T__ -D__ARM_ARCH_5E__ -D__ARM_ARCH_5TE__ \
  -Wall -Wno-unknown-pragmas -Wno-reorder -Wno-trigraphs \
  -Wno-unused-parameter -Wno-psabi \
  -march=armv7-a -mfloat-abi=softfp -mfpu=vfp \
  -mthumb -fomit-frame-pointer \
  -fno-strict-aliasing -finline-limit=64 \
  -DANDROID -DTZ_ANDROID

CXXFLAGSPOST := \
 $(addprefix -I,$(ANDROID_NDK_STL_INCLUDES) $(ANDROID_NDK_PLATFORM_INCLUDES)) \
 -DFASTCALL= -finline-limit=256 -O3 -Wa,--noexecstack -O2 -fexceptions \
 -c

#
# AR
#

AR := $(ANDROID_NDK_TOOLBIN)/$(ANDROID_NDK_TOOLPREFIX)ar
ARFLAGSPRE := cr
arout :=
ARFLAGSPOST :=

libprefix := lib
libsuffix := .a

#
# DLLS
#

# /Users/dtebbs/turbulenz/external/android/android-ndk-r8/toolchains/arm-linux-androideabi-4.4.3/prebuilt/darwin-x86/bin/arm-linux-androideabi-g++
# -Wl,-soname,libturbulenz.so -shared
# --sysroot=/Users/dtebbs/turbulenz/external/android/android-ndk-r8/platforms/android-9/arch-arm
# <objects>
# <libs>
# /Users/dtebbs/turbulenz/build/android/obj/local/armeabi-v7a/libopenal.so
# /Users/dtebbs/turbulenz/build/android/obj/local/armeabi-v7a/libtbb.so
# /Users/dtebbs/turbulenz/build/android/obj/local/armeabi-v7a/libwebsockets.a
# /Users/dtebbs/turbulenz/build/android/obj/local/armeabi-v7a/libgnustl_static.a
# -Wl,--fix-cortex-a8  -Wl,--no-undefined -Wl,-z,noexecstack -L/Users/dtebbs/turbulenz/external/android/android-ndk-r8/platforms/android-9/arch-arm/usr/lib -llog -landroid -lEGL -lGLESv2 -ldl -llog -lc -lm -o /Users/dtebbs/turbulenz/build/android/obj/local/armeabi-v7a/libturbulenz.so


DLL := $(ANDROID_NDK_TOOLBIN)/$(ANDROID_NDK_TOOLPREFIX)gcc
DLLFLAGSPRE := -Wl,-soname,$$(basename $$@) -shared \
  --sysroot=$(ANDROID_NDK_PLATFORMDIR) \
# -nostdlib
# -Wl,-shared,-Bsymbolic

DLLFLAGSPOST := \
  $(ANDROID_NDK_STL_LIBS)/libgnustl_static.a \
  -Wl,--fix-cortex-a8 -Wl,--no-undefined -Wl,-z,noexecstack \
  -L$(ANDROID_NDK_PLATFORMDIR)/usr/lib \
  -landroid -lEGL -lGLESv2 -ldl -llog -lc -lm
# -Wl,--no-whole-archive
# -Wl,-rpath-link=.

DLLFLAGS_LIBDIR := -L
DLLFLAGS_LIB := -l
dllprefix := lib
dllsuffix := .so

#
# APPS
#

LD := $(DLL)
LDFLAGSPRE := $(DLLFLAGSPRE)
LDFLAGSPOST := $(DLLFLAGSPOST)
LDFLAGS_LIBDIR := $(DLLFLAGS_LIBDIR)
LDFLAGS_LIB := $(DLLFLAGS_LIB)
binsuffix := $(dllsuffix)