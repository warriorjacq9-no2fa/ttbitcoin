/* 
 * Copyright (C) 2026 Jack Flusche <jackflusche@gmail.com>
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
 */

`timescale 1ns / 1ps

module tb;

    reg clk;
    reg rst_n;
    reg start;
    reg [639:0] data;
    wire [255:0] hash;
    wire done;

    // DUT
    sha256 dut (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .block(data),
        .hash(hash),
        .done(done)
    );

    // Clock generation: 100 MHz
    always #5 clk = ~clk;

    // Golden hash for Bitcoin genesis block
    localparam [255:0] GOLDEN_HASH =
        256'h6fe28c0ab6f1b372c1a6a246ae63f74f931e8365e15a089c68d6190000000000;

    initial begin
        $dumpfile("tb.vcd");
        $dumpvars(0, tb);
        $dumpvars(0, dut.W[0]);
        $dumpvars(0, dut.W[1]);
        $dumpvars(0, dut.W[2]);
        $dumpvars(0, dut.W[3]);
        $dumpvars(0, dut.W[4]);
        $dumpvars(0, dut.W[5]);
        $dumpvars(0, dut.W[6]);
        $dumpvars(0, dut.W[7]);
        $dumpvars(0, dut.W[8]);
        $dumpvars(0, dut.W[9]);
        $dumpvars(0, dut.W[10]);
        $dumpvars(0, dut.W[11]);
        $dumpvars(0, dut.W[12]);
        $dumpvars(0, dut.W[13]);
        $dumpvars(0, dut.W[14]);
        $dumpvars(0, dut.W[15]);
        clk = 0;
        rst_n = 0;
        start = 0;
        data = 640'h0100000000000000000000000000000000000000000000000000000000000000000000003BA3EDFD7A7B12B27AC72C3E67768F617FC81BC3888A51323A9FB8AA4B1E5E4A29AB5F49FFFF001D1DAC2B7C;
        // Release reset
        #20;
        rst_n = 1;

        // Start the engine
        #20;
        start = 1;
        #20;
        start = 0;

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
