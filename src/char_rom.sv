//==========================================================================
// char_rom.sv  -  tiny 8x8 bitmap font for card rendering.
// Glyph codes:  0-9 = digits, 10=A, 11=J, 12=Q, 13=K, 14='?', 15=blank.
// `bits` is one 8-pixel row (MSB = leftmost pixel).
//==========================================================================
module char_rom (
    input  logic [3:0] code,
    input  logic [2:0] row,
    output logic [7:0] bits
);
    logic [7:0] font [0:15][0:7];

    initial begin
        font[0]  = '{8'h7C,8'hC6,8'hCE,8'hDE,8'hF6,8'hE6,8'h7C,8'h00}; // 0
        font[1]  = '{8'h30,8'h70,8'h30,8'h30,8'h30,8'h30,8'hFC,8'h00}; // 1
        font[2]  = '{8'h7C,8'hC6,8'h06,8'h1C,8'h70,8'hC0,8'hFE,8'h00}; // 2
        font[3]  = '{8'h7C,8'hC6,8'h06,8'h3C,8'h06,8'hC6,8'h7C,8'h00}; // 3
        font[4]  = '{8'h1C,8'h3C,8'h6C,8'hCC,8'hFE,8'h0C,8'h0C,8'h00}; // 4
        font[5]  = '{8'hFE,8'hC0,8'hFC,8'h06,8'h06,8'hC6,8'h7C,8'h00}; // 5
        font[6]  = '{8'h3C,8'h60,8'hC0,8'hFC,8'hC6,8'hC6,8'h7C,8'h00}; // 6
        font[7]  = '{8'hFE,8'h06,8'h0C,8'h18,8'h30,8'h30,8'h30,8'h00}; // 7
        font[8]  = '{8'h7C,8'hC6,8'hC6,8'h7C,8'hC6,8'hC6,8'h7C,8'h00}; // 8
        font[9]  = '{8'h7C,8'hC6,8'hC6,8'h7E,8'h06,8'h0C,8'h78,8'h00}; // 9
        font[10] = '{8'h38,8'h6C,8'hC6,8'hC6,8'hFE,8'hC6,8'hC6,8'h00}; // A
        font[11] = '{8'h1E,8'h06,8'h06,8'h06,8'hC6,8'hC6,8'h7C,8'h00}; // J
        font[12] = '{8'h7C,8'hC6,8'hC6,8'hC6,8'hDE,8'hCC,8'h76,8'h00}; // Q
        font[13] = '{8'hC6,8'hCC,8'hD8,8'hF0,8'hD8,8'hCC,8'hC6,8'h00}; // K
        font[14] = '{8'h7C,8'hC6,8'h0C,8'h18,8'h18,8'h00,8'h18,8'h00}; // ?
        font[15] = '{8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00}; // blank
    end

    assign bits = font[code][row];
endmodule
