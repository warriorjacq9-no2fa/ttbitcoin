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

    reg clk, rst_n;
    reg start;
    wire rq;
    reg rdy = 0;
    wire done;
    reg [255:0] hash;

    reg [7:0] data;
    wire [7:0] addr;
    wire [5:0] pad;

    tt_um_bitcoin dut (
        .clk(clk),
        .rst_n(rst_n),
        .ui_in(data),
        .uo_out(addr),
        .uio_in({6'b0, rdy, start}),
        .uio_out({pad[5:2], done, rq, pad[1:0]})
    );

    // Data feeding
    reg [640:0] block = 
    640'h0100000000000000000000000000000000000000000000000000000000000000000000003BA3EDFD7A7B12B27AC72C3E67768F617FC81BC3888A51323A9FB8AA4B1E5E4A29AB5F49FFFF001D1DAC2B7C;
 
    reg [4:0] i = 0;
    always @(posedge rq) begin
        if(done) begin
            rdy <= 1;
            #10;
            rdy <= 0;
            hash[(255 - i*8) -: 8] <= addr;
            i <= i + 1;
        end else begin
            data <= block[(639 - addr*8) -: 8];
            rdy <= 1;
            #10;
            rdy <= 0;
        end
    end

    // Benchmarking
    integer counter = 0;
    logic count = 0;

    // Clock generation: 100 MHz
    always #5 begin
        clk = ~clk;
        if(count) counter++;
    end

    initial begin
        $dumpfile("tb.vcd");
        $dumpvars(0, tb);
        clk = 0;
        rst_n = 0;
        start = 0;
        // Release reset
        #20;
        rst_n = 1;

        // Start the engine
        #20;
        start = 1;
        #20;
        start = 0;
        count = 1;

        // Wait for completion
        wait(done);
        wait(!done);
        count = 0;
        #10;

        $display("\tGot     : %h", hash);
        $display("\tIn      %0d cycles (%f ns at 80MHz, or %0d KH/s)", counter, counter / 0.080, 80000 / counter);

        $finish;
    end

endmodule
