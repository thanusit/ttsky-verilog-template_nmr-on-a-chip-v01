/*
 * Copyright (c) 2026 Thanusit Burinprakhon
 * SPDX-License-Identifier: Apache-2.0
 */

`timescale 1ns / 1ps
`default_nettype none

module tb;

    // -------------------------------------------------------------------------
    // Testbench Wire and Register Declarations
    // -------------------------------------------------------------------------
    reg [7:0] ui_in;
    reg [7:0] uio_in;
    reg       ena;
    reg       clk;
    reg       rst_n;

    wire [7:0] uo_out;
    wire [7:0] uio_out;
    wire [7:0] uio_oe;

    // Dedicated Output Port Aliases
    wire rf_pulse_A   = uo_out[0];
    wire rf_pulse_B   = uo_out[1];
    wire rx_gate      = uo_out[2];
    wire status_busy  = uo_out[3];
    wire spi_out_sclk = uo_out[4];
    wire spi_out_miso = uo_out[5];
    wire spi_out_busy = uo_out[6];

    // Track testbench echo counting internally
    integer echo_idx;

    // -------------------------------------------------------------------------
    // Device Under Test (DUT) Instantiation
    // -------------------------------------------------------------------------
    tt_um_thanusit_nmr_cores user_project (
        .ui_in(ui_in), .uo_out(uo_out),
        .uio_in(uio_in), .uio_out(uio_out), .uio_oe(uio_oe),
        .ena(ena), .clk(clk), .rst_n(rst_n)
    );

    // -------------------------------------------------------------------------
    // Clock Generation (20 MHz System Clock -> 50ns cycle period)
    // -------------------------------------------------------------------------
    always #25 clk = ~clk;

    // -------------------------------------------------------------------------
    // Digitized RF Input Signal Generator (Simulates Echo Signal Ingestion)
    // -------------------------------------------------------------------------
    // Toggles a mock 5 MHz alternating signal into ui_in[4] ONLY when rx_gate is active.
    always begin
        #50; // Check every 50ns
        if (rx_gate) begin
            ui_in[4] = ~ui_in[4]; 
        end else begin
            ui_in[4] = 1'b0; // Quiet baseline when gate is closed
        end
    end

    // -------------------------------------------------------------------------
    // Main Test Vector Execution Flow
    // -------------------------------------------------------------------------
    initial begin
        // 1. Initialize safe startup states
        clk    = 1'b0;
        rst_n  = 1'b1;
        ena    = 1'b1;
        uio_in = 8'h00;
        ui_in  = 8'h08; // Set pin 3 (spi_ss_n) = 1, all others 0

        #100;
        reset_system();
        #100;

        // 2. Program multi-echo sequence parameters via SPI
        // Frame format: [tA(32-bit)][tau(32-bit)][tB(32-bit)][echo_count(32-bit)]
        // We set echo_count = 4 to verify 4 back-to-back windows!
        $display("[%t] [TB] Streaming 128-bit config payload (Echo Count = 4)...", $time);
        spi_write_128({32'd10, 32'd50, 32'd20, 32'd4});
        #200;

        // 3. Fire the sequence
        $display("[%t] [TB] Pulsing start trigger...", $time);
        @(negedge clk);
        ui_in[0] = 1'b1; // Drive ui_in[0] (start) high
        @(negedge clk);
        ui_in[0] = 1'b0; // Return start low

        // 4. Trace and handle back-to-back echo transmissions dynamically
        fork
            // Thread A: Monitor the master sequencer lifecycle
            begin
                @(posedge status_busy);
                $display("[%t] [TB] Master sequencer loop entered busy operational state.", $time);
                @(negedge status_busy);
                $display("[%t] [TB] Master sequencer loop finished all planned echoes.", $time);
            end

            // Thread B: Capture and print each back-to-back SPI data readout train
            begin
                for (echo_idx = 1; echo_idx <= 4; echo_idx = echo_idx + 1) begin
                    // Monitor when the readout engine begins serialization for this echo window
                    @(posedge spi_out_busy);
                    $display("[%t] [TB] >>> Echo #%0d SPI readout transmission started.", $time, echo_idx);
                    
                    // Optional: Monitor the incoming bits on spi_out_miso here if desired
                    
                    @(negedge spi_out_busy);
                    $display("[%t] [TB] <<< Echo #%0d SPI readout transmission completed.", $time, echo_idx);
                end
            end
        join

        // 5. Finalize execution run
        #1000;
        $display("[%t] [TB] Back-to-back echo simulation verified successfully.", $time);
        $finish;
    end

    // -------------------------------------------------------------------------
    // Hardware Simulation Control Tasks
    // -------------------------------------------------------------------------
    
    task reset_system;
    begin
        $display("[%t] [TB] Asserting active-low hardware reset...", $time);
        rst_n = 1'b0;
        ui_in[3] = 1'b1; // Keep spi_ss_n deasserted
        ui_in[0] = 1'b0; // Keep start deasserted
        #(100);
        rst_n = 1'b1;
        $display("[%t] [TB] Reset released.", $time);
    end
    endtask

    // Safely shift config bits over the SPI lines to the pulse sequencer
    task spi_write_128(input [127:0] data_payload);
        integer i;
        begin
            ui_in[3] = 1'b0; // Pull spi_ss_n LOW
            ui_in[1] = 1'b0; // Clear spi_sclk
            #50;

            for (i = 127; i >= 0; i = i - 1) begin
                ui_in[2] = data_payload[i]; // Assign ui_in[2] (spi_mosi)
                #50;
                ui_in[1] = 1'b1;             // Toggle spi_sclk High
                #50;
                ui_in[1] = 1'b0;             // Toggle spi_sclk Low
            end
            
            #50;
            ui_in[3] = 1'b1; // Snap spi_ss_n HIGH to trigger parallel parameter load
            #100;
        end
    endtask

    // VCD Dump Routine
    initial begin
        $dumpfile("back_to_back_echoes.vcd");
        $dumpvars(0, tb);
    end

endmodule
