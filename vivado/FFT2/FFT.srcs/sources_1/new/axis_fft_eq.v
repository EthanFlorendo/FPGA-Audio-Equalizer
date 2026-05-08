`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 05/02/2026 04:32:19 PM
// Design Name: 
// Module Name: axis_fft_eq
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


module axis_fft_eq #(
    parameter FFT_SIZE = 1024,
    parameter LOW_HIGH_BIN = 5,
    parameter MID_HIGH_BIN = 85
)(
    input  wire         aclk,
    input  wire         aresetn,

    input  wire [31:0]  s_axis_tdata,
    input  wire         s_axis_tvalid,
    output wire         s_axis_tready,
    input  wire         s_axis_tlast,

    output reg  [31:0]  m_axis_tdata,
    output reg          m_axis_tvalid,
    input  wire         m_axis_tready,
    output reg          m_axis_tlast,

    input  wire [15:0]  gain_low,
    input  wire [15:0]  gain_mid,
    input  wire [15:0]  gain_high
);

    localparam BIN_BITS = 10;

    reg [BIN_BITS-1:0] bin_index;

    wire signed [15:0] real_in;
    wire signed [15:0] imag_in;

    assign real_in = s_axis_tdata[15:0];
    assign imag_in = s_axis_tdata[31:16];

    reg [15:0] gain;

    assign s_axis_tready = (~m_axis_tvalid) || m_axis_tready;

    always @(*) begin
        if ((bin_index <= LOW_HIGH_BIN) ||
            (bin_index >= FFT_SIZE - LOW_HIGH_BIN)) begin
            gain = gain_low;
        end
        else if ((bin_index <= MID_HIGH_BIN) ||
                 (bin_index >= FFT_SIZE - MID_HIGH_BIN)) begin
            gain = gain_mid;
        end
        else begin
            gain = gain_high;
        end
    end

    wire signed [31:0] real_mult;
    wire signed [31:0] imag_mult;

    assign real_mult = real_in * $signed({1'b0, gain});
    assign imag_mult = imag_in * $signed({1'b0, gain});

    wire signed [31:0] real_scaled_full;
    wire signed [31:0] imag_scaled_full;

    assign real_scaled_full = real_mult >>> 15;
    assign imag_scaled_full = imag_mult >>> 15;

    function signed [15:0] sat16;
        input signed [31:0] x;
        begin
            if (x > 32767)
                sat16 = 16'sd32767;
            else if (x < -32768)
                sat16 = -16'sd32768;
            else
                sat16 = x[15:0];
        end
    endfunction

    wire signed [15:0] real_out;
    wire signed [15:0] imag_out;

    assign real_out = sat16(real_scaled_full);
    assign imag_out = sat16(imag_scaled_full);

    always @(posedge aclk) begin
        if (!aresetn) begin
            m_axis_tdata  <= 32'd0;
            m_axis_tvalid <= 1'b0;
            m_axis_tlast  <= 1'b0;
            bin_index     <= {BIN_BITS{1'b0}};
        end
        else begin
            if (s_axis_tready) begin
                m_axis_tvalid <= s_axis_tvalid;

                if (s_axis_tvalid) begin
                    m_axis_tdata <= {imag_out, real_out};
                    m_axis_tlast <= s_axis_tlast;

                    if (s_axis_tlast)
                        bin_index <= {BIN_BITS{1'b0}};
                    else
                        bin_index <= bin_index + 1'b1;
                end
            end
        end
    end

endmodule
