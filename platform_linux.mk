# Copyright (c) 2012 Turbulenz Limited.
# Released under "Modified BSD License".  See COPYING for full text.

############################################################
#
# Linux
#
############################################################

CLANG_VERSION ?= 3.6

#
# CCACHE
#
CCACHE:=$(shell test -n "`which ccache 2&>/dev/null`"; if [ $$? -eq 0 ] ; then echo "ccache" ; fi)

#
# DISTCC
#
ifeq (1,$(ENABLE_DISTCC))
DISTCC:=$(shell test -n "`which distcc 2&>/dev/null`"; if [ $$? -eq 0 ] ; then echo "distcc" ; fi)
endif

#
# RPATH the executable dir?
ifneq (1,$(DISABLE_EXECUTABLE_RPATH))
  _rpath_flags := -Wl,-rpath,'$$$$ORIGIN'
endif

#
# CXX / CMM
#

ifeq (clang,$(COMPILER))
  CXXCOMPILER:=$(shell \
    which clang++ || which clang++-$(CLANG_VERSION) || echo -n \
  )
  ifeq ($(CXXCOMPILER),)
    $(error Cannot find clang++)
  endif
else
  CXXCOMPILER:=g++
endif

CXX := $(CCACHE) $(DISTCC) $(CXXCOMPILER)
CC := $(CXX) -x c

#
# CXX / CMM FLAGS
#

_cxxflags_warnings := \
    -Wall -Wconversion -Wsign-compare -Wno-unknown-pragmas \
    -Wno-overloaded-virtual -Wno-trigraphs -Wno-unused-parameter

# -Wconversion

CFLAGSPRE := \
    -fmessage-length=0 -pipe \
    $(_cxxflags_warnings) \
    -fPIC \
    -ftree-vectorize -msse3 -mssse3

ifeq (clang,$(COMPILER))
  CFLAGSPRE += -Qunused-arguments -Wno-deprecated-register
endif

CFLAGSPOST := -c

# SYMBOLS

ifeq (1,$(C_SYMBOLS))
  CFLAGSPRE += -g
  DLLFLAGSPOST += -g -rdynamic
  LDFLAGSPOST += -g -rdynamic -lc++
endif

ifeq (1,$(C_OPTIMIZE))
  CFLAGSPRE += -O3 -DNDEBUG -ftree-vectorize

else
  CFLAGSPRE += -O0 -D_DEBUG -DDEBUG
  # ifneq (clang,$(COMPILER))
  #   CFLAGSPRE += -falign-functions=4
  # endif
endif

CXXFLAGSPRE := \
  $(CFLAGSPRE) -Wno-overloaded-virtual -std=c++17 -Wno-reorder \
  -DXP_LINUX=1 -DXP_UNIX=1 -DMOZILLA_STRICT_API
CXXFLAGSPOST := $(CFLAGSPOST) -fexceptions -fpermissive

PCHFLAGS := -x c++-header

#
# LIBS
#

AR := ar
ARFLAGSPRE := cr
arout :=
ARFLAGSPOST :=

libprefix := lib
libsuffix := .a

#
# DLLS
#

DLL := g++
DLLFLAGSPRE += -shared
DLLFLAGSPOST += $(_rpath_flags)


DLLFLAGS_LIBDIR := -L
DLLFLAGS_LIB := -l

dllprefix := lib
dllsuffix := .so

#
# APPS
#

LDFLAGS_LIBDIR := -L
LDFLAGS_LIB := -l

LD := g++
LDFLAGSPRE +=
LDFLAGSPOST += -lpthread $(_rpath_flags)


############################################################


# g++ \
#  -shared \
#  -Wl,-soname,turbulenz.so.0.13.0 \
#  <objects> \
#  -Wl,--rpath /usr/local/lib/turbulenz \
#  -L/usr/local/lib/turbulenz -L../../external/v8/lib/linux64 -L../../external/bullet/lib/linux64 -L../../external/zlib/lib/linux64 -L../../external/png/lib/linux64 \
#  -lv8 -lGL -lopenal -lvorbis -lvorbisfile -lpng -ljpeg -lbulletmultithreaded -lbulletdynamics -lbulletcollision -lbulletmath -ltbb `pkg-config --libs-only-l gtkglext-1.0` \
#  -o turbulenz.so.0.13.0
