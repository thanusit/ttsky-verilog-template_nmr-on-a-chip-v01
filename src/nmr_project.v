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
    output wire [7:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)
    input  wire       ena,      // always 1 when design is powered
    input  wire       clk,      // clock
    input  wire       rst_n     // reset_n - low to reset
);
    
// Unused bidirectionals assigned safely to zero inputs
    assign uio_out = 8'b00000000; 
    assign uio_oe  = 8'b00000000;
    assign uo_out[7:4] = 4'b0000;
  
    // 1. Declare Internal Wires to interconnect the modules
    wire        start_pulse;
    wire [1:0]  pulse_type;
    wire        rf_out_signal;
    wire        rx_signal;

    // Assign Bidirectional Control (0 = input, 1 = output)
    // Example: uio[0] is input (RX line), uio[7:1] are outputs
    assign uio_oe = 8'b1111_1110; 
    assign rx_signal = uio_in[0]; 

    // 2. Instantiate the Pulse Sequencer
    pulse_sequencer sequencer_inst (
        .clk(clk),
        .rst_n(rst_n),
        .trigger(ui_in[0]),            // Map external trigger to input pin 0
        .start_rf(start_pulse),        // Internal connection to Transmitter
        .mode_select(pulse_type)       // Internal connection to Transmitter
    );

    // 3. Instantiate the RF Transmitter
    //rf_transmitter transmitter_inst (
    //    .clk(clk),
    //    .rst_n(rst_n),
    //    .start(start_pulse),           // Driven by Sequencer
    //    .mode(pulse_type),             // Driven by Sequencer
    //    .rf_out(rf_out_signal)         // Internal signal out
    //);

    // 4. Instantiate the Quadrature Demodulator
    //quadrature_demodulator demod_inst (
    //    .clk(clk),
    //    .rst_n(rst_n),
    //    .rf_in(rx_signal),             // Driven by external bidir pin 0
    //    .i_out(uo_out[3:0]),           // Map I-channel to lower output bits
    //    .q_out(uo_out[7:4])            // Map Q-channel to higher output bits
    // );

    // 5. Route remaining outputs to external dedicated output pins
    assign uo_out[0] = rf_out_signal;  // Route transmit signal to output pin 0
    assign uo_out[1] = start_pulse;    // Optional: debug pulse trigger monitor
    assign uo_out[2] = 1'b0;           // Unused pin tied to ground

    // Route remaining unused bidirectional outputs
    assign uio_out[7:1] = 7'b0000000;

endmodule
