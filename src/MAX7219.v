`timescale 1ns / 1ps

/*
  MAX7219, 8-Digit LED Display Driver for FPGA
  Copyright (C) 2023 Cidorvan Leite

  This program is free software: you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation, either version 3 of the License, or
  (at your option) any later version.

  This program is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with this program.  If not, see [http://www.gnu.org/licenses/].
*/

module MAX7219 #(parameter CLK_DIV = 5, INTENSITY = 1, SCAN_LIMIT = 7) (
    output wire DIN, CS, CLK,
    input wire [31:0] DATA,
    input wire [7:0] DOT,
    input wire CLK_IN, RST
//    , output wire [3:0] index
//    , output wire [6:0] demux
//    , output wire [15:0] cmd
);

    wire clk;
    MAX7219_CLOCK #(CLK_DIV) clock (clk, CLK_IN);

    wire [3:0] cnt;
    MAX7219_COUNT count(CS, cnt, clk, RST);

    wire dot;
    MAX7219_DOT_MUX dmx(dot, DOT, index[2:0]);

    wire [3:0] mux, index;
    MAX7219_NUMBER_MUX nmx(mux, DATA, index[2:0]);

    wire [6:0] demux;
    MAX7219_NUMBER_DEMUX ndmx(demux, mux);

    wire [15:0] cmd;
    MAX7219_UPDATE_COMMAND command(cmd, index, demux, dot, INTENSITY, SCAN_LIMIT, CS, RST);

    MAX7219_OUTPUT out(DIN, CLK, cmd, cnt, clk, CS);

endmodule


// Clock divider by 2^N
module MAX7219_CLOCK #(parameter N = 5) (
    output wire OUT,
    input wire IN
);

    reg [N - 1:0] count = 0;

    assign OUT = count[N - 1];

    always @ (posedge IN)
        count <= count + 1;

endmodule


module MAX7219_COUNT(
    output reg CS,
    output reg [3:0] COUNT,
    input wire CLK, RST
);

    always @ (negedge CLK, negedge RST)
        if (!RST) begin
            CS <= 1;
            COUNT <= 4'b1111;
        end else begin
            COUNT = COUNT - 1;
            if (COUNT == 4'b1111)
                CS <= ~CS;
        end

endmodule


module MAX7219_DOT_MUX(
    output wire OUT,
    input wire [7:0] IN,
    input wire [2:0] INDEX
);

    assign OUT =
        INDEX == 3'd1 ? IN[0] :
        INDEX == 3'd2 ? IN[1] :
        INDEX == 3'd3 ? IN[2] :
        INDEX == 3'd4 ? IN[3] :
        INDEX == 3'd5 ? IN[4] :
        INDEX == 3'd6 ? IN[5] :
        INDEX == 3'd7 ? IN[6] :
                        IN[7];

endmodule


module MAX7219_NUMBER_MUX(
    output wire [3:0] OUT,
    input wire [31:0] IN,
    input wire [2:0] INDEX
);

    assign OUT =
        INDEX == 3'd1 ? IN[3:0]   :
        INDEX == 3'd2 ? IN[7:4]   :
        INDEX == 3'd3 ? IN[11:8]  :
        INDEX == 3'd4 ? IN[15:12] :
        INDEX == 3'd5 ? IN[19:16] :
        INDEX == 3'd6 ? IN[23:20] :
        INDEX == 3'd7 ? IN[27:24] :
                        IN[31:28];

endmodule


// Convert current digit to 7 segment format
module MAX7219_NUMBER_DEMUX(
    output wire [6:0] OUT,
    input wire [3:0] IN
);

    assign OUT =
        IN == 4'd0  ? 8'h7E :
        IN == 4'd1  ? 8'h30 :
        IN == 4'd2  ? 8'h6D :
        IN == 4'd3  ? 8'h79 :
        IN == 4'd4  ? 8'h33 :
        IN == 4'd5  ? 8'h5B :
        IN == 4'd6  ? 8'h5F :
        IN == 4'd7  ? 8'h70 :
        IN == 4'd8  ? 8'h7F :
        IN == 4'd9  ? 8'h7B :
        IN == 4'd10 ? 8'h77 :
        IN == 4'd11 ? 8'h1F :
        IN == 4'd12 ? 8'h4E :
        IN == 4'd13 ? 8'h3D :
        IN == 4'd14 ? 8'h4F :
                      8'h47;

endmodule


module MAX7219_UPDATE_COMMAND(
    output reg [15:0] CMD,
    output reg [3:0] INDEX,
    input wire [6:0] DIGIT,
    input wire DOT,
    input wire [3:0] INTENSITY,
    input wire [2:0] SCAN_LIMIT,
    input wire CS, RST
);

    always @ (negedge CS, negedge RST)
        if (!RST) begin
            CMD <= 0;
            INDEX <= 4'd9;
        end else begin
            INDEX <= INDEX + 1;
            if (INDEX == 4'd8)
                INDEX <= 4'd1;
            CMD <= { 4'b0000, INDEX, 8'b00000000 };
            case (INDEX)
                1, 2, 3, 4, 5, 6, 7, 8:                   // Digits from 0 to 7
                    CMD[7:0] <= { DOT, DIGIT };
//                9:  CMD[6:0] <= 7'b0000000;             // Decode mode (always disable)
                10: CMD[3:0] <= INTENSITY;                // Intensity
                11: CMD[2:0] <= SCAN_LIMIT;               // Scan limit
                12: CMD[0]   <= 1;                        // Shutdown (normal operation)
//                15: CMD[0]   <= 1'b0;                   // Display test (normal operation)
            endcase
        end

endmodule


module MAX7219_OUTPUT(
    output wire DIN, CLK,
    input wire [15:0] CMD,
    input wire [3:0] CNT,
    input wire CLK_IN, CS
);

    assign DIN = !CS & CMD[CNT];
    assign CLK = !CS & CLK_IN;

endmodule


module MAX7219_tb();
    wire din, cs, clk_out;
    reg [31:0] data;
    reg [7:0] dot;
    reg clk = 0, rst;
//    wire [3:0] index;
//    wire [6:0] demux;
//    wire [15:0] cmd;

    MAX7219 #(1) max(din, cs, clk_out, data, dot, clk, rst); //, index, demux, cmd);

    always #1 clk = ~clk;

    initial begin
//        $monitor("CS:%b CLK:%b DIN:%b  IDX:%d DMX:%X CMD:%b CLK_IN:%b", cs, clk_out, din, index, demux, cmd, clk);
        $monitor("CS:%b CLK:%b DIN:%b CLK_IN:%b", cs, clk_out, din, clk);

        data = 32'h1A2B3C4D; dot = 8'h55; rst = 0; #10; rst = 1; #10

        #4000

        $finish();
    end

endmodule
