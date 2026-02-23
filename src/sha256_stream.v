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

module sha256_stream (
    // Control signals
    input wire clk, rst_n,
    input wire start,

    // Bus interface
    input wire rdy,
    input wire [31:0] data,
    output wire [3:0] addr,
    output reg rq,

    // SHA-256 specific
    input wire [255:0] state_in,
    output wire [255:0] state_out,
    output reg done
);

    wire [31:0] ch_e = `ch(e,f,g);
    wire [31:0] maj_a = `maj(a,b,c);

    wire [31:0] S0_a = `S0(a);
    wire [31:0] S1_e = `S1(e);

    reg [31:0] H0, H1, H2, H3, H4, H5, H6, H7;
    reg [31:0] a, b, c, d, e, f, g, h;
    assign state_out[255:0] = {H0, H1, H2, H3, H4, H5, H6, H7};
    reg [5:0] i;

    /* Combinational calculations */
    wire [31:0] t1 = h + S1_e + ch_e + 
                        `K_at(i) + Wt;
    wire [31:0] t2 = S0_a + maj_a;
    reg [31:0] W [0:15];
    reg [3:0] Wptr;
    wire [31:0] Wt = (i < 16 ? 
        W[i[3:0]] :
        `s1(W[(Wptr + 14) & 4'hF]) +
        W[(Wptr + 9) & 4'hF] +
        `s0(W[(Wptr + 1) & 4'hF]) +
        W[Wptr]
    );

    localparam S_IDLE=0, S_INIT=1, S_COMPUTE=2, S_OUT=3;
    reg [1:0] state;

    assign addr = (i < 16 ? i[3:0] : 0);

    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            rq <= 0;
            done <= 0;
            // State machine
            state <= S_IDLE;
        end else begin
            if(state == S_IDLE) begin
                done <= 0;
                i <= 0;
                if(start) begin
                    state <= S_INIT;
                    {H0, H1, H2, H3, H4, H5, H6, H7} <= state_in;
                    {a, b, c, d, e, f, g, h} <= state_in;
                end
            end else if(state == S_INIT) begin
                if(i < 16 && !rq) begin
                    rq <= 1;
                end
                if(rq && rdy) begin
                    W[i[3:0]] <= data;
                    rq <= 0;
                    i <= i + 1;
                end
                if(i == 16) begin
                    i <= 0;
                    Wptr <= 0;
                    state <= S_COMPUTE;
                end
            end else if(state == S_COMPUTE) begin
                h <= g;
                g <= f;
                f <= e;
                e <= d + t1;
                d <= c;
                c <= b;
                b <= a;
                a <= t1 + t2;

                if(i >= 16) begin
                    W[Wptr] <= Wt;
                    Wptr <= Wptr + 1;
                end

                if(i == 63) state <= S_OUT;
                i <= i + 1;
                
            end else if(state == S_OUT) begin
                H0 <= a + H0;
                H1 <= b + H1;
                H2 <= c + H2;
                H3 <= d + H3;
                H4 <= e + H4;
                H5 <= f + H5;
                H6 <= g + H6;
                H7 <= h + H7;
                done <= 1;
                state <= S_IDLE;
            end
        end
    end

endmodule