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
    output reg [255:0] hash,
    output reg done
);
    /* Run logic */
    reg run;
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            run <= 1'b0;
        end else begin
            if(start) run <= 1'b1;
            else if(done) run <= 1'b0;
        end
    end

    `define rotr(x, n) (((x) >> (n)) | ((x) << (32 - (n))))
    wire [31:0] ch_e = (e & f) ^ (~e & g);
    wire [31:0] maj_a = (a & b) ^ (a & c) ^ (b & c);

    wire [31:0] S0_a = {a[1:0],a[31:2]} ^ {a[12:0],a[31:13]} ^ {a[21:0],a[31:22]};
    wire [31:0] S1_e = {e[5:0],e[31:6]} ^ {e[10:0],e[31:11]} ^ {e[24:0],e[31:25]};
    `define s0(x) (`rotr((x), 7) ^ `rotr((x), 18) ^ ((x) >> 3))
    `define s1(x) (`rotr((x), 17) ^ `rotr((x), 19) ^ ((x) >> 10))
    
    /* ----- Size and Endianness Correction ----- */
    wire [1023:0] data = {
        block[639:0],
        8'h80,
        376'h0280
    };

    /* ----- SHA256 Calculation ----- */
    reg [31:0] a, b, c, d, e, f, g, h;
    reg [31:0] H0, H1, H2, H3, H4, H5, H6, H7;
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
    reg [255:0] int_hash;
    wire [511:0] int_data = {
        int_hash,
        8'h80,
        248'h0100
    };
    // State machine
    localparam S_SCHEDULE=0, S_INIT=1, S_COMPUTE=2;
    localparam S_OUT=3, S_NEXT=4, S_DONE=5;
    reg [4:0] state;
    // To track iteration for 640-bit double-SHA
    localparam I_BLOCK1=0, I_BLOCK2=1, I_DOUBLE=2, I_DONE=3;
    reg [1:0] iteration;

    // Round counter
    reg [5:0] i;

    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            // State variables
            state <= S_SCHEDULE;
            iteration <= I_BLOCK1;
            i <= 6'b0;
            int_hash <= 256'b0;
            done <= 0;

            // Working variables
            H0 <= CH0;
            H1 <= CH1;
            H2 <= CH2;
            H3 <= CH3;
            H4 <= CH4;
            H5 <= CH5;
            H6 <= CH6;
            H7 <= CH7;
        end else begin
            if(run) begin
                if(state == S_SCHEDULE) begin
                    if(i < 16) begin
                        if(iteration == I_DOUBLE) begin
                            W[i[3:0]] <= int_data[(511 - i*32) -: 32];
                        end else begin
                            W[i[3:0]] <= data[(1023 - iteration*512 - i*32) -: 32];
                        end
                        i <= i + 1;
                    end else begin
                        i <= 0;
                        state <= S_INIT;
                    end
                end else if(state == S_INIT) begin
                    a <= H0;
                    b <= H1;
                    c <= H2;
                    d <= H3;
                    e <= H4;
                    f <= H5;
                    g <= H6;
                    h <= H7;
                    state <= S_COMPUTE;
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
                        state <= S_SCHEDULE;
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
                        state <= S_SCHEDULE;
                        iteration <= I_DOUBLE;
                    end else if(iteration == I_DOUBLE) begin
                        hash <= {H0, H1, H2, H3, H4, H5, H6, H7};
                        done <= 1;
                        iteration <= I_DONE;
                        state <= S_DONE;
                    end
                end
            end
        end
    end
endmodule