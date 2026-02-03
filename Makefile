.PHONY: all clean

SRCS = \
test/tb.sv \
src/sha256.v

all: tb.vvp
	vvp $<

tb.vvp: $(SRCS)
	iverilog -g2012 $(SRCS) -o $@

clean:
	rm -f tb.vvp tb.vcd