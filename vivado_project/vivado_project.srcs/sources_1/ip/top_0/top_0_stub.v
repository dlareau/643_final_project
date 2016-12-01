// Copyright 1986-2015 Xilinx, Inc. All Rights Reserved.
// --------------------------------------------------------------------------------
// Tool Version: Vivado v.2015.2 (lin64) Build 1266856 Fri Jun 26 16:35:25 MDT 2015
// Date        : Thu Dec  1 15:45:56 2016
// Host        : ares.andrew.local.cmu.edu running 64-bit Red Hat Enterprise Linux Server release 7.2 (Maipo)
// Command     : write_verilog -force -mode synth_stub
//               /afs/ece.cmu.edu/usr/jlareau/Private/18643/643_final_project/vivado_project/vivado_project.srcs/sources_1/ip/top_0/top_0_stub.v
// Design      : top_0
// Purpose     : Stub declaration of top-level module interface
// Device      : xc7z020clg484-1
// --------------------------------------------------------------------------------

// This empty module with port declaration file causes synthesis tools to infer a black box for IP.
// The synthesis directives are for Synopsys Synplify support to prevent IO buffer insertion.
// Please paste the declaration into a Verilog source file or add the file as an additional source.
(* X_CORE_INFO = "top,Vivado 2015.2" *)
module top_0(clk, reset_L, valid_in, valid_out, data_in, data_out)
/* synthesis syn_black_box black_box_pad_pin="clk,reset_L,valid_in,valid_out,data_in[31:0],data_out[31:0]" */;
  input clk;
  input reset_L;
  input valid_in;
  output valid_out;
  input [31:0]data_in;
  output [31:0]data_out;
endmodule
