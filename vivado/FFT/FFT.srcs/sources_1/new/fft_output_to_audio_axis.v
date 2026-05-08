`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 05/07/2026 05:07:22 PM
// Design Name: 
// Module Name: fft_output_to_audio_axis
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


module fft_output_to_audio_axis (
    input  wire        aclk,
    input  wire        aresetn,

    // Input from FFT / equalizer / IFFT
    input  wire [31:0] s_axis_fft_tdata,
    input  wire        s_axis_fft_tvalid,
    output wire        s_axis_fft_tready,
    input  wire        s_axis_fft_tlast,

    // Output to I2S transmitter
    output reg  [31:0] m_axis_audio_tdata,
    output reg         m_axis_audio_tvalid,
    input  wire        m_axis_audio_tready,
    output reg  [2:0]  m_axis_audio_tid,

    // Optional debug
    output reg  [23:0] debug_sample24,
    output reg  [3:0]  debug_preamble
);

    reg        channel;
    reg [7:0]  frame_count;

    wire signed [15:0] real16;
    wire signed [23:0] sample24;

    reg [3:0] preamble;

    // FFT/IFFT output format:
    // lower 16 bits = real
    // upper 16 bits = imag
    assign real16 = s_axis_fft_tdata[15:0];

    // Convert signed int16 back to signed 24-bit audio.
    // Left shift by 8 to recover amplitude range.
    assign sample24 = {real16, 8'd0};

    assign s_axis_fft_tready = m_axis_audio_tready;

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
            channel            <= 1'b0;
            frame_count        <= 8'd0;

            m_axis_audio_tdata  <= 32'd0;
            m_axis_audio_tvalid <= 1'b0;
            m_axis_audio_tid    <= 3'd0;

            debug_sample24      <= 24'd0;
            debug_preamble      <= 4'd0;
        end else begin
            if (s_axis_fft_tvalid && s_axis_fft_tready) begin
                // I2S TX audio format:
                // [31:28] = control bits
                // [27:4]  = signed 24-bit sample
                // [3:0]   = preamble
                m_axis_audio_tdata  <= {4'h0, sample24[23:0], preamble};
                m_axis_audio_tvalid <= 1'b1;
                m_axis_audio_tid    <= channel ? 3'd1 : 3'd0;

                debug_sample24 <= sample24[23:0];
                debug_preamble <= preamble;

                channel <= ~channel;

                // Advance AES frame count once per stereo pair
                if (channel) begin
                    if (frame_count == 8'd191)
                        frame_count <= 8'd0;
                    else
                        frame_count <= frame_count + 1'b1;
                end
            end else if (m_axis_audio_tready) begin
                m_axis_audio_tvalid <= 1'b0;
            end
        end
    end

endmodule
