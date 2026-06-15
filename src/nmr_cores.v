/*
 * Copyright (c) 2026 Thanusit Burinprakhon
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

module tt_um_thanusit_nmr_cores (
    input  wire [7:0] ui_in,    // Dedicated inputs
    output wire [7:0] uo_out,   // Dedicated outputs
    input  wire [7:0] uio_in,   // IOs: Input path
    output wire [7:0] uio_out,  // IOs: Output path
    output wire [7:0] uio_oe,   // IOs: Enable path (active high)
    input  wire       ena,      // always 1 when design is powered
    input  wire       clk,      // clock
    input  wire       rst_n     // reset_n - low to reset
);

    // Internal wires connecting the sub-module outputs
    wire psq_rf_A;
    wire psq_rf_B;
    wire psq_rx_gate;
    wire psq_busy;
    
    wire [7:0] demod_i;
    wire [7:0] demod_q;

    // Instantiate CPMG Pulse Sequencer
    pulse_sequencer psq_inst (
        .clk(clk),
        .rst_n(rst_n),
        .start(ui_in[0]),
        .spi_sclk(ui_in[1]),
        .spi_mosi(ui_in[2]),
        .spi_ss_n(ui_in[3]),
        .rf_pulse_A(psq_rf_A),   
        .rf_pulse_B(psq_rf_B),   
        .rx_gate(psq_rx_gate),   
        .status_busy(psq_busy)
    );

    // Instantiate Quadrature Demodulator
    quadrature_demodulator demod_inst (
        .clk(clk),
        .rst_n(rst_n),
        .rx_gate(psq_rx_gate),   // Gated processing window directly from sequencer
        .rx_in(ui_in[4]),        // 1-Bit Digitized RF Input Signal mapped to pin 4
        .i_out(demod_i),
        .q_out(demod_q)
    );

    // Bind physical dedicated output pins
    assign uo_out[0] = psq_rf_A;
    assign uo_out[1] = psq_rf_B;
    assign uo_out[2] = psq_rx_gate;
    assign uo_out[3] = psq_busy;
    
    // Output the lower 4 bits of I and Q streams to dedicated output pins 4-7
    assign uo_out[5:4] = demod_i[1:0];
    assign uo_out[7:6] = demod_q[1:0];

    // Map remaining upper 6 bits of I and Q streams over the bi-directional bus
    assign uio_out[3:0] = demod_i[5:2];
    assign uio_out[7:4] = demod_q[5:2];
    
    // Set all Bidirectional IOs explicitly as outputs (Active-High Output Enable)
    assign uio_oe = 8'b11111111;

endmodule
