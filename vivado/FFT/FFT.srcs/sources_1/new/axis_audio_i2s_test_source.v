`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 05/07/2026 01:33:09 AM
// Design Name: 
// Module Name: axis_audio_i2s_test_source
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
module axis_audio_i2s_test_source (
    input  wire        aclk,
    input  wire        aresetn,

    output reg [31:0]  m_axis_tdata,
    output reg         m_axis_tvalid,
    input  wire        m_axis_tready,
    output reg [2:0]   m_axis_tid
);

    reg channel;
    reg [7:0] frame_count;
    reg [15:0] phase;
    reg [3:0] preamble;

    wire signed [23:0] sample24 =
    phase[15] ? 24'sd8000000 : -24'sd8000000;

    always @(*) begin
        if (!channel) begin
            if (frame_count == 8'd0)
                preamble = 4'h1;   // start of block, channel 0
            else
                preamble = 4'h2;   // channel 0
        end else begin
            preamble = 4'h3;       // channel 1
        end
    end

    always @(posedge aclk) begin
        if (!aresetn) begin
            channel       <= 1'b0;
            frame_count   <= 8'd0;
            phase         <= 16'd0;
            m_axis_tdata  <= 32'd0;
            m_axis_tvalid <= 1'b0;
            m_axis_tid    <= 3'd0;
        end else begin
            m_axis_tvalid <= 1'b1;

            if (!m_axis_tvalid || m_axis_tready) begin
                // [31:28] = control bits
                // [27:4]  = 24-bit audio sample
                // [3:0]   = preamble
                m_axis_tdata <= {4'h0, sample24, preamble};

                m_axis_tid <= channel ? 3'd1 : 3'd0;

                channel <= ~channel;

                // Advance tone once per stereo pair
                if (channel) begin
                    phase <= phase + 16'd300;

                    if (frame_count == 8'd191)
                        frame_count <= 8'd0;
                    else
                        frame_count <= frame_count + 1'b1;
                end
            end
        end
    end

endmodule