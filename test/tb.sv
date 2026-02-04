`timescale 1ns / 1ps

module tb;

    reg clk;
    reg rst_n;
    reg [639:0] data;
    wire [255:0] hash;
    wire done;

    // DUT
    sha256 dut (
        .clk(clk),
        .rst_n(rst_n),
        .block(data),
        .hash(hash),
        .done(done)
    );

    // Clock generation: 100 MHz
    always #5 clk = ~clk;

    // Golden hash for Bitcoin genesis block
    localparam [255:0] GOLDEN_HASH =
        256'h6fe28c0ab6f1b372c1a6a246ae63f74f931e8365e15a089c68d6190000000000;

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
        $dumpfile("tb.vcd");
        $dumpvars(0, tb);
        clk = 0;
        rst_n = 0;
        data = 640'h0100000000000000000000000000000000000000000000000000000000000000000000003BA3EDFD7A7B12B27AC72C3E67768F617FC81BC3888A51323A9FB8AA4B1E5E4A29AB5F49FFFF001D1DAC2B7C;
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
