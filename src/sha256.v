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

    reg [31:0] K [0:63];

    localparam [2047:0] INIT_K = {
        32'h428a2f98, 32'h71374491, 32'hb5c0fbcf, 32'he9b5dba5, 32'h3956c25b, 32'h59f111f1, 32'h923f82a4, 32'hab1c5ed5,
        32'hd807aa98, 32'h12835b01, 32'h243185be, 32'h550c7dc3, 32'h72be5d74, 32'h80deb1fe, 32'h9bdc06a7, 32'hc19bf174,
        32'he49b69c1, 32'hefbe4786, 32'h0fc19dc6, 32'h240ca1cc, 32'h2de92c6f, 32'h4a7484aa, 32'h5cb0a9dc, 32'h76f988da,
        32'h983e5152, 32'ha831c66d, 32'hb00327c8, 32'hbf597fc7, 32'hc6e00bf3, 32'hd5a79147, 32'h06ca6351, 32'h14292967,
        32'h27b70a85, 32'h2e1b2138, 32'h4d2c6dfc, 32'h53380d13, 32'h650a7354, 32'h766a0abb, 32'h81c2c92e, 32'h92722c85,
        32'ha2bfe8a1, 32'ha81a664b, 32'hc24b8b70, 32'hc76c51a3, 32'hd192e819, 32'hd6990624, 32'hf40e3585, 32'h106aa070,
        32'h19a4c116, 32'h1e376c08, 32'h2748774c, 32'h34b0bcb5, 32'h391c0cb3, 32'h4ed8aa4a, 32'h5b9cca4f, 32'h682e6ff3,
        32'h748f82ee, 32'h78a5636f, 32'h84c87814, 32'h8cc70208, 32'h90befffa, 32'ha4506ceb, 32'hbef9a3f7, 32'hc67178f2
    };

    integer k;
    initial begin
        for (k = 0; k < 64; k = k + 1)
            K[k] = INIT_K[(63 - k) * 32 +: 32];
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
                        K[i] + Wt;
    wire [31:0] t2 = S0_a + maj_a;
    reg [31:0] W [0:15];
    wire [31:0] Wt = (i > 15 ?
        `s1(W[14]) +
        W[9] +
        `s0(W[1]) +
        W[0]
        : W[i]
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
            H0 <= 32'h6a09e667;
            H1 <= 32'hbb67ae85;
            H2 <= 32'h3c6ef372;
            H3 <= 32'ha54ff53a;
            H4 <= 32'h510e527f;
            H5 <= 32'h9b05688c;
            H6 <= 32'h1f83d9ab;
            H7 <= 32'h5be0cd19;
            a <= 0; b <= 0; c <= 0; d <= 0;
            e <= 0; f <= 0; g <= 0; h <= 0;
            W[0] <= 32'b0;
            W[1] <= 32'b0;
            W[2] <= 32'b0;
            W[3] <= 32'b0;
            W[4] <= 32'b0;
            W[5] <= 32'b0;
            W[6] <= 32'b0;
            W[7] <= 32'b0;
            W[8] <= 32'b0;
            W[9] <= 32'b0;
            W[10] <= 32'b0;
            W[11] <= 32'b0;
            W[12] <= 32'b0;
            W[13] <= 32'b0;
            W[14] <= 32'b0;
            W[15] <= 32'b0;
        end else begin
            if(run) begin
                if(state == S_SCHEDULE) begin
                    if(i < 16) begin
                        if(iteration == I_DOUBLE) begin
                            W[i] <= int_data[(511 - i*32) -: 32];
                        end else begin
                            W[i] <= data[(1023 - iteration*512 - i*32) -: 32];
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
                        H0 <= 32'h6a09e667;
                        H1 <= 32'hbb67ae85;
                        H2 <= 32'h3c6ef372;
                        H3 <= 32'ha54ff53a;
                        H4 <= 32'h510e527f;
                        H5 <= 32'h9b05688c;
                        H6 <= 32'h1f83d9ab;
                        H7 <= 32'h5be0cd19;
                        a <= 0; b <= 0; c <= 0; d <= 0;
                        e <= 0; f <= 0; g <= 0; h <= 0;
                        i <= 0;
                        state <= S_SCHEDULE;
                        iteration <= I_DOUBLE;
                    end else if(iteration == I_DOUBLE) begin
                        hash <= {H0, H1, H2, H3, H4, H5, H6, H7};
                        done <= 1;
                        iteration <= I_DONE;
                    end
                end
            end
        end
    end
endmodule