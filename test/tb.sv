`timescale 1ns / 1ps

module tb;

    reg clk;
    reg rst_n;
    reg [511:0] data;
    wire [255:0] hash;
    wire done;

    // DUT
    sha256 dut (
        .clk(clk),
        .rst_n(rst_n),
        .data(data),
        .hash(hash),
        .done(done)
    );

    // Clock generation: 100 MHz
    always #5 clk = ~clk;

    // Golden hash for "abc"
    localparam [255:0] GOLDEN_HASH =
        256'h315f5bdb76d078c43b8ac0064e4a0164612b1fce77c869345bfc94c75894edd3;

    // --------------------------
    // Helper task to convert a string to SHA-256 padded 512-bit block
    // --------------------------
    task string_to_block(input string msg, output reg [511:0] block);
        integer i;
        integer msg_len;
        reg [63:0] bit_len;
        begin
            block = 512'b0;
            msg_len = msg.len();          // number of bytes
            bit_len = msg_len * 8;       // message length in bits

            // Copy message bytes into the MSBs of the block
            for (i = 0; i < msg_len; i = i + 1) begin
                block[511 - i*8 -: 8] = msg[i];
            end

            // Add the 0x80 bit right after the message
            block[511 - msg_len*8 -: 8] = {1'b1, 7'b0};

            // Append message length in bits at the last 64 bits
            block[63:0] = bit_len;
        end
    endtask

    initial begin
        clk = 0;
        rst_n = 0;
        data = 512'b0;

        // --------------------------------------------------
        // Message = "abc"
        // Use helper task to automatically pad
        // --------------------------------------------------
        string_to_block("Hello, world!", data);

        // Release reset
        #20;
        rst_n = 1;

        // Wait for completion
        wait(done);

        // Small delay to let hash settle
        #10;

        // Check result
        $display("Expected: %h", GOLDEN_HASH);
        $display("Got     : %h", hash);

        $finish;
    end

endmodule
