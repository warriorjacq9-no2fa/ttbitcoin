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
    output wire [7:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)
    input  wire       ena,      // always 1 when the design is powered, so you can ignore it
    input  wire       clk,      // clock
    input  wire       rst_n     // reset_n - low to reset
);

    /* External interface */
    assign uio_oe = 8'b00001100;
    wire start = uio_in[0];
    reg rq, done;
    assign uio_out = {4'b0, done, rq, 2'b0};
    wire rdy = uio_in[1];
    reg [7:0] w_data;

    assign uo_out = (done ? w_data : {1'b0, s_addr, i[1:0]});
    wire [7:0] data = ui_in;

    /* SHA256 interface */
    reg [31:0] s_data;
    wire [4:0] s_addr;
    wire s_rq, s_done;
    reg d_srq;
    reg s_start, s_rdy;
    wire [255:0] s_hash;
    sha256d_wrapper s1 (
        .clk(clk),
        .rst_n(rst_n),
        .start(s_start),
        .rdy(s_rdy),
        .data(s_data),
        .addr(s_addr),
        .rq(s_rq),
        .hash(s_hash),
        .done(s_done)
    );

    localparam S_IDLE=2'd0, S_HASH=2'd1, S_WRITE=2'd2;
    reg [1:0] state;

    reg [5:0] i;
    reg read;
    
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            state <= S_IDLE;
            i <= 6'b0;
            w_data <= 8'b0;
            s_start <= 1'b0;
            s_rdy <= 1'b0;
            d_srq <= 1'b0;
            rq <= 1'b0;
            done <= 1'b0;
            read <= 1'b0;
        end else begin
            d_srq <= s_rq;
            case(state)
                S_IDLE: begin
                    if(start) begin
                        s_start <= 1'b1;
                        state <= S_HASH;
                    end
                end
                S_HASH: begin
                    s_start <= 1'b0;
                    // Handle data requests
                    s_rdy <= 1'b0;
                    if(s_rq && !d_srq) read <= 1'b1;
                    if(read) begin
                        if(i < 4 && !rq) begin
                            rq <= 1'b1;
                        end else if(rq && rdy) begin
                            rq <= 1'b0;
                            s_data[31 - i*8 -: 8] <= data;
                            i <= i + 1;
                        end else if(i == 4) begin
                            s_rdy <= 1'b1;
                            read <= 1'b0;
                            i <= 6'b0;
                        end
                    end
                    // Handle done
                    if(s_done) begin
                        done <= 1'b1;
                        state <= S_WRITE;
                    end
                end
                S_WRITE: begin
                    if(i < 32 && !rq) begin
                        rq <= 1'b1;
                        w_data <= s_hash[255 - i*8 -: 8];
                    end else if(rq && rdy) begin
                        rq <= 1'b0;
                        i <= i + 1;
                    end else if(i == 32) begin
                        done <= 1'b0;
                        state <= S_IDLE;
                    end
                end
                default: state <= S_IDLE;
            endcase
        end
    end

    wire _unused = &{uio_in[7:2], ena};

endmodule