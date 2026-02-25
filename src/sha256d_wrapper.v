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
    output wire rq,

    // SHA-256 specific
    output wire [255:0] hash,
    output wire done
);

    wire s_start = (state == S_IDLE && start) || 
                 (s_done && state == S_BLOCK1) ||
                 (s_done && state == S_BLOCK2);
    wire s_rq, s_done, s_rdy;
    reg [31:0] s_data;
    wire [3:0] s_addr;
    wire [255:0] s_out;
    assign hash = s_out;
    wire [255:0] s_in = (state == S_BLOCK2 ? s_out : {CH0, CH1, CH2, CH3, CH4, CH5, CH6, CH7});

    assign addr = {state == S_BLOCK2, s_addr};

    localparam S_IDLE=0, S_BLOCK1=1, S_BLOCK2=2, S_DOUBLE=3;
    reg [1:0] state;

    sha256_stream s (
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

    wire internal = (state == S_DOUBLE) || (state == S_BLOCK2 && s_addr > 3);
    assign s_rdy = internal ? s_rq : rdy;
    assign rq = s_rq && !internal;

    always @(*) begin
        s_data = 0;
        if(state == S_BLOCK2 && addr[3:0] > 3) begin
            case (addr[3:0])
                4:          s_data = 32'h80000000;
                15:         s_data = 32'h00000280;
                default:    s_data = 32'h00000000;
            endcase
        end else if(state == S_DOUBLE) begin
            if(addr[3:0] < 8) begin
                s_data = s_out[(255 - addr[3:0]*32) -: 32];
            end else begin
                case(addr[3:0])
                    8:          s_data = 32'h80000000;
                    15:         s_data = 32'h00000100;
                    default:    s_data = 32'h00000000;
                endcase
            end
        end else begin
            s_data = data;
        end
    end

    assign done = (state == S_DOUBLE) && s_done;

    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            state <= S_IDLE;
        end else begin
            if(s_done) begin
                case(state)
                    S_BLOCK1: begin state <= S_BLOCK2; end
                    S_BLOCK2: begin state <= S_DOUBLE; end
                    S_DOUBLE: begin state <= S_IDLE; end
                endcase
            end else if(state == S_IDLE && start) begin
                state <= S_BLOCK1;
            end
        end
    end

endmodule