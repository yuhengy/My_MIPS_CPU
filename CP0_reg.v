`include "mycpu.h"
module CP0_reg(
	input        clk,
	input        rst,

    input  [ 7:0] cp0_addr,
    output [31:0] cp0_rdata,
    input         cp0_wen,
    input  [31:0] cp0_wdata,

    input  [ 6:0] exc_type,
    input  [31:0] PC,
    input         is_slot,

    input  [ 5:0] int_num,
    input  [31:0] bad_vaddr,
    output [31:0] EPC,

    output        int_happen,

    input         eret
);
wire [31:0] cp0_addr_d;
wire        int, adel, ades, sys, bp, ri, ov;
wire        any_exc;
wire [ 4:0] exccode;

wire [31:0] cp0_status;
wire        cp0_status_bev;
reg  [ 7:0] cp0_status_im;
reg         cp0_status_exl;
wire        cp0_status_exl_set, cp0_status_exl_clear;
reg         cp0_status_ie;

wire [31:0] cp0_cause;
reg         cp0_cause_bd;
wire        cp0_cause_bd_wen;
reg         cp0_cause_ti;
wire        cp0_cause_ti_set, cp0_cause_ti_clear;
reg  [ 7:0] cp0_cause_ip;
reg  [ 4:0] cp0_cause_exccode;
wire        cp0_cause_exccode_wen;

reg  [31:0] cp0_epc;
wire        cp0_epc_wen;
reg [ 31:0] cp0_badvaddr;
wire        cp0_badvaddr_wen;
reg         tick;
reg  [31:0] cp0_count;
reg  [31:0] cp0_compare;


//soft access
decoder_5_32 u_dec2(.in(cp0_addr[7:3]), .out(cp0_addr_d));

assign cp0_rdata = {32{cp0_addr_d[`BADVADDR_NUM]}} & cp0_badvaddr
                 | {32{cp0_addr_d[`STATUS_NUM]}}   & cp0_status
                 | {32{cp0_addr_d[`COUNT_NUM]}}    & cp0_count
                 | {32{cp0_addr_d[`COMPARE_NUM]}}  & cp0_compare
                 | {32{cp0_addr_d[`CAUSE_NUM]}}    & cp0_cause
                 | {32{cp0_addr_d[`EPC_NUM]}}      & cp0_epc;

//exc int info
assign {int, adel, ades, sys, bp, ri, ov} = exc_type;
assign any_exc = |exc_type;
assign exccode = {5{int}}  & 5'h00
               | {5{adel}} & 5'h04
               | {5{ades}} & 5'h05
               | {5{sys}}  & 5'h08
               | {5{bp}}   & 5'h09
               | {5{ri}}   & 5'h0a
               | {5{ov}}   & 5'h0c;

assign int_happen = !cp0_status_exl && cp0_status_ie
                 && (|(cp0_status_im & cp0_cause_ip));

//cp0 regs
	//status
assign cp0_status = {9'h0, cp0_status_bev, 6'h0, cp0_status_im, 6'h0, cp0_status_exl, cp0_status_ie};

assign cp0_status_bev = 1'b1;

always @(posedge clk) begin
	if(cp0_wen && cp0_addr_d[`STATUS_NUM] && cp0_addr[2:0]==3'h0)
		cp0_status_im  <= cp0_wdata[15:8];
end

assign cp0_status_exl_set = any_exc;
assign cp0_status_exl_clear = eret;
always @(posedge clk) begin
	if(rst)
		cp0_status_exl <= 1'b0;
	else if(cp0_status_exl_set)
		cp0_status_exl <= 1'b1;
	else if(cp0_status_exl_clear)
		cp0_status_exl <= 1'b0;
	else if(cp0_wen && cp0_addr_d[`STATUS_NUM] && cp0_addr[2:0]==3'h0)
		cp0_status_exl <= cp0_wdata[1];
end

always @(posedge clk)
	if(rst)
		cp0_status_ie  <= 1'b0;
	else if(cp0_wen && cp0_addr_d[`STATUS_NUM] && cp0_addr[2:0]==3'h0)
		cp0_status_ie  <= cp0_wdata[0];

	//cause
assign cp0_cause = {cp0_cause_bd, cp0_cause_ti, 14'h0, cp0_cause_ip, 1'h0, cp0_cause_exccode, 2'h0};

assign cp0_cause_bd_wen = any_exc && !cp0_status_exl;
always @(posedge clk)
	if(rst)
		cp0_cause_bd  <= 1'b0;
	else if(cp0_cause_bd_wen)
		cp0_cause_bd  <= is_slot;

assign cp0_cause_ti_set = cp0_count==cp0_compare;
assign cp0_cause_ti_clear = cp0_wen && cp0_addr_d[`COMPARE_NUM] && cp0_addr[2:0]==3'h0;
always @(posedge clk)
	if(rst)
		cp0_cause_ti  <= 1'b0;
	else if(cp0_cause_ti_clear)
		cp0_cause_ti  <= 1'b0;
	else if(cp0_cause_ti_set)
		cp0_cause_ti  <= 1'b1;

always @(posedge clk)
	if(rst)
		cp0_cause_ip[7:2] <= 6'b0;
	else
		cp0_cause_ip[7:2] <= {int_num[5]|cp0_cause_ti, int_num[4:0]};
always @(posedge clk)
	if(rst)
		cp0_cause_ip[1:0] <= 2'b0;
	else if(cp0_wen && cp0_addr_d[`CAUSE_NUM] && cp0_addr[2:0]==3'h0)
		cp0_cause_ip[1:0] <= cp0_wdata[9:8];

assign cp0_cause_exccode_wen = any_exc;
always @(posedge clk)
	if(rst)
		cp0_cause_exccode <= 1'b0;
	else if(cp0_cause_exccode_wen)
		cp0_cause_exccode <= exccode;

	//epc
assign cp0_epc_wen = any_exc && !cp0_status_exl;
assign EPC = cp0_epc;
always @(posedge clk)
	if(cp0_epc_wen)
		cp0_epc <= is_slot? PC - 3'h4 : PC;
	else if(cp0_wen && cp0_addr_d[`EPC_NUM] && cp0_addr[2:0]==3'h0)
		cp0_epc <= cp0_wdata;

	//badvaddr
assign cp0_badvaddr_wen = adel;
always @(posedge clk)
	if(cp0_badvaddr_wen)
		cp0_badvaddr <= bad_vaddr;

	//count
always @(posedge clk)
	if(rst) tick <= 1'b0;
	else    tick <= ~tick;
always @(posedge clk)
	if(cp0_wen && cp0_addr_d[`COUNT_NUM] && cp0_addr[2:0]==3'h0)
		cp0_count <= cp0_count + 1'b1;

	//compare
always @(posedge clk)
	if(cp0_wen && cp0_addr_d[`COMPARE_NUM] && cp0_addr[2:0]==3'h0)
		cp0_compare <= cp0_wdata;


endmodule
