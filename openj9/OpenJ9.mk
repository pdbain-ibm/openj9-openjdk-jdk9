ROOT_DIR := $(dir $(shell pwd))
#$(info ROOT_DIR = $(ROOT_DIR))

SPEC_FILE := $(shell find $(ROOT_DIR) -name spec.gmk)
$(info Using SPEC_FILE = $(SPEC_FILE))

ifdef SPEC_FILE
	include $(SPEC_FILE)
else
	$(error Missing OpenJDK SPEC file! Run configure first!)
endif

HGTAG_FILE := $(shell find $(ROOT_DIR) -name .hgtags)
#$(info HGTAG_FILE = $(HGTAG_FILE))

TAG := $(lastword $(shell tail -n 1 $(HGTAG_FILE)))
#$(info OpenJDk TAG = $(TAG))

ifdef TAG
	LEN := $(shell echo $(TAG) | wc -m)
endif
#$(info LEN = $(LEN))

ifdef TAG
ifeq ($(LEN),9)
	ID := $(shell echo $(TAG) | tail -c 3)
else
	ID := $(shell echo $(TAG) | tail -c 4)
endif
endif

#$(info ID = $(ID))
JDK_BUILD = $(shell echo $$(( $(ID) + 1 )))
#$(info JDK_BUILD = $(JDK_BUILD))

PRE_MOD_CFG := $(shell if test "$(JDK_BUILD)" -lt "113"; then echo 1; else echo 0; fi)
#$(info PRE_MOD_CFG = $(PRE_MOD_CFG))

ifeq ($(PRE_MOD_CFG), 1) # pre-modules version
 	BOOT_MOD := bootmodules.jimage
	BOOT_MOD_DIR := bootmodules
	EXTRA_PATH := modules/
else
	BOOT_MOD := modules
	BOOT_MOD_DIR := modules-dir
	EXTRA_PATH := 
endif
#$(info BOOT_MOD = $(BOOT_MOD), BOOT_MOD_DIR = $(BOOT_MOD_DIR))

OPENJ9VM_SRC_DIR := $(shell find $(SRC_ROOT) -maxdepth 1 -type d | grep j9vm)
#$(info OPENJ9VM_SRC_DIR = $(OPENJ9VM_SRC_DIR))

ifndef OPENJ9VM_SRC_DIR
	$(error Missing OpenJ9 VM sources! Run get_source.sh with j9 option!)
endif

OPENJ9JIT_SRC_DIR := $(shell find $(SRC_ROOT) -maxdepth 1 -type d | grep tr.open)
#$(info OPENJ9JIT_SRC_DIR = $(OPENJ9JIT_SRC_DIR))

ifndef OPENJ9JIT_SRC_DIR
	$(error Missing OpenJ9 tr.open sources! Run get_source.sh with j9 option!)
endif

OPENJ9OMR_SRC_DIR := $(shell find $(SRC_ROOT) -maxdepth 1 -type d | grep omr)
#$(info OPENJ9OMR_SRC_DIR = $(OPENJ9OMR_SRC_DIR))

ifndef OPENJ9OMR_SRC_DIR
	$(error Missing OpenJ9 OMR sources! Run get_source.sh with j9 option!)
endif

define \n



endef

define recompilation
	$(BUILD_JAVAP) -c -p $(BUILD_JDK)/modules/$(module)/module-info.class > $(BUILD_JDK)/modules/$(module)/module-info.java.temp
	sed -i -e 's/\$$/\./g' $(BUILD_JDK)/modules/$(module)/module-info.java.temp
	tail -n +2 $(BUILD_JDK)/modules/$(module)/module-info.java.temp > $(BUILD_JDK)/modules/$(module)/module-info.java
	echo $(BUILD_JDK)/modules/$(module)/module-info.java >> $(BUILD_JDK)/../moduleinfo.list
endef

define copy-ibm-specific
	rm -rf $(BUILD_JDK)/modules/$(module)
	mkdir -p $(BUILD_JDK)/modules/$(module)
	cp -rf $(OUTPUT_ROOT)/j9classes/$(module)/* $(BUILD_JDK)/modules/$(module)/.
	echo $(BUILD_JDK)/modules/$(module)/module-info.java >> $(BUILD_JDK)/../moduleinfo.list
endef

define merge-module-info
	cp -rf $(OUTPUT_ROOT)/j9classes/$(module)/* $(BUILD_JDK)/modules/$(module)/.
	mv $(BUILD_JDK)/modules/$(module)/module-info.java $(BUILD_JDK)/modules/$(module)/module-info.java.j9
	$(BUILD_JAVAP) -c -p $(BUILD_JDK)/modules/$(module)/module-info.class > $(BUILD_JDK)/modules/$(module)/module-info.java.temp
	sed -i -e 's/\$$/\./g' $(BUILD_JDK)/modules/$(module)/module-info.java.temp
	tail -n +2 $(BUILD_JDK)/modules/$(module)/module-info.java.temp > $(BUILD_JDK)/modules/$(module)/module-info.java.oracle
	$(BUILD_JAVA) -cp $(OUTPUT_ROOT)/vm/VM_Source-Tools/lib/ com.ibm.moduletools.ModuleInfoMerger $(BUILD_JDK)/modules/$(module)/module-info.java.oracle $(BUILD_JDK)/modules/$(module)/module-info.java.j9 $(BUILD_JDK)/modules/$(module)/module-info.java
	echo $(BUILD_JDK)/modules/$(module)/module-info.java >> $(BUILD_JDK)/../moduleinfo.list
endef

define compile-module-info
	$(BUILD_JAVAC) -source 9 -target 9 -encoding ascii -d $(BUILD_JDK)/modules --module-source-path $(BUILD_JDK)/modules --module-path $(BUILD_JDK)/modules --system none @$(BUILD_JDK)/../moduleinfo.list
endef

# Find recursively in directory $1 all of the files with given extension $2.
#
# Parameters:
#	param 1 is the name of the directory to search
#	parem 2 is the file extension to search in given directory: e.g *.java
# 
define findFiles
	$(foreach i,$(wildcard $1*),$(call findAllFiles,$i/,$2)) $(wildcard $1$2)
endef

# Finds recursively all of the files with given extension in the given source 
# directories and outputs them to a file. 
#
# Parameters:
# 	param 1 is a space separated list of source directories to search
#	param 2 is the extension of the file to look up in the source directories
#	param 3 is the name of the output file
# 
# Usage: $(call cacheFile, dir1 dir2, *.java, /path/to/sources.txt
#
define cacheFiles
	$(foreach d, $1, @echo $(strip $(call findFiles, $d, $2)) >> $3)
endef

NUMCPU := $(shell grep -c ^processor /proc/cpuinfo)
#$(info NUMCPU = $(NUMCPU))

override MAKEFLAGS := -j $(NUMCPU)

.PHONY: clean-j9 clean-j9-dist compose-j9 create-jmod prepare-jmod setup-j9jcl compile-j9 stage-j9 openj9 run-preprocessors-j9 build-j9 setup-j9jcl-pre-jcl merge_module compose
.NOTPARALLEL:
build-j9: stage-j9 run-preprocessors-j9 compile-j9 setup-j9jcl-pre-jcl

stage-j9:
	@echo "---------------- Staging OpenJ9 components in $(OUTPUT_ROOT)/vm ------------------"
	rm -rf $(OUTPUT_ROOT)/vm
	mkdir $(OUTPUT_ROOT)/vm
	# actions required to hammer j9vm repo into the 'source.zip' shape
	cp -r $(OPENJ9VM_SRC_DIR)/* $(OUTPUT_ROOT)/vm
	rm -rf $(OUTPUT_ROOT)/vm/8096_*
	cp -r $(OUTPUT_ROOT)/vm/VM_NLS/* $(OUTPUT_ROOT)/vm
	rm -rf $(OUTPUT_ROOT)/vm/VM_NLS
	cp -r $(OUTPUT_ROOT)/vm/VM_Common/* $(OUTPUT_ROOT)/vm
	rm -rf $(OUTPUT_ROOT)/vm/VM_Common
	cp -r $(OUTPUT_ROOT)/vm/VM_Runtime-Tools/* $(OUTPUT_ROOT)/vm
	rm -rf $(OUTPUT_ROOT)/vm/VM_Runtime-Tools
	cp -r $(OPENJ9VM_SRC_DIR)/../tooling/VM_Build-Tools/* $(OUTPUT_ROOT)/vm
	cp -r $(OPENJ9VM_SRC_DIR)/../tooling/VM_Build-Specifications/* $(OUTPUT_ROOT)/vm
	cp $(OPENJ9VM_SRC_DIR)/../binaries/common/ibm/recordio.jar $(OUTPUT_ROOT)/vm/DTFJ\ Core\ File\ Support/
	cp $(OPENJ9VM_SRC_DIR)/../binaries/common/ibm/ibmjzos.jar $(OUTPUT_ROOT)/vm/DTFJ\ Core\ File\ Support/
	mkdir $(OUTPUT_ROOT)/vm/DTFJ_Utils/lib/
	cp $(OPENJ9VM_SRC_DIR)/../binaries/common/third/asm-3.1.jar $(OUTPUT_ROOT)/vm/DTFJ_Utils/lib/
	mkdir $(OUTPUT_ROOT)/vm/J9\ JCL\ Build\ Tools/lib
	cp $(OPENJ9VM_SRC_DIR)/../binaries/vm/third/dbghelp.dll $(OUTPUT_ROOT)/vm/J9\ JCL\ Build\ Tools/lib/
	cp $(OPENJ9VM_SRC_DIR)/../binaries/vm/ibm/buildutils.jar $(OUTPUT_ROOT)/vm/J9\ JCL\ Build\ Tools/lib/buildutils.jar
	cp $(OPENJ9VM_SRC_DIR)/../binaries/vm/ibm/awtMessageStrings.jar $(OUTPUT_ROOT)/vm/J9\ JCL\ Build\ Tools/lib/awtMessageStrings.jar
	cp $(OPENJ9VM_SRC_DIR)/../binaries/vm/ibm/apimarker.jar $(OUTPUT_ROOT)/vm/J9\ JCL\ Build\ Tools/lib/
	cp $(OPENJ9VM_SRC_DIR)/../binaries/vm/ibm/japt.jar $(OUTPUT_ROOT)/vm/J9\ JCL\ Build\ Tools/lib/
	cp $(OPENJ9VM_SRC_DIR)/../binaries/vm/ibm/jpp.jar $(OUTPUT_ROOT)/vm/J9\ JCL\ Build\ Tools/lib/
	cp $(OPENJ9VM_SRC_DIR)/../binaries/vm/ibm/zipit.jar $(OUTPUT_ROOT)/vm/J9\ JCL\ Build\ Tools/lib/
	cp $(OPENJ9VM_SRC_DIR)/../binaries/vm/ibm/jikesbt.jar $(OUTPUT_ROOT)/vm/J9\ JCL\ Build\ Tools/lib/
	cp $(OPENJ9VM_SRC_DIR)/../binaries/vm/ibm/TestGen.jar $(OUTPUT_ROOT)/vm/J9\ JCL\ Build\ Tools/lib/
	cp $(OPENJ9VM_SRC_DIR)/../binaries/vm/ibm/Compiler.jar $(OUTPUT_ROOT)/vm/J9\ JCL\ Build\ Tools/lib/
	cp $(OPENJ9VM_SRC_DIR)/../binaries/vm/ibm/indexer.jar $(OUTPUT_ROOT)/vm/J9\ JCL\ Build\ Tools/lib/
	cp $(OPENJ9VM_SRC_DIR)/../binaries/common/third/junit3.8.2.jar $(OUTPUT_ROOT)/vm/J9\ JCL\ Build\ Tools/lib/
	cp $(OPENJ9VM_SRC_DIR)/../binaries/common/third/junit.jclbuildtools.jar $(OUTPUT_ROOT)/vm/J9\ JCL\ Build\ Tools/lib/JUnit.jar
	cp $(OPENJ9VM_SRC_DIR)/../binaries/common/third/xercesImpl.jar $(OUTPUT_ROOT)/vm/VM_Source-Tools/lib/
	cp $(OPENJ9VM_SRC_DIR)/../binaries/common/third/dom4j-1.6.1.jar $(OUTPUT_ROOT)/vm/VM_Source-Tools/lib/
	cp $(OPENJ9VM_SRC_DIR)/../binaries/common/third/xmlParserAPIs-2.0.2.jar $(OUTPUT_ROOT)/vm/VM_Source-Tools/lib/
	cp $(OPENJ9VM_SRC_DIR)/../binaries/common/third/gnujaxp.jar $(OUTPUT_ROOT)/vm/VM_Source-Tools/lib/
	mkdir -p $(OUTPUT_ROOT)/vm/J9\ JCL\ buildpath/sun190
	mkdir $(OUTPUT_ROOT)/vm/J9\ JCL\ buildpath/sun190B136
	cp $(OPENJ9VM_SRC_DIR)/../binaries/vm/third/rt-compressed.sun190B136.jar $(OUTPUT_ROOT)/vm/J9\ JCL\ buildpath/sun190B136/rt-compressed.jar
	cp $(OPENJ9VM_SRC_DIR)/../binaries/vm/third/rt-compressed.sun190.jar $(OUTPUT_ROOT)/vm/J9\ JCL\ buildpath/sun190/rt-compressed.jar
	# actions required to hammer tr.open repo into the 'source.zip' shape
	cp -r $(OPENJ9JIT_SRC_DIR)/* $(OUTPUT_ROOT)/vm/tr.source/
	echo "#define TR_LEVEL_NAME \"`git -C $(OPENJ9JIT_SRC_DIR) describe --tags`\"" > $(OUTPUT_ROOT)/vm/tr.source/jit.version
	# actions required to hammer OMR repo into the 'source.zip' shape
	mkdir $(OUTPUT_ROOT)/vm/omr
	cp -r $(OPENJ9OMR_SRC_DIR)/* $(OUTPUT_ROOT)/vm/omr/
	echo "#define OMR_VERSION_STRING \"`git -C $(OPENJ9OMR_SRC_DIR) rev-parse --short HEAD`\"" > $(OUTPUT_ROOT)/vm/omr/OMR_VERSION_STRING
	sed -i '/com.ibm.util.ant.CVSSync/d' $(OPENJ9VM_SRC_DIR)/../tooling/jvmbuild_scripts/build_jvmbuilds.xml
	sed -i -e 's/workspace\///g' $(OPENJ9VM_SRC_DIR)/../tooling/jvmbuild_scripts/build_jvmbuilds.xml
	@echo "---------------- Finished staging OpenJ9 ------------------------"

run-preprocessors-j9: stage-j9
	@echo "---------------- Running OpenJ9 preprocessors ------------------------"
	cd $(OUTPUT_ROOT)/vm
	$(BOOT_JDK)/bin/javac "$(OUTPUT_ROOT)/vm/J9 JCL Build Tools/src/com/ibm/moduletools/ModuleInfoMerger.java" -d $(OUTPUT_ROOT)/vm/VM_Source-Tools/lib
	(export BOOT_JDK=$(BOOT_JDK) && cd $(OUTPUT_ROOT)/vm && $(MAKE) $(MAKEFLAGS) -f buildtools.mk SPEC=linux_x86-64 JAVA_HOME=$(BOOT_JDK) BUILD_ID=000000 UMA_OPTIONS_EXTRA="-buildDate $(shell date +'%Y%m%d')" tools)
	$(eval J9VM_SHA=$(shell git -C $(OPENJ9VM_SRC_DIR) rev-parse --short HEAD))
	@sed -i -e 's/developer.compile/$(J9VM_SHA)/g' $(OUTPUT_ROOT)/vm/include/j9version.h
	@echo J9VM version string set to : $(J9VM_SHA)
	sed -i -e 's/gcc-4.6/gcc/g' $(OUTPUT_ROOT)/vm/makelib/mkconstants.mk
	sed -i -e 's/O3 -fno-strict-aliasing/O0 -Wno-format -Wno-unused-result -fno-strict-aliasing -fno-stack-protector/g' $(OUTPUT_ROOT)/vm/makelib/targets.mk
	# generate RAS binaries - PROBLEM: need to fix these to work with new sdk release
	(export JAVA_HOME=$(BOOT_JDK8) && ant -lib $(OPENJ9VM_SRC_DIR)/../binaries/common/ibm/om.jar -f $(OUTPUT_ROOT)/vm/RAS_Binaries/build.xml -Djavabin_java8=$(BOOT_JDK8)/bin -Djavabin_java9=$(BOOT_JDK)/bin -Djar.dir=$(OUTPUT_ROOT)/vm/VM_Source-Tools/lib/ -Dwith-boot-jdk=$(BOOT_JDK))
	(cd "$(OUTPUT_ROOT)/vm/J9 JCL/" && $(MAKE) -f cuda4j.mk JVM_VERSION=28 SPEC_LEVEL=1.8 BUILD_ID=$(shell date +'%N') BUILD_ROOT=$(OUTPUT_ROOT)/vm JAVA_BIN=$(BOOT_JDK)/bin WORKSPACE=$(OUTPUT_ROOT)/vm)
	(cd "$(OUTPUT_ROOT)/vm/J9 JCL/" && $(MAKE) -f cuda4j.mk JVM_VERSION=28 SPEC_LEVEL=1.9 BUILD_ID=$(shell date +'%N') BUILD_ROOT=$(OUTPUT_ROOT)/vm JAVA_BIN=$(BOOT_JDK)/bin WORKSPACE=$(OUTPUT_ROOT)/vm)
	$(MAKE) $(MAKEFLAGS) -f "$(OUTPUT_ROOT)/vm/JCL Ant Build/jcl_build.mk" SPEC_LEVEL=1.9 JPP_CONFIG=SIDECAR19_MODULAR-SE_B136 BUILD_ID=$(shell date +'%N') COMPILER_BCP=sun190B136 JPP_DIRNAME=jclSC19ModularB136 JAVA_BIN=$(BOOT_JDK)/bin/ BUILD_ROOT=$(OUTPUT_ROOT)/vm NVCC=/usr/local/cuda-5.5/bin/nvcc WORKSPACE=$(OUTPUT_ROOT)/vm 
	$(MAKE) $(MAKEFLAGS) -f "$(OUTPUT_ROOT)/vm/JCL Ant Build/jcl_build.mk" SPEC_LEVEL=1.9 JPP_CONFIG=SIDECAR19-DAA BUILD_ID=$(shell date +'%N') COMPILER_BCP=sun190 JPP_DIRNAME=jclSC190-DAA JAVA_BIN=$(BOOT_JDK)/bin/ BUILD_ROOT=$(OUTPUT_ROOT)/vm NVCC=/usr/local/cuda-5.5/bin/nvcc WORKSPACE=$(OUTPUT_ROOT)/vm
	@echo "---------------- Finished OpenJ9 preprocessors ------------------------"

compile-j9: run-preprocessors-j9 
	@echo "----------------Compiling OpenJ9 in $(OUTPUT_ROOT)/vm ------------------"
	(cd $(OUTPUT_ROOT)/vm && $(MAKE) $(MAKEFLAGS) all)
	@echo "--------------------- Finished compiling OpenJ9 ------------------------"

setup-j9jcl-pre-jcl: 
	@echo "----------------------Extract vm.jar and jcl-4-raw.jar ------------"
	rm -rf $(OUTPUT_ROOT)/j9classes
	mkdir -p $(OUTPUT_ROOT)/j9classes
	unzip -qo "$(OUTPUT_ROOT)/vm/J9 JCL/cuda4j_j9_modular.jar" -d $(OUTPUT_ROOT)/j9classes
	unzip -qo $(OUTPUT_ROOT)/vm/build/j9jcl/source/ive/lib/jclSC19ModularB136/classes-vm.zip -d $(OUTPUT_ROOT)/j9classes
	unzip -qo $(OPENJ9VM_SRC_DIR)/../tooling/jvmbuild_scripts/jcl-4-raw.jar -d $(OUTPUT_ROOT)/j9classes/java.base
	unzip -qo $(OUTPUT_ROOT)/vm/build/j9jcl/source/ive/lib/jclSC190-DAA/classes-vm.zip -d $(OUTPUT_ROOT)/j9classes/java.base/ "com/ibm/dataaccess/*"
	unzip -qo $(OUTPUT_ROOT)/vm/VM_Source-Tools/lib/java9_dtfj-interface.jar -d $(OUTPUT_ROOT)/j9classes/com.ibm.dtfj
	unzip -qo $(OUTPUT_ROOT)/vm/VM_Source-Tools/lib/java9_dtfj.jar -d $(OUTPUT_ROOT)/j9classes/com.ibm.dtfj
	cp "$(OUTPUT_ROOT)/vm/J9 JCL/src/com.ibm.dtfj/module-info.java" $(OUTPUT_ROOT)/j9classes/com.ibm.dtfj/
	rm -rf $(OUTPUT_ROOT)/j9classes/com.ibm.dtfj/META-INF
	unzip -qo $(OUTPUT_ROOT)/vm/VM_Source-Tools/lib/java9_dtfjview.jar -d $(OUTPUT_ROOT)/j9classes/com.ibm.dtfjview
	cp "$(OUTPUT_ROOT)/vm/J9 JCL/src/com.ibm.dtfjview/module-info.java" $(OUTPUT_ROOT)/j9classes/com.ibm.dtfjview/
	rm -rf $(OUTPUT_ROOT)/j9classes/com.ibm.dtfjview/META-INF
	rm -rf $(OUTPUT_ROOT)/j9classes/META-INF
	cp $(OPENJ9VM_SRC_DIR)/../tooling/jvmbuild_scripts/jvm.cfg $(OUTPUT_ROOT)/jdk/lib/amd64/
	$(SED) -i -e 's/shape=vm.shape/shape=b$(JDK_BUILD)/g' $(OUTPUT_ROOT)/vm/classlib.properties
	$(MKDIR) -p $(OUTPUT_ROOT)/jdk/lib/amd64/compressedrefs/
	cp -R $(OUTPUT_ROOT)/vm/*.so $(OUTPUT_ROOT)/jdk/lib/amd64/compressedrefs/
	cp $(OUTPUT_ROOT)/vm/J9TraceFormat.dat $(OUTPUT_ROOT)/jdk/lib/
	cp $(OUTPUT_ROOT)/vm/OMRTraceFormat.dat $(OUTPUT_ROOT)/jdk/lib/
	cp -R $(OUTPUT_ROOT)/vm/options.default $(OUTPUT_ROOT)/jdk/lib/
	cp -R $(OUTPUT_ROOT)/vm/java*properties $(OUTPUT_ROOT)/jdk/lib/
	mkdir -p $(OUTPUT_ROOT)/jdk/lib/amd64/j9vm
	cp $(OUTPUT_ROOT)/vm/redirector/libjvm.so $(OUTPUT_ROOT)/jdk/lib/amd64/j9vm
	cp $(OUTPUT_ROOT)/vm/classlib.properties  $(OUTPUT_ROOT)/jdk/lib
	cp $(OUTPUT_ROOT)/vm/classlib.properties $(OUTPUT_ROOT)/jdk/lib/amd64/compressedrefs

J9_LIST := java.base jdk.attach java.logging java.management
J9_SPECIFIC := com.ibm.management com.ibm.dtfj com.ibm.dtfjview
OPENJ9_IMAGE_DIR:=jdk

merge_module:
	$(eval $(shell rm -rf $(BUILD_JDK)/../moduleinfo.list))
	$(eval override MODULE_LIST = $(filter-out $(J9_SPECIFIC), $(filter-out $(J9_LIST),$(shell find $(BUILD_JDK)/modules/ -maxdepth 1 -type d -exec basename '{}' \; | tail -n +2 | tr '\n' ' '))))
	$(foreach module, $(J9_SPECIFIC), $(call copy-ibm-specific) $(\n))
	$(foreach module, $(J9_LIST), $(call merge-module-info) $(\n))
	$(foreach module, $(MODULE_LIST), $(call recompilation) $(\n))
	$(call compile-module-info)

compose:
	cp $(OPENJ9VM_SRC_DIR)/../tooling/jvmbuild_scripts/jvm.cfg $(IMAGES_OUTPUTDIR)/$(OPENJ9_IMAGE_DIR)/lib/amd64/
	$(SED) -i -e 's/shape=vm.shape/shape=b$(JDK_BUILD)/g' $(OUTPUT_ROOT)/vm/classlib.properties
	$(MKDIR) -p $(IMAGES_OUTPUTDIR)/$(OPENJ9_IMAGE_DIR)/lib/amd64/compressedrefs/
	cp -R $(OUTPUT_ROOT)/vm/*.so $(IMAGES_OUTPUTDIR)/$(OPENJ9_IMAGE_DIR)/lib/amd64/compressedrefs/
	cp $(OUTPUT_ROOT)/vm/J9TraceFormat.dat $(IMAGES_OUTPUTDIR)/$(OPENJ9_IMAGE_DIR)/lib/
	cp $(OUTPUT_ROOT)/vm/OMRTraceFormat.dat $(IMAGES_OUTPUTDIR)/$(OPENJ9_IMAGE_DIR)/lib/
	cp -R $(OUTPUT_ROOT)/vm/options.default $(IMAGES_OUTPUTDIR)/$(OPENJ9_IMAGE_DIR)/lib/
	cp -R $(OUTPUT_ROOT)/vm/java*properties $(IMAGES_OUTPUTDIR)/$(OPENJ9_IMAGE_DIR)/lib/
	mkdir -p $(IMAGES_OUTPUTDIR)/$(OPENJ9_IMAGE_DIR)/lib/amd64/j9vm
	cp $(OUTPUT_ROOT)/vm/redirector/libjvm.so $(IMAGES_OUTPUTDIR)/$(OPENJ9_IMAGE_DIR)/lib/amd64/j9vm
	cp $(OUTPUT_ROOT)/vm/classlib.properties  $(IMAGES_OUTPUTDIR)/$(OPENJ9_IMAGE_DIR)/lib
	cp $(OUTPUT_ROOT)/vm/classlib.properties $(IMAGES_OUTPUTDIR)/$(OPENJ9_IMAGE_DIR)/lib/amd64/compressedrefs

clean-j9:
	( cd $(OUTPUT_ROOT)/vm && \
		$(MAKE) clean )
clean-j9-dist:
	rm -fdr $(IMAGES_OUTPUTDIR)/$(OPENJ9_IMAGE_DIR)
	rm -fdr $(OUTPUT_ROOT)/vm

