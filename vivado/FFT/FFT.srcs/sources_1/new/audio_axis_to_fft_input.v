`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 05/07/2026 05:05:33 PM
// Design Name: 
// Module Name: audio_axis_to_fft_input
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


module audio_axis_to_fft_input #(
    parameter integer FRAME_LEN = 1024
)(
    input  wire        aclk,
    input  wire        aresetn,

    // Input from I2S receiver
    input  wire [31:0] s_axis_audio_tdata,
    input  wire        s_axis_audio_tvalid,
    output wire        s_axis_audio_tready,
    input  wire [2:0]  s_axis_audio_tid,

    // Output to FFT / equalizer
    output reg  [31:0] m_axis_fft_tdata,
    output reg         m_axis_fft_tvalid,
    input  wire        m_axis_fft_tready,
    output reg         m_axis_fft_tlast,

    // Optional debug
    output reg  [15:0] debug_sample16,
    output reg  [3:0]  debug_preamble,
    output reg  [2:0]  debug_tid
);

    reg [15:0] sample_count;

    wire signed [23:0] sample24;
    wire signed [15:0] sample16;
    wire [3:0] preamble;

    assign preamble = s_axis_audio_tdata[3:0];

    // Extract signed 24-bit audio sample
    assign sample24 = s_axis_audio_tdata[27:4];

    // Convert 24-bit audio to 16-bit for FFT.
    // This keeps the upper/significant bits and avoids overflow.
    assign sample16 = sample24[23:8];

    // Backpressure directly follows FFT readiness.
    assign s_axis_audio_tready = m_axis_fft_tready;

    always @(posedge aclk) begin
        if (!aresetn) begin
            m_axis_fft_tdata  <= 32'd0;
            m_axis_fft_tvalid <= 1'b0;
            m_axis_fft_tlast  <= 1'b0;

            sample_count      <= 16'd0;

            debug_sample16    <= 16'd0;
            debug_preamble    <= 4'd0;
            debug_tid         <= 3'd0;
        end else begin
            m_axis_fft_tlast <= 1'b0;

            if (s_axis_audio_tvalid && s_axis_audio_tready) begin
                // FFT format:
                // lower 16 bits = real
                // upper 16 bits = imaginary = 0
                m_axis_fft_tdata  <= {16'd0, sample16[15:0]};
                m_axis_fft_tvalid <= 1'b1;

                debug_sample16 <= sample16[15:0];
                debug_preamble <= preamble;
                debug_tid      <= s_axis_audio_tid;

                if (sample_count == FRAME_LEN - 1) begin
                    sample_count     <= 16'd0;
                    m_axis_fft_tlast <= 1'b1;
                end else begin
                    sample_count <= sample_count + 1'b1;
                end
            end else if (m_axis_fft_tready) begin
                m_axis_fft_tvalid <= 1'b0;
            end
        end
    end

endmodule
