module bin2bcd_tb;
    reg clk, rst;
    reg in;
    wire [31:0] out;

    //  8bit <-> 0-255      = 3digit,  8 clocks
    // 16bit <-> 0-65535    = 5digit, 16 clocks
    // 24bit <-> 0-16777215 = 8digit, 24 clocks
    bin2bcd #(.Ndigit(8)) i0(clk, rst, in, out);
    always #5 clk = ~clk;

    initial begin
        $dumpfile("restult.vcd");
        $dumpvars(0, i0); // dump all the hierarchical instances' variables
    end

    initial begin
        clk <= 0; rst <= 1;
        #10 rst <= 0;
    end

    initial begin
        #10 in <= 1;
        #10 in <= 1;
        #10 in <= 1;
        #10 in <= 1;
        #10 in <= 1;
        #10 in <= 1;
        #10 in <= 1;
        #10 in <= 0;
        #10 in <= 1;
        #10 in <= 0;
        #10 in <= 1;
        #10 in <= 0;
    end
    initial begin
        #300 $finish();
    end

endmodule
