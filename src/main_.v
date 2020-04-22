module FSd1 (clk24M, rst_n, mix_in, lo_out, mix_out, sig_in, TXD, RXD, led);
    input clk24M, rst_n;
    input [2:0] mix_in;
    input [2:0] sig_in;
    output[2:0] lo_out, mix_out;
    input RXD;
    output TXD;
    output [1:0] led;

    reg [15:0] lo_cnt[0:2];
    reg [15:0] lo_cycle[0:2];
    reg [2:0] r_lo;
    reg [15:0] raw_cnt[0:2], raw_cnt_work[0:2];
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
    reg [15:0] r_lo_cycle;
    reg [3:0] rx_data_b;
    reg f_send;
    reg [1:0] r_lo_channel;
    wire w_txd;

    RX8 irx8(clk24M, rst, RXD, rx_data, rx_ready);
    TX8 itx8(clk24M, rst, tx_data, w_txd, tx_start, tx_busy);
//    assign TXD = RXD;
    assign TXD = (f_send == 1)?(w_txd):(1'b1);

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
            tx_start <= 0; tx_state <= 0;
            rx_f_receiving <= 0; rx_byte <= 0;
            f_send <= 0;
        end
        if (tx_busy == 0 && tx_start == 0) begin
            case (tx_state) 
                0  : data_b <= raw_cnt[0][15:12];
                1  : data_b <= raw_cnt[0][11:8];
                2  : data_b <= raw_cnt[0][7:4];
                3  : data_b <= raw_cnt[0][3:0];
                4  : data_b <= 5'h12;
                5  : data_b <= raw_cnt[1][15:12];
                6  : data_b <= raw_cnt[1][11:8];
                7  : data_b <= raw_cnt[1][7:4];
                8  : data_b <= raw_cnt[1][3:0];
                9  : data_b <= 5'h12;
                10 : data_b <= raw_cnt[2][15:12];
                11 : data_b <= raw_cnt[2][11:8];
                12 : data_b <= raw_cnt[2][7:4];
                13 : data_b <= raw_cnt[2][3:0];
                14 : data_b <= 5'h12;
                15 : data_b <= sig_cnt[0][23:20];
                16 : data_b <= sig_cnt[0][19:16];
                17 : data_b <= sig_cnt[0][15:12];
                18 : data_b <= sig_cnt[0][11:8];
                19 : data_b <= sig_cnt[0][7:4];
                20 : data_b <= sig_cnt[0][3:0];
                21  : data_b <= 5'h12;
                22 : data_b <= sig_cnt[1][23:20];
                23 : data_b <= sig_cnt[1][19:16];
                24 : data_b <= sig_cnt[1][15:12];
                25 : data_b <= sig_cnt[1][11:8];
                26 : data_b <= sig_cnt[1][7:4];
                27 : data_b <= sig_cnt[1][3:0];
                28 : data_b <= 5'h12;
                29 : data_b <= sig_cnt[2][23:20];
                30 : data_b <= sig_cnt[2][19:16];
                31 : data_b <= sig_cnt[2][15:12];
                32 : data_b <= sig_cnt[2][11:8];
                33 : data_b <= sig_cnt[2][7:4];
                34 : data_b <= sig_cnt[2][3:0];
                35 : data_b <= 5'h10;
                36 : data_b <= 5'h11;
            endcase
            if (tx_state == 36) tx_state <= 0;
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
            if (rx_byte == 1) r_lo_cycle[15:12] <= rx_data_b;
            if (rx_byte == 2) r_lo_cycle[11:8] <= rx_data_b;
            if (rx_byte == 3) r_lo_cycle[7:4] <= rx_data_b;
            if (rx_byte == 4) r_lo_cycle[3:0] <= rx_data_b;
            if (rx_byte == 4) begin
                lo_cycle[r_lo_channel] <= r_lo_cycle;
                rx_byte <= 0;
            end
        end
        if (rx_f_receiving == 2 && rx_ready == 0) rx_f_receiving <= 0;
    end
    // LED color
    // green  : idle
    // white  : received 1st byte
    // yellow : receiving rest
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
