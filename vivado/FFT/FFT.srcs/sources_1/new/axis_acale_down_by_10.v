`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 05/02/2026 06:01:29 PM
// Design Name: 
// Module Name: axis_acale_down_by_10
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


module axis_scale_down_by_10 (
    input  wire        aclk,
    input  wire        aresetn,

    input  wire [31:0] s_axis_tdata,
    input  wire        s_axis_tvalid,
    output wire        s_axis_tready,
    input  wire        s_axis_tlast,

    output reg  [31:0] m_axis_tdata,
    output reg         m_axis_tvalid,
    input  wire        m_axis_tready,
    output reg         m_axis_tlast
);

    wire signed [15:0] real_in = s_axis_tdata[15:0];
    wire signed [15:0] imag_in = s_axis_tdata[31:16];

    wire signed [15:0] real_out = real_in >>> 10;
    wire signed [15:0] imag_out = imag_in >>> 10;

    assign s_axis_tready = (~m_axis_tvalid) || m_axis_tready;

    always @(posedge aclk) begin
        if (!aresetn) begin
            m_axis_tdata  <= 32'd0;
            m_axis_tvalid <= 1'b0;
            m_axis_tlast  <= 1'b0;
        end else if (s_axis_tready) begin
            m_axis_tvalid <= s_axis_tvalid;
            if (s_axis_tvalid) begin
                m_axis_tdata <= {imag_out, real_out};
                m_axis_tlast <= s_axis_tlast;
            end
        end
    end

endmodule
