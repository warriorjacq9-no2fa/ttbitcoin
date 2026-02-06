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
        end
    end

    localparam [2047:0] K = {
        32'h428a2f98, 32'h71374491, 32'hb5c0fbcf, 32'he9b5dba5, 32'h3956c25b, 32'h59f111f1, 32'h923f82a4, 32'hab1c5ed5,
        32'hd807aa98, 32'h12835b01, 32'h243185be, 32'h550c7dc3, 32'h72be5d74, 32'h80deb1fe, 32'h9bdc06a7, 32'hc19bf174,
        32'he49b69c1, 32'hefbe4786, 32'h0fc19dc6, 32'h240ca1cc, 32'h2de92c6f, 32'h4a7484aa, 32'h5cb0a9dc, 32'h76f988da,
        32'h983e5152, 32'ha831c66d, 32'hb00327c8, 32'hbf597fc7, 32'hc6e00bf3, 32'hd5a79147, 32'h06ca6351, 32'h14292967,
        32'h27b70a85, 32'h2e1b2138, 32'h4d2c6dfc, 32'h53380d13, 32'h650a7354, 32'h766a0abb, 32'h81c2c92e, 32'h92722c85,
        32'ha2bfe8a1, 32'ha81a664b, 32'hc24b8b70, 32'hc76c51a3, 32'hd192e819, 32'hd6990624, 32'hf40e3585, 32'h106aa070,
        32'h19a4c116, 32'h1e376c08, 32'h2748774c, 32'h34b0bcb5, 32'h391c0cb3, 32'h4ed8aa4a, 32'h5b9cca4f, 32'h682e6ff3,
        32'h748f82ee, 32'h78a5636f, 32'h84c87814, 32'h8cc70208, 32'h90befffa, 32'ha4506ceb, 32'hbef9a3f7, 32'hc67178f2
    };
    `define rotr(x, n) (((x) >> (n)) | ((x) << (32 - (n))))
    wire [31:0] ch_e = (e & f) ^ (~e & g);
    wire [31:0] maj_a = (a & b) ^ (a & c) ^ (b & c);

    wire [31:0] S0_a = {a[1:0],a[31:2]} ^ {a[12:0],a[31:13]} ^ {a[21:0],a[31:22]};
    wire [31:0] S1_e = {e[5:0],e[31:6]} ^ {e[10:0],e[31:11]} ^ {e[24:0],e[31:25]};
    `define s0(x) (`rotr((x), 7) ^ `rotr((x), 18) ^ ((x) >> 3))
    `define s1(x) (`rotr((x), 17) ^ `rotr((x), 19) ^ ((x) >> 10))

    `define K_at(idx) (K[(63 - (idx)) * 32 +: 32])
    `define W_at(idx) (W[(63 - (idx)) * 32 +: 32])
    
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
                        `K_at(i[5:0]) + 
                        `W_at(i[5:0]);
    wire [31:0] t2 = S0_a + maj_a;
    reg [2047:0] W;
    reg [255:0] int_hash;
    wire [511:0] int_data = {
        int_hash,
        8'h80,
        248'h0100
    };
    // Hash state machine
    reg [7:0] i;
    // High-level state machine
    reg [1:0] j;

    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
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
            i <= 8'b0;
            j <= 2'b0;
            W <= 2048'b0;
            int_hash <= 256'b0;
            done <= 0;
        end else begin
            if(run) begin
                if((i[7:6] == 0)) begin
                    if(i[5:0] < 16) begin
                        if(j > 1) begin
                            W[(63 - i[5:0]) * 32 +: 32] <= int_data[(511 - i*32) -: 32];
                        end else begin
                            W[(63 - i[5:0]) * 32 +: 32] <= data[(1023 - j*512 - i*32) -: 32];
                        end
                    end else begin
                        W[(63 - i[5:0]) * 32 +: 32] <=
                            `s1(`W_at(i[5:0]-2)) +
                            `W_at(i[5:0]-7) +
                            `s0(`W_at(i[5:0]-15)) +
                            `W_at(i[5:0]-16);
                    end
                    i <= i + 1;
                end else if(i[7:6] == 1) begin
                    a <= H0;
                    b <= H1;
                    c <= H2;
                    d <= H3;
                    e <= H4;
                    f <= H5;
                    g <= H6;
                    h <= H7;
                    i <= 8'h80;
                end else if(i[7:6] == 2) begin
                    h <= g;
                    g <= f;
                    f <= e;
                    e <= d + t1;
                    d <= c;
                    c <= b;
                    b <= a;
                    a <= t1 + t2;
                    i <= i + 1;
                end else if(i == 8'b11000000) begin
                    H0 <= a + H0;
                    H1 <= b + H1;
                    H2 <= c + H2;
                    H3 <= d + H3;
                    H4 <= e + H4;
                    H5 <= f + H5;
                    H6 <= g + H6;
                    H7 <= h + H7;
                    i <= i + 1;
                end else begin
                    if(j == 0) begin // Finished first block
                        j <= j + 1;
                        i <= 8'b0;
                    end else if(j == 1) begin // Finished second block
                        int_hash <= {H0, H1, H2, H3, H4, H5, H6, H7};
                        j <= j + 1;
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
                    end else if(j == 2) begin
                        hash <= {H0, H1, H2, H3, H4, H5, H6, H7};
                        done <= 1;
                        j <= j + 1;
                    end
                end
            end
        end
    end
endmodule