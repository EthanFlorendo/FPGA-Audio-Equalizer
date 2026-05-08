`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 05/03/2026 02:51:58 AM
// Design Name: 
// Module Name: audio_to_fft_axis
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


module audio_to_fft_axis #(
    parameter FFT_SIZE = 1024
)(
    input  wire        aclk,
    input  wire        aresetn,

    // From I2S RX / audio stream
    input  wire [31:0] s_axis_tdata,
    input  wire        s_axis_tvalid,
    output wire        s_axis_tready,

    // To FFT
    output reg  [31:0] m_axis_tdata,
    output reg         m_axis_tvalid,
    input  wire        m_axis_tready,
    output reg         m_axis_tlast
);

    localparam CNT_BITS = 10;

    reg [CNT_BITS-1:0] sample_count;

    assign s_axis_tready = (~m_axis_tvalid) || m_axis_tready;

    // Take top 16 bits as signed audio sample.
    // Adjust this if your I2S RX packs samples differently.
    wire signed [15:0] audio_sample = s_axis_tdata[31:16];

    always @(posedge aclk) begin
        if (!aresetn) begin
            sample_count  <= 0;
            m_axis_tdata  <= 0;
            m_axis_tvalid <= 0;
            m_axis_tlast  <= 0;
        end else begin
            if (s_axis_tready) begin
                m_axis_tvalid <= s_axis_tvalid;

                if (s_axis_tvalid) begin
                    // FFT input: imag = 0, real = audio_sample
                    m_axis_tdata <= {16'd0, audio_sample};

                    m_axis_tlast <= (sample_count == FFT_SIZE-1);

                    if (sample_count == FFT_SIZE-1)
                        sample_count <= 0;
                    else
                        sample_count <= sample_count + 1'b1;
                end
            end
        end
    end

endmodule
