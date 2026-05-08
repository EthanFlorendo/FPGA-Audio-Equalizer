`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 05/03/2026 02:56:40 AM
// Design Name: 
// Module Name: axis_fft_config_gen
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


module axis_fft_config_gen #(
    parameter [15:0] CONFIG_WORD = 16'h0001
)(
    input  wire        aclk,
    input  wire        aresetn,

    output reg  [15:0] m_axis_tdata,
    output reg         m_axis_tvalid,
    input  wire        m_axis_tready
);

    reg sent;

    always @(posedge aclk) begin
        if (!aresetn) begin
            m_axis_tdata  <= CONFIG_WORD;
            m_axis_tvalid <= 1'b1;
            sent          <= 1'b0;
        end else begin
            m_axis_tdata <= CONFIG_WORD;

            if (!sent) begin
                m_axis_tvalid <= 1'b1;

                if (m_axis_tvalid && m_axis_tready) begin
                    sent <= 1'b1;
                    m_axis_tvalid <= 1'b0;
                end
            end
        end
    end

endmodule
