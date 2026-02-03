`timescale 1ns/1ps

module tb;

    // DUT signals
    logic         clk;
    logic         rst_n;
    logic [511:0] data;
    wire  [255:0] hash;
    wire          done;

    // Instantiate DUT
    sha256 dut (
        .clk  (clk),
        .rst_n(rst_n),
        .data (data),
        .hash (hash),
        .done (done)
    );

    // Clock generation: 100 MHz
    always #5 clk = ~clk;

    // Expected hash for "abc"
    localparam logic [255:0] EXPECTED_HASH =
        256'hba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad;

    initial begin
        $dumpfile("tb.vcd");
        $dumpvars(0, tb);
        // Init
        clk  = 0;
        rst_n = 1;
        data = 512'h0;

        // Reset pulse
        #10;
        rst_n = 0;
        #10;
        rst_n = 1;

        // Apply padded "abc" block
        // "abc" = 0x61 62 63
        // Padding: 0x80 ... length = 24 bits
        data = 512'h61626380_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000018;

        // Wait for completion
        wait (done === 1'b1);
        #1;

        // Check result
        $display("Result:   %h", hash);
        $display("Expected: %h", EXPECTED_HASH);

        #20;
        $finish;
    end

endmodule
