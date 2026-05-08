`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 05/07/2026 01:08:55 AM
// Design Name: 
// Module Name: axis_audio_constant_source
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


module axis_audio_constant_source (
    input  wire        aclk,
    input  wire        aresetn,

    output wire [31:0] m_axis_tdata,
    output wire        m_axis_tvalid,
    input  wire        m_axis_tready,
    output wire [2:0]  m_axis_tid
);

    assign m_axis_tvalid = aresetn;
    assign m_axis_tdata  = 32'h007FFFFF;
    assign m_axis_tid    = 3'd0;

endmodule
