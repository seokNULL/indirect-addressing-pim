# Standard defines
DEFINE += +define+WAVE_DUMP_VCS+RTL_SIM

# Target follow
RUN = vcs $(DEFINE) $(OP_CLASS) +libext+.v -full64 -v2005 -R -timescale=1ns/10ps +define+VCS -l vcs.log -debug_all -sverilog

all	: Dev_top_test

DELETE =\
*.log \
*.key \
INCA_libs \
*.X \
.simvision \
compare_axi \
DVEfiles \
simv \
simv.daidir \
*.vpd \
csrc \
64 \
AN.DB 

clean	:
	rm -rf $(DELETE)

Dev_top_test :
	$(RUN) -file vlist_Device_top -ucli -do dump.tcl +vpdfile+dump/$@.vpd
