// http://jjmk.dk/MMMI/Lessons/06_Arithmetics/No6_Conversion/Index.htm
module bin2bcd_unit(clk, rst, ModIn, ModOut, Q);
    input clk, rst, ModIn;
    output ModOut;
    output [3:0] Q;
    reg [3:0] bcd;
    assign Q = bcd;
    assign ModOut = (bcd >= 5)?(1'b1):(1'b0);
    always @(posedge clk) begin
        if (rst == 1'b1) bcd <= 4'b0000;
        else begin
            case (bcd) 
                4'b0000 : begin bcd <= {3'b000, ModIn}; end
                4'b0001 : begin bcd <= {3'b001, ModIn}; end
                4'b0010 : begin bcd <= {3'b010, ModIn}; end
                4'b0011 : begin bcd <= {3'b011, ModIn}; end
                4'b0100 : begin bcd <= {3'b100, ModIn}; end
                4'b0101 : begin bcd <= {3'b000, ModIn}; end
                4'b0110 : begin bcd <= {3'b001, ModIn}; end
                4'b0111 : begin bcd <= {3'b010, ModIn}; end
                4'b1000 : begin bcd <= {3'b011, ModIn}; end
                4'b1001 : begin bcd <= {3'b100, ModIn}; end
                default : begin bcd <= 4'b0000; end
            endcase
        end
    end
endmodule

module bin2bcd #(parameter Ndigit = 2)(clk, rst, in, out);
    input clk, rst;
    input in;
    output [Ndigit*4 - 1:0] out;
    wire [Ndigit:0] m;
    assign m[0] = in;
    generate
        genvar i;
        for (i = 0; i < Ndigit; i = i + 1) begin
            bin2bcd_unit d(clk, rst, m[i], m[i+1], out[i*4+3:i*4]);
        end
    endgenerate
endmodule
