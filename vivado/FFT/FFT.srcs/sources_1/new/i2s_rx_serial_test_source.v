`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 05/07/2026 04:07:51 PM
// Design Name: 
// Module Name: i2s_rx_serial_test_source
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module i2s_rx_serial_test_source (
    input  wire sclk,
    input  wire lrclk,
    input  wire resetn,

    output reg  sdata
);

    // Test samples
    // Use obvious signed 24-bit values
    localparam signed [23:0] LEFT_SAMPLE_POS  = 24'sd4000000;
    localparam signed [23:0] LEFT_SAMPLE_NEG  = -24'sd4000000;
    localparam signed [23:0] RIGHT_SAMPLE_POS = 24'sd1000000;
    localparam signed [23:0] RIGHT_SAMPLE_NEG = -24'sd1000000;

    reg lrclk_d;
    reg [5:0] bit_count;
    reg [23:0] shift_reg;
    reg tone_phase;

    wire lrclk_edge = (lrclk != lrclk_d);

    always @(negedge sclk) begin
        if (!resetn) begin
            sdata      <= 1'b0;
            lrclk_d    <= 1'b0;
            bit_count  <= 6'd0;
            shift_reg  <= 24'd0;
            tone_phase <= 1'b0;
        end else begin
            lrclk_d <= lrclk;

            if (lrclk_edge) begin
                bit_count <= 6'd0;

                // Toggle test tone once per LRCLK edge
                tone_phase <= ~tone_phase;

                // Choose sample based on LRCLK side.
                // If left/right appear swapped, that is okay for testing.
                if (lrclk == 1'b0) begin
                    shift_reg <= tone_phase ? LEFT_SAMPLE_POS[23:0] : LEFT_SAMPLE_NEG[23:0];
                end else begin
                    shift_reg <= tone_phase ? RIGHT_SAMPLE_POS[23:0] : RIGHT_SAMPLE_NEG[23:0];
                end

                // I2S has a 1-bit delay after LRCLK edge
                sdata <= 1'b0;
            end else begin
                if (bit_count == 6'd0) begin
                    // one-bit I2S delay slot
                    sdata <= 1'b0;
                    bit_count <= bit_count + 1'b1;
                end else if (bit_count <= 6'd24) begin
                    // MSB first
                    sdata <= shift_reg[23];
                    shift_reg <= {shift_reg[22:0], 1'b0};
                    bit_count <= bit_count + 1'b1;
                end else begin
                    sdata <= 1'b0;
                end
            end
        end
    end

endmodule
