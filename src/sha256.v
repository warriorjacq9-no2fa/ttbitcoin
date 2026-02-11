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


module sha256 (
    input wire clk, rst_n,
    input wire start,
    input wire [639:0] block,
    output wire [255:0] hash,
    output wire done
);

    `define rotr(x, n) (((x) >> (n)) | ((x) << (32 - (n))))
    wire [31:0] ch_e = (e & f) ^ (~e & g);
    wire [31:0] maj_a = (a & b) ^ (a & c) ^ (b & c);

    wire [31:0] S0_a = {a[1:0],a[31:2]} ^ {a[12:0],a[31:13]} ^ {a[21:0],a[31:22]};
    wire [31:0] S1_e = {e[5:0],e[31:6]} ^ {e[10:0],e[31:11]} ^ {e[24:0],e[31:25]};
    `define s0(x) (`rotr((x), 7) ^ `rotr((x), 18) ^ ((x) >> 3))
    `define s1(x) (`rotr((x), 17) ^ `rotr((x), 19) ^ ((x) >> 10))

    /* ----- SHA256 Calculation ----- */
    reg [31:0] a, b, c, d, e, f, g, h;
    reg [31:0] H0, H1, H2, H3, H4, H5, H6, H7;
    /* Combinational calculations */
    wire [31:0] t1 = h + S1_e + ch_e + 
                        K(i) + Wt;
    wire [31:0] t2 = S0_a + maj_a;
    reg [31:0] W [0:15];
    wire [31:0] Wt = (i < 16 ?
        W[i[3:0]] :
        `s1(W[14]) +
        W[9] +
        `s0(W[1]) +
        W[0]
    );
    reg [31:0] Wnext;
    always @(*) begin
        if(iteration == I_DOUBLE) begin
            if (i < 8)
                Wnext = int_hash[(255 - i*32) -: 32];
            else if (i == 8)
                Wnext = 32'h80000000;
            else if (i == 15)
                Wnext = 32'h00000100;
            else
                Wnext = 32'h00000000;
        end else if(iteration == I_BLOCK1) begin
                Wnext = block[(639 - i*32) -: 32];
        end else if(iteration == I_BLOCK2) begin
            if (i < 4)
                Wnext = block[(127 - i*32) -: 32];
            else if (i == 4)
                Wnext = 32'h80000000;
            else if (i == 15)
                Wnext = 32'h00000280;
            else
                Wnext = 32'h00000000;
        end else
            Wnext = 32'h00000000;
    end
    reg [255:0] int_hash;
    // State machine
    localparam S_IDLE=0, S_INIT=1, S_COMPUTE=2;
    localparam S_OUT=3, S_NEXT=4;
    reg [4:0] state;
    // To track iteration for 640-bit double-SHA
    localparam I_BLOCK1=0, I_BLOCK2=1, I_DOUBLE=2;
    reg [1:0] iteration;

    assign done = (state == S_IDLE && iteration == I_DOUBLE);
    assign hash = {H0, H1, H2, H3, H4, H5, H6, H7};

    // Round counter
    reg [5:0] i;

    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            // State machine
            state <= S_IDLE;
        end else begin
            if(state == S_IDLE) begin
                iteration <= I_BLOCK1;
                i <= 6'b0;
                int_hash <= 256'b0;

                // Working variables
                H0 <= CH0;
                H1 <= CH1;
                H2 <= CH2;
                H3 <= CH3;
                H4 <= CH4;
                H5 <= CH5;
                H6 <= CH6;
                H7 <= CH7;
                if(start) state <= S_INIT;
            end else if(state == S_INIT) begin
                if(i == 0) begin
                    a <= H0;
                    b <= H1;
                    c <= H2;
                    d <= H3;
                    e <= H4;
                    f <= H5;
                    g <= H6;
                    h <= H7;
                end
                if(i < 16) begin
                    W[i[3:0]] <= Wnext;
                    i <= i + 1;
                end else begin
                    i <= 0;
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
                    W[0] <= W[1];
                    W[1] <= W[2];
                    W[2] <= W[3];
                    W[3] <= W[4];
                    W[4] <= W[5];
                    W[5] <= W[6];
                    W[6] <= W[7];
                    W[7] <= W[8];
                    W[8] <= W[9];
                    W[9] <= W[10];
                    W[10] <= W[11];
                    W[11] <= W[12];
                    W[12] <= W[13];
                    W[13] <= W[14];
                    W[14] <= W[15];
                    W[15] <= Wt;
                end

                if(i == 63) state <= S_OUT;
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
                state <= S_NEXT;
            end else if(state == S_NEXT) begin
                if(iteration == I_BLOCK1) begin // Finished first block
                    i <= 0;
                    iteration <= I_BLOCK2;
                    state <= S_INIT;
                end else if(iteration == I_BLOCK2) begin // Finished second block
                    int_hash <= {H0, H1, H2, H3, H4, H5, H6, H7};
                    // Reset SHA256 state and start new hash
                    H0 <= CH0;
                    H1 <= CH1;
                    H2 <= CH2;
                    H3 <= CH3;
                    H4 <= CH4;
                    H5 <= CH5;
                    H6 <= CH6;
                    H7 <= CH7;
                    i <= 0;
                    state <= S_INIT;
                    iteration <= I_DOUBLE;
                end else if(iteration == I_DOUBLE) begin
                    state <= S_IDLE;
                end
            end
        end
    end
endmodule