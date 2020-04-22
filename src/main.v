module FSd1 (clk24M, rst_n, mix_in, lo_out, mix_out, sig_in, TXD, RXD, led);
    input clk24M, rst_n;
    input [2:0] mix_in;
    input [2:0] sig_in;
    output[2:0] lo_out, mix_out;
    input RXD;
    output TXD;
    output [1:0] led;

//    reg [15:0] lo_cnt[0:2];
//    reg [15:0] lo_cycle[0:2];
    reg [11:0] lo_cnt[0:2];
    reg [11:0] lo_cycle[0:2];
    reg [2:0] r_lo;
//    reg [15:0] raw_cnt[0:2], raw_cnt_work[0:2];
    reg [11:0] raw_cnt[0:2], raw_cnt_work[0:2];
    reg [23:0] sig_cnt[0:2], sig_cnt_work[0:2];
    reg mix_in_p[0:2], sig_in_p[0:2];
    wire rst = ~rst_n;
    wire tx_busy, rx_ready;
    reg tx_start;
    wire [7:0] tx_data, rx_data;
    reg [7:0] tx_state;
    reg [4:0] data_b;
    reg [7:0] data_h;
    reg [1:0] rx_f_receiving;
    reg [5:0] rx_byte;
//    reg [15:0] r_lo_cycle;
    reg [11:0] r_lo_cycle;
    reg [3:0] rx_data_b;
    reg f_send;
    reg [1:0] r_lo_channel;
    wire w_txd;
    reg f_tx_data_ready;
    reg [5:0] bcd_conversion_count;
    wire [31:0] bcd_out;
    reg [31:0] bcd_out_reg;
    reg bcd_in;
    reg f_bcd_data_ready, f_bcd_converting;
    reg [2:0] bcd_state;
    reg [23:0] bcd_in_data;
    wire bcd_rst;
    reg f_send_frame;

    RX8 irx8(clk24M, rst, RXD, rx_data, rx_ready);
    TX8 itx8(clk24M, rst, tx_data, w_txd, tx_start, tx_busy);
//    assign TXD = RXD;
    assign TXD = (f_send_frame == 1)?(w_txd):(1'b1);

    bin2bcd #(.Ndigit(8)) i0(clk24M, bcd_rst, bcd_in, bcd_out); // 24bit < 10^8
    assign bcd_rst = (f_bcd_converting == 1)?(0):(1);

    integer i;
    always @(posedge clk24M) begin
        for (i = 0; i < 3; i = i + 1) begin
            if (rst == 1'b1) begin
                lo_cnt[i] <= 0; lo_cycle[i] <= 100;
                raw_cnt[i] <= 0; raw_cnt_work[i] <= 0; mix_in_p[i] <= mix_in[i];
                sig_cnt[i] <= 0; sig_cnt_work[i] <= 0; sig_in_p[i] <= sig_in[i];
                r_lo[i] <= 1'b0;
            end
            else begin
                // Local Oscillator
                lo_cnt[i] <= lo_cnt[i] + 1;
                if (lo_cnt[i] == lo_cycle[i] - 1) begin // lo: 24MHz/(lo_cycle[0])
                    r_lo[i] <= 1'b1; lo_cnt[i] <= 0;
                end
                else if (lo_cnt[i] == lo_cycle[i]/2 - 1) r_lo[i] <= 1'b0;

                // Raw Wave Counter
                if (mix_in_p[i] == 0 && mix_in[i] == 1) begin
                    raw_cnt[i] <= raw_cnt_work[i];
                    raw_cnt_work[i] <= 0;
                end
                else raw_cnt_work[i] <= raw_cnt_work[i] + 1;
                mix_in_p[i] <= mix_in[i];

                // Signal Wave Counter
                if (sig_in_p[i] == 0 && sig_in[i] == 1) begin
                    sig_cnt[i] <= sig_cnt_work[i];
                    sig_cnt_work[i] <= 0;
                end
                else sig_cnt_work[i] <= sig_cnt_work[i] + 1;
                sig_in_p[i] <= sig_in[i];
            end
        end

        if (rst == 1'b1) begin
            tx_start <= 0; tx_state <= 0; data_b <= 0;
            rx_f_receiving <= 0; rx_byte <= 0;
//            f_send <= 1; f_send_frame <= 1; // for debug
            f_send <= 0; f_send_frame <= 0;
            f_tx_data_ready <= 0; bcd_conversion_count <= 0;
            f_bcd_data_ready <= 0; bcd_state <= 0;
            bcd_in_data <= 0; f_bcd_converting <= 0;
            bcd_out_reg <= 0; bcd_in <= 0;
/*            
            // for simulation
            raw_cnt[0] <= 4000;
            raw_cnt[1] <= 3789;
            raw_cnt[2] <= 2468;
            sig_cnt[0] <= 123456;
            sig_cnt[1] <= 67890;
            sig_cnt[2] <= 13579013;
*/        
        end

        if (f_bcd_data_ready == 0 && f_bcd_converting == 0) begin
            f_bcd_converting <= 1;
            case (bcd_state)
                0  : bcd_in_data <= {12'h000, raw_cnt[0]};
                1  : bcd_in_data <= {12'h000, raw_cnt[1]};
                2  : bcd_in_data <= {12'h000, raw_cnt[2]};
                3  : bcd_in_data <= sig_cnt[0];
                4  : bcd_in_data <= sig_cnt[1];
                5  : bcd_in_data <= sig_cnt[2];
                default: bcd_in_data <= 0;
            endcase
        end
        else if (f_bcd_converting == 1) begin
            if (bcd_conversion_count <= 23) bcd_in <= bcd_in_data[23 - bcd_conversion_count];
            else bcd_in <= 0;
            if (bcd_conversion_count == 25) begin
                bcd_out_reg <= bcd_out;
                bcd_conversion_count <= 0;
                f_bcd_converting <= 0;
                f_bcd_data_ready <= 1; 

                if (bcd_state == 5) bcd_state <= 0;
                else bcd_state <= bcd_state + 1;
            end
            else bcd_conversion_count <= bcd_conversion_count + 1;
        end

        if (tx_busy == 0 && tx_start == 0 && f_bcd_data_ready == 1) begin
            case (tx_state) 
                // raw_cnt[0]
                0  : data_b <= bcd_out_reg[15:12];
                1  : data_b <= bcd_out_reg[11: 8];
                2  : data_b <= bcd_out_reg[ 7: 4];
                3  : begin data_b <= bcd_out_reg[ 3: 0]; f_bcd_data_ready <= 0; end
                4  : data_b <= 5'h12;
                // raw_cnt[1]
                5  : data_b <= bcd_out_reg[15:12];
                6  : data_b <= bcd_out_reg[11: 8];
                7  : data_b <= bcd_out_reg[ 7: 4];
                8  : begin data_b <= bcd_out_reg[ 3: 0]; f_bcd_data_ready <= 0; end
                9  : data_b <= 5'h12;
                // raw_cnt[2]
                10 : data_b <= bcd_out_reg[15:12];
                11 : data_b <= bcd_out_reg[11: 8];
                12 : data_b <= bcd_out_reg[ 7: 4];
                13 : begin data_b <= bcd_out_reg[ 3: 0]; f_bcd_data_ready <= 0; end
                14 : data_b <= 5'h12;
                // sig_cnt[0]
                15 : data_b <= bcd_out_reg[31:28];
                16 : data_b <= bcd_out_reg[27:24];
                17 : data_b <= bcd_out_reg[23:20];
                18 : data_b <= bcd_out_reg[19:16];
                19 : data_b <= bcd_out_reg[15:12];
                20 : data_b <= bcd_out_reg[11: 8];
                21 : data_b <= bcd_out_reg[ 7: 4];
                22 : begin data_b <= bcd_out_reg[ 3: 0]; f_bcd_data_ready <= 0; end
                23 : data_b <= 5'h12;
                // sig_cnt[1]
                24 : data_b <= bcd_out_reg[31:28];
                25 : data_b <= bcd_out_reg[27:24];
                26 : data_b <= bcd_out_reg[23:20];
                27 : data_b <= bcd_out_reg[19:16];
                28 : data_b <= bcd_out_reg[15:12];
                29 : data_b <= bcd_out_reg[11: 8];
                30 : data_b <= bcd_out_reg[ 7: 4];
                31 : begin data_b <= bcd_out_reg[ 3: 0]; f_bcd_data_ready <= 0; end
                32 : data_b <= 5'h12;
                // sig_cnt[2]
                33 : data_b <= bcd_out_reg[31:28];
                34 : data_b <= bcd_out_reg[27:24];
                35 : data_b <= bcd_out_reg[23:20];
                36 : data_b <= bcd_out_reg[19:16];
                37 : data_b <= bcd_out_reg[15:12];
                38 : data_b <= bcd_out_reg[11: 8];
                39 : data_b <= bcd_out_reg[ 7: 4];
                40 : begin data_b <= bcd_out_reg[ 3: 0]; f_bcd_data_ready <= 0; end
                41 : data_b <= 5'h10;
                42  : data_b <= 5'h11;
            endcase
            if (tx_state == 42) begin
                tx_state <= 0;
                f_send_frame <= f_send;
            end
            else tx_state <= tx_state + 1;
            tx_start <= 1;
        end
        else tx_start <= 0;

// control (115200bps)
// ' '   : toggle measure output
// NTTTT : set LO of channel N's cycle as TTTT (hex)
        if (rx_f_receiving == 0 && rx_ready == 1) rx_f_receiving <= 1;
        if (rx_f_receiving == 1) begin
            rx_f_receiving <= 2;
            rx_byte <= rx_byte + 1;
            if (rx_byte == 0) begin
                if (rx_data == 8'h20) begin
                    f_send <= ~f_send;
                    rx_byte <= 0;
                end
                else r_lo_channel <= rx_data_b[1:0];
            end
//            if (rx_byte == 1) r_lo_cycle[15:12] <= rx_data_b;
            if (rx_byte == 1) r_lo_cycle[11:8] <= rx_data_b;
            if (rx_byte == 2) r_lo_cycle[7:4] <= rx_data_b;
            if (rx_byte == 3) r_lo_cycle[3:0] <= rx_data_b;
            if (rx_byte == 4) begin
                lo_cycle[r_lo_channel] <= r_lo_cycle;
                rx_byte <= 0;
            end
        end
        if (rx_f_receiving == 2 && rx_ready == 0) rx_f_receiving <= 0;
    end
    // LED color
    // none    (green)  : idle
    // magenda (white)  : received 1st byte
    // red     (yellow) : receiving rest

    assign led[0] = (rx_byte == 1)?(1'b0):(1'b1); // blue
    assign led[1] = (rx_byte == 0)?(1'b1):(1'b0); // red
 
    assign tx_data = data_h;

    always @(data_b) begin
        case (data_b) 
            5'h0 : data_h <= 8'h30;
            5'h1 : data_h <= 8'h31;
            5'h2 : data_h <= 8'h32;
            5'h3 : data_h <= 8'h33;
            5'h4 : data_h <= 8'h34;
            5'h5 : data_h <= 8'h35;
            5'h6 : data_h <= 8'h36;
            5'h7 : data_h <= 8'h37;
            5'h8 : data_h <= 8'h38;
            5'h9 : data_h <= 8'h39;
            5'ha : data_h <= 8'h41;
            5'hb : data_h <= 8'h42;
            5'hc : data_h <= 8'h43;
            5'hd : data_h <= 8'h44;
            5'he : data_h <= 8'h45;
            5'hf : data_h <= 8'h46;
            5'h10 : data_h <= 8'h0d; // CR
            5'h11 : data_h <= 8'h0a; // LF
            5'h12 : data_h <= 8'h2c; // comma
            default: data_h <= 8'h20; // space
        endcase
    end
    always @(rx_data) begin 
        case (rx_data)
            8'h30 : rx_data_b <= 4'h0;
            8'h31 : rx_data_b <= 4'h1;
            8'h32 : rx_data_b <= 4'h2;
            8'h33 : rx_data_b <= 4'h3;
            8'h34 : rx_data_b <= 4'h4;
            8'h35 : rx_data_b <= 4'h5;
            8'h36 : rx_data_b <= 4'h6;
            8'h37 : rx_data_b <= 4'h7;
            8'h38 : rx_data_b <= 4'h8;
            8'h39 : rx_data_b <= 4'h9;
            8'h41 : rx_data_b <= 4'ha; // 'A'
            8'h42 : rx_data_b <= 4'hb;
            8'h43 : rx_data_b <= 4'hc;
            8'h44 : rx_data_b <= 4'hd;
            8'h45 : rx_data_b <= 4'he;
            8'h46 : rx_data_b <= 4'hf;
            8'h61 : rx_data_b <= 4'ha; // 'a'
            8'h62 : rx_data_b <= 4'hb;
            8'h63 : rx_data_b <= 4'hc;
            8'h64 : rx_data_b <= 4'hd;
            8'h65 : rx_data_b <= 4'he;
            8'h66 : rx_data_b <= 4'hf;
            default : rx_data_b <= 0;
        endcase
    end

    // Mixer
    wire [2:0] w_mix_sig, w_mix_lo, w_mix_out;
    assign w_mix_sig = mix_in;
    assign w_mix_lo = r_lo;
    assign w_mix_out = w_mix_sig ^ w_mix_lo;
    assign mix_out = w_mix_out;
    assign lo_out = r_lo;
endmodule
