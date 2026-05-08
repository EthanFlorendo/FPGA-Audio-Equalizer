set_property -dict { PACKAGE_PIN U5 IOSTANDARD LVCMOS33 } [get_ports audio_clk_10MHz]

set_property -dict { PACKAGE_PIN U9 IOSTANDARD LVCMOS33 } [get_ports IIC_1_scl_io]
set_property PULLUP true [get_ports IIC_1_scl_io]

set_property -dict { PACKAGE_PIN T9 IOSTANDARD LVCMOS33 } [get_ports IIC_1_sda_io]
set_property PULLUP true [get_ports IIC_1_sda_io]

set_property -dict { PACKAGE_PIN R18 IOSTANDARD LVCMOS33 } [get_ports aud_sclk_out]
set_property -dict { PACKAGE_PIN T17 IOSTANDARD LVCMOS33 } [get_ports aud_lrclk_out]
set_property -dict { PACKAGE_PIN G18 IOSTANDARD LVCMOS33 } [get_ports aud_sdata_0_out]
set_property -dict { PACKAGE_PIN F17 IOSTANDARD LVCMOS33 } [get_ports aud_sdata_0_in]
