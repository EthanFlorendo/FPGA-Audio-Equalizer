`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 05/03/2026 07:54:12 PM
// Design Name: 
// Module Name: axis_audio_tone_gen
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
module axis_audio_tone_gen (
    input  wire        aclk,
    input  wire        aresetn,

    output reg [31:0]  m_axis_tdata,
    output reg         m_axis_tvalid,
    input  wire        m_axis_tready,
    output reg [2:0]   m_axis_tid
);

    reg [15:0] phase;
    wire signed [23:0] sample24 =
        phase[15] ? 24'sd6000000 : -24'sd6000000;

    always @(posedge aclk) begin
        if (!aresetn) begin
            phase         <= 16'd0;
            m_axis_tdata  <= 32'd0;
            m_axis_tvalid <= 1'b0;
            m_axis_tid    <= 3'd0;
        end else begin
            m_axis_tvalid <= 1'b1;

            // Only update when transfer happens or first valid cycle
            if (!m_axis_tvalid || m_axis_tready) begin
                m_axis_tid   <= 3'd0;
                m_axis_tdata <= {{8{sample24[23]}}, sample24};
                phase        <= phase + 16'd1500;
            end
        end
    end

endmodule