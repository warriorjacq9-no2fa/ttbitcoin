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

`timescale 1ns/1ps

module tb;

    reg  clk;
    reg  rst_n;

    reg  [7:0] ui_in;
    reg  [7:0] uio_in;
    wire [7:0] uo_out;
    wire [7:0] uio_out;
    wire [7:0] uio_oe;

    tt_um_bitcoin dut (
        .ui_in(ui_in),
        .uo_out(uo_out),
        .uio_in(uio_in),
        .uio_out(uio_out),
        .uio_oe(uio_oe),
        .ena(1'b1),
        .clk(clk),
        .rst_n(rst_n)
    );

    // Clock
    always #5 clk = ~clk;

    // Decode outputs
    wire [5:0] addr = uo_out[5:0];
    wire done = uo_out[6];
    wire rq   = uo_out[7];

    reg [639:0] block = 
    640'h0100000000000000000000000000000000000000000000000000000000000000000000003BA3EDFD7A7B12B27AC72C3E67768F617FC81BC3888A51323A9FB8AA4B1E5E4A29AB5F49FFFF001D1DAC2B7C;

    reg [255:0] out;

    reg running;
    integer cycles = 0;

    always @(posedge clk) begin
        if(running) begin
            cycles++;
        end
    end

    function string human_readable(longint unsigned value);
        string suffix;
        real scaled;

        if (value >= 1_000_000_000) begin
            scaled = value / 1_000_000_000.0;
            suffix = "G";
        end
        else if (value >= 1_000_000) begin
            scaled = value / 1_000_000.0;
            suffix = "M";
        end
        else if (value >= 1_000) begin
            scaled = value / 1_000.0;
            suffix = "K";
        end
        else begin
            return $sformatf("%0d", value);
        end

        return $sformatf("%.1f%s", scaled, suffix);
    endfunction

    // Task: write one 16-bit word
    task write_word(input [15:0] w);
        begin
            // Wait for request
            wait (rq == 1'b1);

            // Drive data
            ui_in  <= w[15:8];   // DI8..15
            uio_in <= w[7:0];    // DI/O0..7
            wait (rq == 1'b0);
        end
    endtask

    task read_word(output [255:0] s);
        begin
            // Wait for data-ready
            wait (rq == 1'b1);

            // Read data
            s[(255 - addr*8) -: 8] <= uio_out[7:0];

            // Acknowledge
            ui_in[7] <= 1'b1;
            wait (rq == 1'b0);
            ui_in[7] <= 1'b0;
        end
    endtask

    integer i;

    initial begin
        $dumpfile("tb.vcd");
        $dumpvars(0, tb);
        clk   = 0;
        rst_n = 0;
        ui_in = 8'h00;
        uio_in = 8'h00;
        out = 256'b0;

        #20;
        rst_n = 1;
        running = 1;

        // Send 40 words
        for (i = 0; i < 40; i = i + 1) begin
            write_word(block[(639 - i*16) -: 16]);
        end
        // Wait for DONE
        wait (done == 1'b1);

        while (addr < 32) begin
            read_word(out);
        end
        running = 0;

        $display("Device recieved   %h\n", dut.block);
        $display("Expected          %h", block);

        $display("Hash output       %h\n", out);

        $display("Took      %d cycles (%sH/s at 100MHz)",
            cycles, human_readable(100000000.0/cycles));

        #50;
        $finish;
    end

endmodule
