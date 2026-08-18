// Copyright 1986-2022 Xilinx, Inc. All Rights Reserved.
// Copyright 2022-2023 Advanced Micro Devices, Inc. All Rights Reserved.
// --------------------------------------------------------------------------------
// Tool Version: Vivado v.2023.2 (lin64) Build 4029153 Fri Oct 13 20:13:54 MDT 2023
// Date        : Mon Aug  3 11:23:16 2026
// Host        : cef03 running 64-bit Ubuntu 22.04.3 LTS
// Command     : write_verilog -force -mode synth_stub
//               /data/nahom338/my_hls_project/micro_qnet_OPTIMAL/project_1/project_1.gen/sources_1/ip/myproject_0/myproject_0_stub.v
// Design      : myproject_0
// Purpose     : Stub declaration of top-level module interface
// Device      : xcvu080-ffvb2104-2-e
// --------------------------------------------------------------------------------

// This empty module with port declaration file causes synthesis tools to infer a black box for IP.
// The synthesis directives are for Synopsys Synplify support to prevent IO buffer insertion.
// Please paste the declaration into a Verilog source file or add the file as an additional source.
(* X_CORE_INFO = "myproject,Vivado 2023.2" *)
module myproject_0(input_layer_TVALID, input_layer_TREADY, 
  input_layer_TDATA, layer18_out_TVALID, layer18_out_TREADY, layer18_out_TDATA, ap_clk, 
  ap_rst_n, ap_start, ap_done, ap_ready, ap_idle)
/* synthesis syn_black_box black_box_pad_pin="input_layer_TVALID,input_layer_TREADY,input_layer_TDATA[7:0],layer18_out_TVALID,layer18_out_TREADY,layer18_out_TDATA[15:0],ap_rst_n,ap_start,ap_done,ap_ready,ap_idle" */
/* synthesis syn_force_seq_prim="ap_clk" */;
  input input_layer_TVALID;
  output input_layer_TREADY;
  input [7:0]input_layer_TDATA;
  output layer18_out_TVALID;
  input layer18_out_TREADY;
  output [15:0]layer18_out_TDATA;
  input ap_clk /* synthesis syn_isclock = 1 */;
  input ap_rst_n;
  input ap_start;
  output ap_done;
  output ap_ready;
  output ap_idle;
endmodule
