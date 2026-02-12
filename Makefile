.PHONY: all clean

SRCS = \
test/tb.sv \
src/main.v \
src/sha256_stream.v \
src/sha256d_wrapper.v \
src/macros.v

all: tb.vvp
	vvp $<

tb.vvp: $(SRCS)
	iverilog -g2012 $(SRCS) -o $@

clean:
	rm -f tb.vvp tb.vcd