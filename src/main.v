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
    reg [5:0] addr;
    reg [7:0] data_out;
    wire [15:0] data_in;
    reg done, rq;
    
    assign uo_out[7:0] = {rq, done, addr[5:0]};
    assign uio_out[7:0] = data_out[7:0];
    assign data_in[15:0] = {ui_in[7:0], uio_in[7:0]};

    /* Internal variables */
    reg [639:0] block;
    wire [255:0] s_hash;
    reg [255:0] hash;
    wire s_done;
    reg start;
    reg [1:0] state;
    localparam S_READ=2'h0, S_COMPUTE=2'h1, S_WRITE=2'h2, S_IDLE=2'h3;
    wire ack = ui_in[7];

    /* Cores (1 for now) */
    sha256 s1 (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .block(block),
        .hash(s_hash),
        .done(s_done)
    );

    // Edge detection
    reg d_ack;

    /* Mainloop */
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            addr <= 6'b0;
            data_out <= 8'b0;
            done <= 1'b0;
            rq <= 1'b0;
            block <= 640'b0;
            state <= S_READ;
            start <= 1'b0;
            uio_oe <= 8'b0;

            d_ack <= 1'b0;
        end else begin
            d_ack <= ack;
            case (state)
                S_READ: begin
                    uio_oe <= 8'h00;
                    if(addr < 6'd40) begin
                        if(rq) begin
                            block[(639 - addr*16) -: 16] <= data_in[15:0];
                            rq <= 1'b0;
                            addr <= addr + 1;
                        end else begin
                            rq <= 1'b1;
                        end
                    end else begin
                        addr <= 6'b0;
                        state <= S_COMPUTE;
                    end
                end
                
                S_COMPUTE: begin
                    start <= 1'b1;
                    if(s_done) begin
                        hash <= s_hash;
                        done <= 1'b1;
                        state <= S_WRITE;
                    end
                end
                
                S_WRITE: begin
                    done <= 1'b0;
                    uio_oe <= 8'hFF;
                    if(addr < 32) begin
                        rq <= 1'b1;
                        data_out[7:0] <= hash[(255 - addr*8) -: 8];
                        if(ack && !d_ack) begin
                            addr <= addr + 1;
                            rq <= 1'b0;
                        end
                    end else begin
                        state <= S_IDLE;
                    end
                end

                S_IDLE: begin
                    done <= 1'b1;
                end
            endcase
        end
    end 

    
endmodule