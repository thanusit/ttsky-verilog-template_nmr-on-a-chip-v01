/*
 * Copyright (c) 2026 Thanusit Burinprakhon
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

module spi_tx (
    input  wire       clk,        // System clock
    input  wire       rst_n,      // Active-low reset
    input  wire       trig_load,  // High for 1 cycle to load new data
    input  wire [7:0] data_i,     // Full 8-bit In-phase component
    input  wire [7:0] data_q,     // Full 8-bit Quadrature component
    output reg        spi_sclk,   // SPI Serial Clock output to host
    output reg        spi_miso,   // SPI Serial Data output to host
    output reg        spi_busy    // Status flag (High while transmitting)
);

    reg [15:0] shift_reg;
    reg [4:0]  bit_count;
    reg        clk_div;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            shift_reg <= 16'h0000;
            bit_count <= 5'd0;
            spi_sclk  <= 1'b0;
            spi_miso  <= 1'b0;
            spi_busy  <= 1'b0;
            clk_div   <= 1'b0;
        end else begin
            if (trig_load && !spi_busy) begin
                // Capture full 8-bit resolutions side-by-side
                shift_reg <= {data_i, data_q};
                bit_count <= 5'd16;
                spi_busy  <= 1'b1;
                clk_div   <= 1'b0;
                spi_sclk  <= 1'b0;
            end else if (spi_busy) begin
                clk_div <= !clk_div;
                
                // Generate SCLK by splitting the main clock cycle
                if (clk_div == 1'b0) begin
                    spi_miso <= shift_reg[15]; // Drive out MSB first
                    spi_sclk <= 1'b1;          // Rising edge
                end else begin
                    spi_sclk  <= 1'b0;         // Falling edge
                    shift_reg <= {shift_reg[14:0], 1'b0}; // Shift left
                    bit_count <= bit_count - 1'b1;
                    
                    if (bit_count == 5'd1) begin
                        spi_busy <= 1'b0;      // All 16 bits sent
                    end
                end
            end else begin
                spi_sclk <= 1'b0;
                spi_miso <= 1'b0;
            end
        end
    end

endmodule
