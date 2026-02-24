.PHONY: all clean

SRCS = \
src/main.v \
src/macros.v \
src/sha256_stream.v \
src/sha256d_wrapper.v

SKY130A = $(PDK_ROOT)/ciel/sky130/versions/*/sky130A/libs.ref

GL_SRCS = \
../tt_submission/tt_um_bitcoin.v \
$(SKY130A)/sky130_fd_sc_hd/verilog/primitives.v \
$(SKY130A)/sky130_fd_sc_hd/verilog/sky130_fd_sc_hd.v \

all: tb.vvp
	vvp $<

unit: tb_unit.vvp
	vvp $<

tb.vvp: test/tb.sv $(SRCS)
	iverilog -g2012 $^ -o $@

tb_unit.vvp: test/tb_unit.sv $(SRCS)
	iverilog -g2012 $^ -o $@

gates: test/tb.sv $(GL_SRCS)
	iverilog -g2012 -DGL_TEST -DFUNCTIONAL -DUSE_POWER_PINS -DSIM -DUNIT_DELAY=\#1 $^ -o a.vvp
	vvp a.vvp

clean:
	rm -f tb.vvp tb_unit.vvp tb.vcd