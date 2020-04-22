module main_tb;
   reg clk, rst_n;
   reg [2:0] sig, sig_in;
   wire [2:0] lo_out, mix_out;
   wire TXD;
   reg RXD;
   wire [1:0] led;

   FSd1 i0(clk, rst_n, sig, lo_out, mix_out, sig_in, TXD, RXD, led);

   initial begin
      clk <= 0; rst_n <= 0; sig <= 0; RXD <= 1;
      #20 rst_n <= 1;
   end

   always #10 clk <= ~clk;
//   always #250 sig <= ~sig;

   initial begin
      $dumpfile("restult.vcd");
      $dumpvars(0, i0); // dump all the hierarchical instances' variables
   end

   initial begin
      #200000 $finish();
   end
endmodule

