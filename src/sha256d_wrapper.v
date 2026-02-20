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

/*
 * Bitcoin double SHA-256 wrapper for SHA256_Stream
 */

module sha256d_wrapper (
    // Control signals
    input wire clk, rst_n,
    input wire start,

    // Bus interface
    input wire rdy,
    input wire [31:0] data,
    output wire [4:0] addr,
    output reg rq,

    // SHA-256 specific
    output wire [255:0] hash,
    output reg done
);
    reg s_rdy, s_start;
    wire s_rq, s_done;
    reg [31:0] s_data;
    wire [3:0] s_addr;
    wire [255:0] s_out;
    assign hash = s_out;
    wire [255:0] s_in = (state == S_BLOCK2 ? s_out : {CH0, CH1, CH2, CH3, CH4, CH5, CH6, CH7});

    reg [255:0] int_hash;

    assign addr = {state == S_BLOCK2, s_addr};

    localparam S_IDLE=0, S_BLOCK1=1, S_BLOCK2=2, S_DOUBLE=3;
    reg [1:0] state;

    sha256_unrolled s (
        .clk(clk),
        .rst_n(rst_n),
        .start(s_start),
        .rdy(s_rdy),
        .data(s_data),
        .addr(s_addr),
        .rq(s_rq),
        .state_in(s_in),
        .state_out(s_out),
        .done(s_done)
    );

    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            s_rdy <= 0;
            s_start <= 0;
            state <= S_IDLE;
            done <= 0;
        end else begin
            if(s_rq) begin
                if(state == S_BLOCK2 && addr[3:0] > 3) begin
                    case (addr[3:0])
                        4:          s_data <= 32'h80000000;
                        15:         s_data <= 32'h00000280;
                        default:    s_data <= 32'h00000000;
                    endcase
                    s_rdy <= 1;
                end else if(state == S_DOUBLE) begin
                    if(addr[3:0] < 8) begin
                        s_data <= int_hash[(255 - addr[3:0]*32) -: 32];
                    end else begin
                        case(addr[3:0])
                            8:          s_data <= 32'h80000000;
                            15:         s_data <= 32'h00000100;
                            default:    s_data <= 32'h00000000;
                        endcase
                    end
                    s_rdy <= 1;
                end else begin
                    s_data <= data;
                    s_rdy <= rdy;
                    rq <= 1;
                end
            end else begin
                s_rdy <= 0;
                rq <= 0;
            end
            if(s_done) begin
                if(state == S_BLOCK1) begin
                    state <= S_BLOCK2;
                    s_start <= 1;
                end
                if(state == S_BLOCK2) begin
                    int_hash <= s_out;
                    s_start <= 1;
                    state <= S_DOUBLE;
                end
                if(state == S_DOUBLE) begin
                    state <= S_IDLE;
                    done <= 1;
                end
            end else begin
                if(state == S_IDLE) begin
                    if(start) begin
                        s_start <= 1;
                        state <= S_BLOCK1;
                    end
                end else s_start <= 0;
            end
        end
    end

endmodule