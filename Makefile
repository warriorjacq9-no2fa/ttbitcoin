.PHONY: all clean

SRCS = \
src/main.v \
src/sha256_stream.v \
src/sha256d_wrapper.v \
src/macros.v

all: tb.vvp
	vvp $<

unit: tb_unit.vvp
	vvp $<

tb.vvp: test/tb.sv $(SRCS)
	iverilog -g2012 $^ -o $@

tb_unit.vvp: test/tb_unit.sv $(SRCS)
	iverilog -g2012 $^ -o $@

clean:
	rm -f tb.vvp tb_unit.vvp tb.vcd