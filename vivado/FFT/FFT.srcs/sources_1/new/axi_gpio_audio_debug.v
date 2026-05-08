`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 05/04/2026 10:28:02 AM
// Design Name: 
// Module Name: axi_gpio_audio_debug
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


module audio_debug_probe (
    input  wire        aclk,
    input  wire        aresetn,

    input  wire        tvalid,
    input  wire        tready,
    input  wire [2:0]  tid,
    input  wire [31:0] tdata,

    output reg [31:0]  debug_word
);

    always @(posedge aclk) begin
        if (!aresetn) begin
            debug_word <= 32'd0;
        end else begin
            // Capture only samples actually accepted by the I2S TX
            if (tvalid && tready) begin
                debug_word <= tdata;
            end
        end
    end

endmodule