module main_tb;
    reg clk, rst_n;
    reg [2:0] sig;
    wire [2:0] lo_out, mix_out;
    wire TXD;
    reg RXD;

    FSd1 i0(clk, rst_n, sig, lo_out, mix_out, TXD, RXD);
    initial begin
        clk <= 0; rst_n <= 0; sig <= 0; RXD <= 1;
        #20 rst_n <= 1;
    end

    always #10 clk <= ~clk;
    always #250 sig <= ~sig;

   initial begin
      $dumpfile("restult.vcd");
      $dumpvars(0, i0); // dump all the hierarchical instances' variables
   end

   initial begin
      #100000 $finish();
   end
endmodule

