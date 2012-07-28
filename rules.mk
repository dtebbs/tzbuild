# Copyright (c) 2012 Turbulenz Limited.
# Released under "Modified BSD License".  See COPYING for full text.

############################################################

all:

MODULES := $(LIBS) $(DLLS) $(APPS)
$(call log,MODULES = $(MODULES))

############################################################

#
# Full deps
#

# 1 - mod
#
# Not the clearest piece of code in the world, but ...
#
# For each dependencies of $(1), recursively calculate their full
# dependencies.  Then, with the full deep dependencies of our deps
# calculated, iterate through all dependencies, adding new words on
# the left to the the deepest dependencies appear on the right (to
# satisfy the gcc linker)
#
define _calc_fulldeps

  # Make sure each dep has been calculated
  $(foreach d,$($(1)_deps), \
    $(if $($(d)_depsdone),$(call log,$(d) deps already done),$(eval \
      $(call _calc_fulldeps,$(d)) \
    )) \
  )

  # For each dep, add any words in $(dep)_fulldeps not already in $(1)_fulldeps
  $(foreach d,$($(1)_deps), \
   $(if $(filter $(d),$($(1)_fulldeps)),$(call log,$(d) already in fulldeps),\
     $(eval $(1)_depstoadd := ) \
     $(foreach dd,$($(d)_fulldeps), \
      $(if $(filter $(dd),$($(1)_fulldeps)),$(call log,dep $(dd) already in list for $(d)),\
       $(call log,adding dep $(dd))\
       $(eval $(1)_depstoadd := $($(1)_depstoadd) $(dd))\
       $(call log,depstoadd: $($(1)_depstoadd))\
      )\
     )\
     $(eval $(1)_fulldeps := $(d) $($(1)_depstoadd) $($(1)_fulldeps)) \
   )\
  )

  $(1)_depsdone:=1
  $(call log,Deps for $(1): $($(1)_fulldeps))

endef

$(foreach mod,$(MODULES),$(eval \
  $(call _calc_fulldeps,$(mod)) \
))


$(foreach mod,$(MODULES),$(call log,$(mod)_fulldeps = $($(mod)_fulldeps)))

############################################################

# call full paths of all source files
$(foreach mod,$(MODULES),$(eval \
  $(mod)_src := $(foreach s,$($(mod)_src),$(realpath $(s))) \
))
$(call log,core_src = $(core_src))

# calc <mod>_headerfile all headers belonging to this module
$(foreach mod,$(MODULES),$(eval \
  $(mod)_headerfiles := $(foreach i,$($(mod)_incdirs),$(wildcard $(i)/*.h)) \
))

# calc full paths of all incdirs and libdirs (including externals)
$(foreach mod,$(MODULES) $(EXT),$(eval \
  $(mod)_incdirs := $(foreach i,$($(mod)_incdirs),$(realpath $(i))) \
))
$(call log,javascriptcore_incdirs = $(javascriptcore_incdirs))

# calc full path of each <ext>_libdir
$(foreach ext,$(EXT), \
  $(eval $(ext)_libdir:=$(strip $(foreach l,$($(ext)_libdir),$(realpath $(l)))))\
)
$(call log,javascriptcore_libdir = $(javascriptcore_libdir))

# calc full path of external dlls
$(foreach ext,$(EXT), \
  $(eval $(ext)_dlls := $(foreach l,$($(ext)_lib), \
    $(foreach d,$($(ext)_libdir), \
      $(wildcard $(d)/lib$(l)$(dllsuffix)*) \
    ) \
  )) \
)
$(call log,javascriptcore_dlls = $(javascriptcore_dlls))

# calc <mod>_depincdirs - include dirs from dependencies
$(foreach mod,$(MODULES),$(eval \
  $(mod)_depincdirs := $(foreach d,$($(mod)_fulldeps),$($(d)_incdirs)) \
))

# # calc <mod>_depheaderfiles - include files of dependencies
# $(foreach mod,$(MODULES),$(eval \
#   $(mod)_depheaderfiles := $(foreach d,$($(mod)_fulldeps),$($(d)_headerfiles)) \
# ))

# calc <mod>_depcxxflags
$(foreach mod,$(MODULES),$(eval \
	$(mod)_depcxxflags := $(foreach d,$($(mod)_fulldeps),$($(d)_cxxflags)) \
))

# cal <mod>_depextlibs - libs from dependencies
$(foreach mod,$(MODULES),$(eval \
  $(mod)_depextlibs := $(foreach d,$($(mod)_fulldeps),$($(d)_extlibs)) \
))

# calc external include dirs
$(foreach mod,$(MODULES),$(eval \
  $(mod)_ext_incdirs := $(foreach e,$($(mod)_extlibs) $($(mod)_depextlibs),$($(e)_incdirs)) \
))

# calc external lib dirs
$(foreach mod,$(MODULES),$(eval \
  $(mod)_ext_libdirs := $(foreach e,$($(mod)_extlibs) $($(mod)_depextlibs),$($(e)_libdir)) \
))

# calc external libs
$(foreach mod,$(MODULES),$(eval \
  $(mod)_ext_libs := $(foreach e,$($(mod)_extlibs) $($(mod)_depextlibs),$($(e)_lib)) \
))

# calc external lib files
$(foreach mod,$(MODULES),$(eval \
  $(mod)_ext_libfiles := $(foreach e,$($(mod)_extlibs) $($(mod)_depextlibs),$($(e)_libfile)) \
))

# calc the full list of external dynamic libs for apps and dlls
$(foreach b,$(DLLS) $(APPS),\
  $(eval $(b)_ext_dlls := $(foreach e,$($(b)_extlibs) $($(b)_depextlibs), \
    $($(e)_dlls) \
    ) \
  )\
)

############################################################

# External dlls need to be copied to bin

# 1 - EXT name
# 2 - EXT file
# 3 - destination file
define _copy_external_dll

  $(1) : $(3)

  $(3) : $(2)
	@mkdir -p $$(dir $$@)
	@echo [COPY-DLL] $$(notdir $$<)
	$(CMDPREFIX) cp $$^ $$@

endef

define _null_external_dll

  .PHONY : $(1)
  $(1) :

endef

$(foreach e,$(EXT),$(if $($(e)_dlls),  \
  $(foreach d,$($(e)_dlls),$(eval      \
    $(call _copy_external_dll,$(e),$(d),$(BINDIR)/$(notdir $(d))) \
  )), \
  $(eval $(call _null_external_dll,$(e))) \
))

############################################################

# calc <mod>_OBJDIR
$(foreach mod,$(MODULES),$(eval $(mod)_OBJDIR := $(OBJDIR)/$(mod)))

# calc <mod>_DEPDIR
$(foreach mod,$(MODULES),$(eval $(mod)_DEPDIR := $(DEPDIR)/$(mod)))

#
# For unity builds, replace the src list with a single file, and a
# rule to create it.
#

ifeq ($(UNITY),1)

# 1 - mod
define _make_cxx_unity_file

  $($(1)_src) : $($(1)_unity_src)
	@mkdir -p $($(1)_OBJDIR)
	echo > $$@
	for i in $$^ ; do echo \#line 1 \"$$$$i\" >> $$@ ; cat $$$$i >> $$@ ; done

endef

$(foreach mod,$(MODULES),\
  $(if $($(mod)_unity),                               \
    $(eval $(mod)_unity_src := $($(mod)_src)) 	      \
    $(eval $(mod)_src := $($(mod)_OBJDIR)/$(mod).cpp) \
    $(eval $(call _make_cxx_unity_file,$(mod)))       \
  )                                                   \
)

$(call log, core_unity_src = $(core_unity_src))
$(call log, core_src = $(core_src))

endif #($(UNITY),1)

#
# For each module, create cxx_obj_dep list
#

# 1 - module name
define _make_cxx_obj_dep_list
  $(1)_cxx_obj_dep := \
    $(foreach s,$(filter %.cpp,$($(1)_src)), \
      $(s)!$($(1)_OBJDIR)/$(notdir $(s:.cpp=.o))!$($(1)_DEPDIR)/$(notdir $(s:.cpp=.d)) \
     ) \
    $(foreach s,$(filter %.c,$($(1)_src)), \
      $(s)!$($(1)_OBJDIR)/$(notdir $(s:.c=.o))!$($(1)_DEPDIR)/$(notdir $(s:.c=.d)) \
     )
endef

# 1 - module name
define _make_cmm_obj_dep_list
  $(1)_cmm_obj_dep := $(foreach s,$(filter %.mm,$($(1)_src)), \
    $(s)!$($(1)_OBJDIR)/$(notdir $(s:.mm=.mm.o))!$($(1)_DEPDIR)/$(notdir $(s:.mm=.mm.d)) \
  )
endef

$(foreach mod,$(MODULES), $(eval \
  $(call _make_cxx_obj_dep_list,$(mod)) \
	))

# only look for .mm's on mac

ifeq ($(TARGET),macosx)
  $(foreach mod,$(MODULES), $(eval \
    $(call _make_cmm_obj_dep_list,$(mod)) \
  ))
endif

$(call log,npengine_src = $(npengine_src))
$(call log,npengine_cxx_obj_dep = $(npengine_cxx_obj_dep))
$(call log,npengine_cmm_obj_dep = $(npengine_cmm_obj_dep))

#
# Functions for getting src, obj and dep files
#

_getsrc = $(word 1,$(subst !, ,$(1)))
_getobj = $(word 2,$(subst !, ,$(1)))
_getdep = $(word 3,$(subst !, ,$(1)))

#
# For each modules, calculate the full object list and full depfile list
#

$(foreach mod,$(MODULES),$(eval \
  $(mod)_OBJECTS := \
    $(foreach sod,$($(mod)_cxx_obj_dep),$(call _getobj,$(sod))) \
    $(foreach sod,$($(mod)_cmm_obj_dep),$(call _getobj,$(sod))) \
))
$(call log,npengine_OBJECTS = $(npengine_OBJECTS))

$(foreach mod,$(MODULES),$(eval \
  $(mod)_DEPFILES := \
    $(foreach sod,$($(mod)_cxx_obj_dep),$(call _getdep,$(sod))) \
    $(foreach sod,$($(mod)_cmm_obj_dep),$(call _getdep,$(sod))) \
))
$(call log,npengine_DEPFILES = $(npengine_DEPFILES))

#
# For each module, create the dependency file rules
#

# 1 - mod
# 2 - srcfile
# 3 - object file
# 4 - dep file
define _make_cxx_depfile_rule

  $(4) : $(2)
	@mkdir -p $($(1)_DEPDIR)
	@echo [CXX \(dep\)] \($(1)\) $$(notdir $$<)

	@$(CMDPREFIX:@, )$(CXX) $(CXXFLAGSPRE) $(CXXFLAGS) \
	  -MM -MF $$@ -MT $(3) -MT $$@ -MP \
	  $($(1)_depcxxflags) $($(1)_cxxflags) $($(1)_local_cxxflags) \
	  $(addprefix -I,$($(1)_incdirs)) \
	  $(addprefix -I,$($(1)_depincdirs)) \
	  $(addprefix -I,$($(1)_ext_incdirs)) \
	  $(CXXFLAGSPOST) $($(call file-flags,$(2))) \
	  $$<

endef

# 1 - mod
define _make_depfile_rules

  $(foreach sod,$($(1)_cxx_obj_dep) $($(1)_cmm_obj_dep),$(eval \
    $(call _make_cxx_depfile_rule,$(1),\
	                              $(call _getsrc,$(sod)),\
	                              $(call _getobj,$(sod)),\
                                  $(call _getdep,$(sod))) \
  ))

endef

$(foreach mod,$(MODULES),$(eval $(call _make_depfile_rules,$(mod))))

#
# For each module, create the object build rules
#

# 1 - mod
# 2 - cxx srcfile
# 3 - object file
define _make_cxx_object_rule

  .PRECIOUS : $(3)

  $(3) : $(2)
	@mkdir -p $($(1)_OBJDIR)
	@echo [CXX] \($(1)\) $$(notdir $$<)
	$(CMDPREFIX)$(CXX) $(CXXFLAGSPRE) $(CXXFLAGS) \
      $($(1)_depcxxflags) $($(1)_cxxflags) $($(1)_local_cxxflags) \
      $(addprefix -I,$($(1)_incdirs)) \
      $(addprefix -I,$($(1)_depincdirs)) \
      $(addprefix -I,$($(1)_ext_incdirs)) \
      $(CXXFLAGSPOST) $($(call file_flags,$(2))) \
      $$< -o $$@

endef

# 1 - mod
# 2 - mm srcfile
# 3 - object file
define _make_cmm_object_rule

  .PRECIOUS : $(3)

  $(3) : $(2)
	@mkdir -p $($(1)_OBJDIR)
	@echo [CMM] \($(1)\) $$(notdir $$<)
	$(CMDPREFIX)$(CMM) $(CMMFLAGSPRE) \
      $($(1)_cxxflags) $($(1)_depcxxflags) \
      $(addprefix -I,$($(1)_incdirs)) \
      $(addprefix -I,$($(1)_depincdirs)) \
      $(addprefix -I,$($(1)_ext_incdirs)) \
      $(CMMFLAGSPOST) $($(call file_flags,$(2))) \
      $$< -o $$@

endef

# DEPS WERE:
# $(2) $($(1)_headerfiles) $($(1)_depheaderfiles)

# 1 - mod
define _make_object_rules

  $(foreach sod,$($(1)_cxx_obj_dep),$(eval \
    $(call _make_cxx_object_rule,$(1),$(call _getsrc,$(sod)),$(call _getobj,$(sod))) \
  ))
  $(foreach sod,$($(1)_cmm_obj_dep),$(eval \
    $(call _make_cmm_object_rule,$(1),$(call _getsrc,$(sod)),$(call _getobj,$(sod))) \
  ))

endef

$(foreach mod,$(MODULES),$(eval $(call _make_object_rules,$(mod))))

############################################################

# LIBRARY

# set <lib>_libfile
$(foreach lib,$(LIBS),$(eval \
  $(lib)_libfile := $(LIBDIR)/$(libprefix)$(lib)$(libsuffix) \
))

# depend on the libs for all dependencies
$(foreach mod,$(MODULES),$(eval \
  $(mod)_deplibs := $(foreach d,$($(mod)_fulldeps),$($(d)_libfile)) \
))

# each lib depends on the object files for that module

# 1 - mod
define _make_lib_rule

  $($(1)_libfile) : $($(1)_OBJECTS)
	@mkdir -p $(LIBDIR)
	@echo [AR ] $$(notdir $$@)
	$(CMDPREFIX)$(AR) \
     $(ARFLAGSPRE) \
     $(arout) $$@ \
     $($(1)_OBJECTS) \
      $(ARFLAGSPOST) \

endef

# $($(1)_deplibs)
# $($(1)_ext_libfiles)

$(foreach lib,$(LIBS),$(eval \
  $(call _make_lib_rule,$(lib)) \
))

# lib depends on this target
$(foreach lib,$(LIBS),$(eval \
  $(lib) : $($(lib)_libfile) \
))

############################################################

# DLLS

# calc <dll>_dllfile
$(foreach dll,$(DLLS),$(eval \
  $(dll)_dllfile ?= $(BINDIR)/$(dllprefix)$(dll)$(dllsuffix) \
))

# 1 - mode
define _make_dll_rule

  $($(1)_dllfile) : $($(1)_deplibs) $($(1)_OBJECTS)
	@mkdir -p $(BINDIR)
	@echo [DLL] $$@
	$(CMDPREFIX)$(DLL) $(DLLFLAGSPRE) \
      $($(1)_DLLFLAGSPRE) \
      $(addprefix $(DLLFLAGS_LIBDIR),$(LIBDIR)) \
      $(addprefix $(DLLFLAGS_LIBDIR),$($(1)_ext_libdirs)) \
      $($(1)_OBJECTS) \
      $($(1)_deplibs) \
      $(addprefix $(DLLFLAGS_LIB),$($(1)_ext_libs)) \
      $($(1)_ext_libfiles) \
      $(DLLFLAGSPOST) \
      $($(1)_DLLFLAGSPOST) \
      -o $$@
	$(call dll-post,$(1))
	$($(1)_poststep)


  $(1) : $($(1)_extlibs) $($(1)_depextlibs)

endef

# rule to make dll file
$(foreach dll,$(DLLS),$(eval \
  $(call _make_dll_rule,$(dll)) \
))

# <dll> : $(<dll>_dllfile)
$(foreach dll,$(DLLS),$(eval \
  $(dll) : $($(dll)_dllfile) \
))

############################################################

# APPLICATIONS

# calc <app>_appfile
$(foreach app,$(APPS),$(eval \
  $(app)_appfile := $(BINDIR)/$(app)$(binsuffix) \
))

# 1 - mod
define _make_app_rule

  $($(1)_appfile) : $($(1)_deplibs) $($(1)_OBJECTS)
	@mkdir -p $(BINDIR)
	@echo [LD ] $$@
	$(CMDPREFIX)$(LD) $(LDFLAGSPRE) \
      $(addprefix $(LDFLAGS_LIBDIR),$(LIBDIR)) \
      $(addprefix $(LDFLAGS_LIBDIR),$($(1)_ext_libdirs)) \
      $($(1)_OBJECTS) \
      $($(1)_deplibs) \
      $(addprefix $(LDFLAGS_LIB),$($(1)_ext_libs)) \
      $($(1)_ext_libfiles) \
      $(LDFLAGSPOST) \
      $($(1)_LDFLAGS) \
      -o $$@

endef

# rule to make app file
$(foreach app,$(APPS),$(eval \
  $(call _make_app_rule,$(app)) \
))

# <app> : $(<app>_appfile)
$(foreach app,$(APPS),$(eval \
  $(app) : $($(app)_appfile) \
))

# <mod>_run rule

# 1 - mod
define _run_app_rule

  $(1)_run :
	$(MAKE) $(1)
	$(call _run_prefix,$(1)) $($(1)_appfile)

endef

$(foreach app,$(APPS),$(eval \
  $(call _run_app_rule,$(app)) \
))

############################################################

# BUNDLES  (macosx only)

$(foreach b,$(BUNDLES),\
  $(if $($(b)_version),,$(error $(b) has no version set)) \
  $(if $($(b)_bundlename),,$(error $(b) has no bundlename set)) \
  $(eval $(b)_bundle := $(BINDIR)/$(b).plugin) \
  $(eval $(b)_copylibs := $($(b)_ext_dlls) $($(b)_bundle_extra_files)) \
)

# Fill out the bundle
# 1 - module name
# 2 - bundle location
# 3 - main dll file
# 4 - dependent libs
define _make_bundle_rule

  .PHONY : $(2)

  $(2) : $(3)
	@echo [MAKE BUNDLE] $(2)
	$(CMDPREFIX)rm -rf $(2)
	$(CMDPREFIX)mkdir -p $(2)/Contents/MacOS
	$(CMDPREFIX)cp $(3) $(2)/Contents/MacOS
	$(CMDPREFIX)./build/scripts/build-infoplist.py \
      --bundlename '$($(1)_bundlename)' \
      --executable `basename $(3)` \
      --version $($(1)_version) > $(2)/Contents/Info.plist
	$(CMDPREFIX)for l in $(4) ; do \
      cp $$$$l $(2)/Contents/MacOS; \
    done

  $(1) : $(2)

  $(1)_install :
	$(CMDPREFIX)$(MAKE) $(1)
	@echo [COPY BUNDLE] $(2) -\> \~/Library/Internet\ Plug-Ins/`basename $(2)`
	$(CMDPREFIX)rm -rf ~/Library/Internet\ Plug-Ins/`basename $(2)`
	$(CMDPREFIX)cp -a $(2) ~/Library/Internet\ Plug-Ins

  $(1)_uninstall :
	@echo [UNINSTALL BUNDLE] \~/Library/Internet\ Plug-Ins/`basename $(2)`
	rm -rf ~/Library/Internet\ Plug-Ins/`basename $(2)`

endef

ifeq ($(TARGET),macosx)
  $(foreach b,$(BUNDLES),$(eval \
    $(call _make_bundle_rule,$(b),$($(b)_bundle),$($(b)_dllfile),$($(b)_copylibs)) \
  ))
endif

############################################################

MODULEDEFDIR := moduledefs

# Define the <mod>_moduledef rule
# 1 - module name
# 2 - module type ('executable', 'shared_library', 'static_library')
define _make_moduledef_rule

  $(1)_moduledef := $(MODULEDEFDIR)/$(1).$(TARGET).$(CONFIG).def
  $(MODULEDEFDIR)/$(1).$(TARGET).$(CONFIG).def :
	@mkdir -p $(MODULEDEFDIR)
	@echo [MODULEDEF] \($(1)\) $$@
	@echo "{ 'target_name': '$(1)'," > $$@
	@echo "  'type': 'none'," >> $$@

	@echo "  'dependencies': [" >> $$@
	@for d in $($(1)_deps) ; do echo "    '$$$$d'," ; done >> $$@
	@echo "  ]," >> $$@

	@echo "  'actions': [ {" >> $$@
	@echo "    'action_name': 'build $(1)', 'extension': 'in'," >> $$@
	@echo "    'action': [ 'bash', '-c', " >> $$@
	@if [ "" == "$($(1)_cmds)" ] ; then \
      echo "'if [ \"\$$$$(ACTION)\" == \"clean\" ] ; then \
               echo Cleaning $(1) ; \
               make CONFIG=\$$$$(CONFIGURATION) \
               USE_JSC=$(USE_JSC) USE_V8=$(USE_V8) USE_SM=$(USE_SM) \
               $(1)_clean ; \
             else \
               echo Building $(1) ; \
               make CONFIG=\$$$$(CONFIGURATION) \
               USE_JSC=$(USE_JSC) USE_V8=$(USE_V8) USE_SM=$(USE_SM) \
               $(1) -j4 ;\
             fi' ]," >> $$@ ; \
	else \
	  echo "'$($(1)_cmds)' ]," >> $$@ ; \
	fi
	@echo "    'outputs': [ 'obj' ]," >> $$@

	@echo "    'inputs': [" >> $$@
	@_p=`pwd`/ ; for s in $($(1)_src) ; do echo "      '$$$${s#$$$$_p}'," ; \
	  done >> $$@
	@for s in $($(1)_headerfiles) ; do echo "      '$$$$s'," ; done >> $$@
	@echo "    ]," >> $$@

	@echo "  } ]," >> $$@

	@echo "  'mac_external': 1," >> $$@

	@echo "}," >> $$@

endef

# define <mod>_moduledef for each APP, DLL and LIB
$(foreach m,$(APPS),$(eval \
  $(call _make_moduledef_rule,$(m),executable) \
))
$(foreach m,$(DLLS),$(eval \
  $(call _make_moduledef_rule,$(m),shared_library) \
))
$(foreach m,$(LIBS),$(eval \
  $(call _make_moduledef_rule,$(m),static_library) \
))
$(foreach m,$(RULES),$(eval \
  $(call _make_moduledef_rule,$(m),static_library) \
))

.PHONY : module-defs
module-defs : $(foreach m,$(MODULES) $(RULES),$($(m)_moduledef))

############################################################

# DEPENDENCY FILES

#
# Generate a list of all dependency files
#

# include only those that are relevant to the targets being
# created

ALLDEPFILES := $(foreach t,$(MAKECMDGOALS),                     \
                 $($(t)_DEPFILES)                               \
	             $(foreach d,$($(t)_fulldeps),$($(d)_DEPFILES)) \
                )
-include $(sort $(ALLDEPFILES))

############################################################

# CLEAN

# <mod>_cleanfiles
$(foreach mod,$(MODULES),$(eval \
  $(mod)_cleanfiles := $($(mod)_OBJECTS) $($(mod)_OBJDIR) $($(mod)_libfile) \
    $($(mod)_appfile) $($(mod)_DEPFILES) \
))

# <mod>_clean  rule to delete files

# 1 - mod
define _make_clean_rule
  $(1)_clean :
	rm -rf $($(1)_cleanfiles)
endef

$(foreach mod,$(MODULES),$(eval \
  $(call _make_clean_rule,$(mod)) \
))

# clean rule
.PHONY : clean
clean : $(foreach mod,$(MODULES),$(mod)_clean)

.PHONY : depclean
depclean :
	rm -rf dep

.PHONY : distclean
distclean :
	rm -rf dep obj bin lib
