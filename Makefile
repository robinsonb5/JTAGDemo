DEMISTIFYPATH=DeMiSTify
SUBMODULES=$(DEMISTIFYPATH)/EightThirtyTwo/lib832/lib832.a
PROJECT=JTAGDemo
PROJECTPATH=./
PROJECTTOROOT=../
BOARD=
ROMSIZE1=8192
ROMSIZE2=4096

all: $(DEMISTIFYPATH)/site.template $(DEMISTIFYPATH)/site.mk $(SUBMODULES) firmware init compile tns mist
# Use the file least likely to change within DeMiSTify to detect submodules!
$(DEMISTIFYPATH)/COPYING:
	git submodule update --init --recursive

$(DEMISTIFYPATH)/site.mk: $(DEMISTIFYPATH)/COPYING
	$(info ******************************************************)
	$(info Please copy the example DeMiSTify/site.template file to)
	$(info DeMiSTify/site.mk and edit the paths for the version(s))
	$(info of Quartus you have installed.)
	$(info *******************************************************)
	$(error site.mk not found.)

include $(DEMISTIFYPATH)/site.mk

$(DEMISTIFYPATH)/EightThirtyTwo/Makefile:
	git submodule update --init --recursive

$(SUBMODULES): $(DEMISTIFYPATH)/EightThirtyTwo/Makefile
	make -C $(DEMISTIFYPATH) -f bootstrap.mk

.PHONY: firmware
firmware: $(SUBMODULES)
	make -C firmware -f ../$(DEMISTIFYPATH)/firmware/Makefile DEMISTIFYPATH=../$(DEMISTIFYPATH) ROMSIZE1=$(ROMSIZE1) ROMSIZE2=$(ROMSIZE2)

.PHONY: firmware_clean
firmware_clean: $(SUBMODULES)
	make -C firmware -f ../$(DEMISTIFYPATH)/firmware/Makefile DEMISTIFYPATH=../$(DEMISTIFYPATH) ROMSIZE1=$(ROMSIZE1) ROMSIZE2=$(ROMSIZE2) clean

.PHONY: init
init:
	make -f $(DEMISTIFYPATH)/Makefile DEMISTIFYPATH=$(DEMISTIFYPATH) PROJECTTOROOT=$(PROJECTTOROOT) PROJECTPATH=$(PROJECTPATH) PROJECTS=$(PROJECT) BOARD=$(BOARD) init 

.PHONY: compile
compile: 
	make -f $(DEMISTIFYPATH)/Makefile DEMISTIFYPATH=$(DEMISTIFYPATH) PROJECTTOROOT=$(PROJECTTOROOT) PROJECTPATH=$(PROJECTPATH) PROJECTS=$(PROJECT) BOARD=$(BOARD) compile

.PHONY: clean
clean:
	make -f $(DEMISTIFYPATH)/Makefile DEMISTIFYPATH=$(DEMISTIFYPATH) PROJECTTOROOT=$(PROJECTTOROOT) PROJECTPATH=$(PROJECTPATH) PROJECTS=$(PROJECT) BOARD=$(BOARD) clean

.PHONY: tns
tns:
	@for BOARD in ${BOARDS}; do \
		echo $$BOARD; \
		grep -r Design-wide\ TNS $$BOARD/*.rpt; \
	done

.PHONY: mist
mist:
	@echo -n "Compiling $(PROJECT) for mist... "
	@$(Q13)/quartus_sh >compile.log --flow compile mist/$(PROJECT)_MiST.qpf \
		&& echo "\033[32mSuccess\033[0m" || grep Error compile.log
	@grep -r Design-wide\ TNS mist/*.rpt

.PHONY: mister
mister:
	@echo -n "Compiling $(PROJECT) for MiSTer... "
	@$(QUARTUS_MISTER)/quartus_sh >MiSTer/compile.log --flow compile MiSTer/$(PROJECT).qpf \
		&& echo "\033[32mSuccess\033[0m" || grep Error MiSTer/compile.log

