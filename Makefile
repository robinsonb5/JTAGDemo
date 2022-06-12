DEMISTIFYPATH=DeMiSTify
SUBMODULES=$(DEMISTIFYPATH)/EightThirtyTwo/lib832/lib832.a
PROJECT=JTAGDemo
PROJECTPATH=./
PROJECTTOROOT=../
BOARD=
ROMSIZE1=8192
ROMSIZE2=4096

all: $(DEMISTIFYPATH)/site.template $(DEMISTIFYPATH)/site.mk $(SUBMODULES)
	$(info JTAG Demo project.)
	$(info )
	$(info Building)
	$(info ~~~~~~~~)
	$(info > make BOARDS=board1\ board2.... compile )
	$(info to build the project for the selected board.)
	$(info )
	$(info > make BOARDS=board config )
	$(info to load the bitstream into the FPGA. [currently Lattice only])
	$(info )
	$(info > make BOARDS=board demo )
	$(info to run a demo JTAG script. [currently Lattice only])
	$(info )
	$(info > /path/to/quartus_stp -t jtagbridge.tcl)
	$(info to run a Tcl/Tk-based GUI to communicate with the design [Altera/Intel only])
	$(info )

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

.PHONY: demo
demo:
	openocd -f DeMiSTify/Board/$(BOARDS)/target.cfg -f jtagdemo_oocd.tcl

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
compile: firmware
	make -f $(DEMISTIFYPATH)/Makefile DEMISTIFYPATH=$(DEMISTIFYPATH) PROJECTTOROOT=$(PROJECTTOROOT) PROJECTPATH=$(PROJECTPATH) PROJECTS=$(PROJECT) BOARD=$(BOARD) compile

.PHONY: config
config: compile
	make -f $(DEMISTIFYPATH)/Makefile DEMISTIFYPATH=$(DEMISTIFYPATH) PROJECTTOROOT=$(PROJECTTOROOT) PROJECTPATH=$(PROJECTPATH) PROJECTS=$(PROJECT) BOARD=$(BOARD) config

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

