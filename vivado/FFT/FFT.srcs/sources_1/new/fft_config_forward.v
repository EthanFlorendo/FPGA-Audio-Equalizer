`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 05/07/2026 06:37:57 PM
// Design Name: 
// Module Name: fft_config_forward
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


module fft_config_forward (
    input  wire        aclk,
    input  wire        aresetn,

    output reg  [15:0] m_axis_config_tdata,
    output reg         m_axis_config_tvalid,
    input  wire        m_axis_config_tready
);

    reg sent;

    always @(posedge aclk) begin
        if (!aresetn) begin
            m_axis_config_tdata  <= 16'h0001;  // forward FFT
            m_axis_config_tvalid <= 1'b0;
            sent                 <= 1'b0;
        end else begin
            if (!sent) begin
                m_axis_config_tdata  <= 16'h0001;
                m_axis_config_tvalid <= 1'b1;

                if (m_axis_config_tready) begin
                    m_axis_config_tvalid <= 1'b0;
                    sent <= 1'b1;
                end
            end else begin
                m_axis_config_tvalid <= 1'b0;
            end
        end
    end

endmodule
