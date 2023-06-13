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

module main(
    output wire DIN, CS, CLK,
    input wire CLK_IN, RST
);

    reg [28:0] clk;
    reg [7:0] dot;
    reg [3:0] data [0:7];

    MAX7219 max(DIN, CS, CLK, { data[7], data[6], data[5], data[4], data[3], data[2], data[1], data[0] }, dot, CLK_IN, RST);

    always @ (posedge CLK_IN, negedge RST)
        if (!RST)
            clk <= 0;
        else
            clk <= clk + 1;

    always @ (posedge clk[24], negedge RST)
        if (!RST)
            dot <= 1;
        else
            dot <= { dot[0], dot[7:1] };

    genvar i;
    for (i = 0; i < 8; i = i + 1) begin
        always @ (posedge clk[i + 21], negedge RST)
            if (!RST)
                data[i] <= 0;
            else
                data[i] <= data[i] + 1;
    end

endmodule
