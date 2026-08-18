set_property IOSTANDARD LVDS [get_ports CLKGTH_GC_P]
set_property IOSTANDARD LVDS [get_ports CLKGTH_GC_N]
set_property PACKAGE_PIN AY13 [get_ports CLKGTH_GC_P]
set_property PACKAGE_PIN BA13 [get_ports CLKGTH_GC_N]


set_property IOSTANDARD LVCMOS18 [get_ports CLK127M_EXIN_SEL]
set_property PACKAGE_PIN BE13 [get_ports CLK127M_EXIN_SEL]

set_property IOSTANDARD LVCMOS18 [get_ports GTH_CLK_SEL]
set_property PACKAGE_PIN BD13 [get_ports GTH_CLK_SEL]

set_property IOSTANDARD LVCMOS18 [get_ports GTY_CLK_SEL]
set_property PACKAGE_PIN BF14 [get_ports GTY_CLK_SEL]

set_property IOSTANDARD LVCMOS18 [get_ports {PLL_GTH_SEL0 PLL_GTH_SEL1 PLL_GTY_SEL0 PLL_GTY_SEL1}]

create_clock -period 7.800 -name CLKGTH_GC [get_ports CLKGTH_GC_P]

set_property BITSTREAM.STARTUP.STARTUPCLK CCLK [current_design]
set_property SEVERITY {Warning} [get_drc_checks NSTD-1]
set_property SEVERITY {Warning} [get_drc_checks UCIO-1]