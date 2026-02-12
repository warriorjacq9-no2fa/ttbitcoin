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

module tt_um_bitcoin (
    input  wire [7:0] ui_in,    // Dedicated inputs
    output wire [7:0] uo_out,   // Dedicated outputs
    input  wire [7:0] uio_in,   // IOs: Input path
    output wire [7:0] uio_out,  // IOs: Output path
    output reg [7:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)
    input  wire       ena,      // always 1 when the design is powered, so you can ignore it
    input  wire       clk,      // clock
    input  wire       rst_n     // reset_n - low to reset
);

    /* External interface */
    wire [5:0] addr;
    reg [5:0] w_addr;
    reg [7:0] data_out;
    wire [15:0] data_in;
    reg done;
    wire rq;
    
    assign uo_out[7:0] = {rq, done, addr[5:0]};
    assign uio_out[7:0] = data_out[7:0];
    assign data_in[15:0] = {ui_in[7:0], uio_in[7:0]};

    /* Internal variables */
    reg [31:0] data;
    wire [4:0] s_addr;
    reg s_rdy;
    wire [255:0] s_hash;
    wire s_done;
    reg start;
    reg state;
    localparam S_HASH=1'h0, S_WRITE=1'h1;

    /* SHA256 core */
    sha256d_wrapper s1 (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .data(data),
        .addr(s_addr),
        .rdy(s_rdy),
        .rq(rq),
        .hash(s_hash),
        .done(s_done)
    );

    reg i;
    assign addr = (state == S_HASH ? {s_addr, i} : {w_addr});

    /* Mainloop */
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            w_addr <= 6'b0;
            data_out <= 8'b0;
            done <= 1'b0;
            state <= S_HASH;
            start <= 1'b0;
            uio_oe <= 8'b0;
            i <= 0;
            s_rdy <= 0;
        end else begin
            if(state == S_HASH) begin
                if(rq) begin
                    data[i*16 +: 16] <= data_in;
                    if(i == 1) s_rdy <= 1;
                    else s_rdy <= 0;
                    i++;
                end
                if(s_done) begin
                    state <= S_WRITE;
                    done <= 1;
                end
            end else if(state == S_WRITE) begin
                data_out <= s_hash[(255 - addr*8) -: 8];
                if(addr == 6'd31) done <= 1;
                else begin
                    done <= 0;
                    w_addr <= w_addr + 1;
                end
            end
        end
    end

    wire _unused = ena;
    
endmodule