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

module sha256_unrolled (
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

    reg [31:0] H0, H1, H2, H3, H4, H5, H6, H7;
    assign state_out[255:0] = {H0, H1, H2, H3, H4, H5, H6, H7};
    reg [31:0] a, b, c, d, e, f, g, h;
    reg [5:0] i;


    wire [31:0] t10 = h + `S1(e) + `ch(e,f,g) + `K_at(i*4) + Wt0;
    wire [31:0] t20 = `S0(a) + `maj(a,b,c);
    wire [31:0] a1 = t10 + t20;
    wire [31:0] e1 = d + t10;

    wire [31:0] t11 = g + `S1(e1) + `ch(e1, e, f) + `K_at(i*4 +1) + Wt1;
    wire [31:0] t21 = `S0(a1) + `maj(a1,a,b);
    wire [31:0] a2 = t11 + t21;
    wire [31:0] e2 = c + t11;

    wire [31:0] t12 = f + `S1(e2) + `ch(e2, e1, e) + `K_at(i*4 +2) + Wt2;
    wire [31:0] t22 = `S0(a2) + `maj(a2, a1, a);
    wire [31:0] a3 = t12 + t22;
    wire [31:0] e3 = b + t12;

    wire [31:0] t13 = e + `S1(e3) + `ch(e3, e2, e1) + `K_at(i*4 +3) + Wt3;
    wire [31:0] t23 = `S0(a3) + `maj(a3, a2, a1);
    wire [31:0] a4 = t13 + t23;
    wire [31:0] e4 = a + t13;

    reg [31:0] W [0:15];
    reg [3:0] Wptr;
    wire [31:0] Wt0 = (i < 4 ? 
        W[i*4] :
        `s1(W[(Wptr + 14) & 4'hf]) +
        W[(Wptr + 9) & 4'hf] +
        `s0(W[(Wptr + 1) & 4'hf]) +
        W[Wptr]
    );
    wire [31:0] Wt1 = (i < 4 ? 
        W[i*4 +1] :
        `s1(W[(Wptr + 15) & 4'hf]) +
        W[(Wptr + 10) & 4'hf] +
        `s0(W[(Wptr + 2) & 4'hf]) +
        W[(Wptr + 1) & 4'hf]
    );
    wire [31:0] Wt2 = (i < 4 ? 
        W[i*4 +2] :
        `s1(Wt0) +
        W[(Wptr + 11) & 4'hf] +
        `s0(W[(Wptr + 3) & 4'hf]) +
        W[(Wptr + 2) & 4'hf]
    );
    wire [31:0] Wt3 = (i < 4 ? 
        W[i*4 +3] :
        `s1(Wt1) +
        W[(Wptr + 12) & 4'hf] +
        `s0(W[(Wptr + 4) & 4'hf]) +
        W[(Wptr + 3) & 4'hf]
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
                a <= a4;
                b <= a3;
                c <= a2;
                d <= a1;
                e <= e4;
                f <= e3;
                g <= e2;
                h <= e1;

                if(i >= 4) begin
                    W[(Wptr + 0) & 4'hf] <= Wt0;
                    W[(Wptr + 1) & 4'hf] <= Wt1;
                    W[(Wptr + 2) & 4'hf] <= Wt2;
                    W[(Wptr + 3) & 4'hf] <= Wt3;
                    Wptr <= Wptr + 4;
                end

                if(i == 15) state <= S_OUT;
                else i <= i + 1;
                
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