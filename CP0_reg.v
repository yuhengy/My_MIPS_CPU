`include "mycpu.h"
module CP0_reg #
(
	parameter TLBNUM = 16
)
(
	input        clk,
	input        rst,

    input  [ 7:0] cp0_addr,
    output [31:0] cp0_rdata,
    input         cp0_wen,
    input  [31:0] cp0_wdata,

    input  [ 7:0] exc_type,
    input  [31:0] PC,
    input         is_slot,

    input  [ 5:0] int_num,
    input  [31:0] bad_vaddr,
    output [31:0] EPC,

    output        int_happen,
    input         eret,

    //tlbp
    input         tlbp_wen,
    output [31:0] tlbp_entryhi,
    input  [31:0] tlbp_index,
    //input Index use cp0_wdata

    //tlbr
    output [$clog2(TLBNUM)-1:0] tlb_index,
    input         tlbr_wen,
    input  [77:0] tlbr_entry,

    //tlbwi
    //output Index use tlb_index
    output [77:0] tlbwi_entry
);

wire [31:0] cp0_addr_d;
wire        int, rine, rdae, ades, sys, bp, ri, ov;
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
reg  [31:0] cp0_badvaddr;
wire        cp0_badvaddr_wen;
reg  [32:0] cp0_count;
reg  [31:0] cp0_compare;

//tlb
reg  [31:0] cp0_index;
reg  [31:0] cp0_entryhi;
reg  [31:0] cp0_entrylo1;
reg  [31:0] cp0_entrylo0;

//soft access
decoder_5_32 u_dec2(.in(cp0_addr[7:3]), .out(cp0_addr_d));

assign cp0_rdata = {32{cp0_addr_d[`BADVADDR_NUM]}} & cp0_badvaddr
                 | {32{cp0_addr_d[`STATUS_NUM]}}   & cp0_status
                 | {32{cp0_addr_d[`COUNT_NUM]}}    & cp0_count[32:1]
                 | {32{cp0_addr_d[`COMPARE_NUM]}}  & cp0_compare
                 | {32{cp0_addr_d[`CAUSE_NUM]}}    & cp0_cause
                 | {32{cp0_addr_d[`EPC_NUM]}}      & cp0_epc

                 | {32{cp0_addr_d[`INDEX_NUM]}}    & cp0_index
                 | {32{cp0_addr_d[`ENTRYHI_NUM]}}  & cp0_entryhi
                 | {32{cp0_addr_d[`ENTRYLO1_NUM]}} & cp0_entrylo1
                 | {32{cp0_addr_d[`ENTRYLO0_NUM]}} & cp0_entrylo0;

//exc int info
assign {int, rine, rdae, ades, sys, bp, ri, ov} = exc_type;
assign any_exc = |exc_type;
assign exccode = int  ? 5'h00 :
                 rine ? 5'h04 :
                 ri   ? 5'h0a :
                 sys  ? 5'h08 :
                 bp   ? 5'h09 :
                 ov   ? 5'h0c :
                 rdae ? 5'h04 :
           /* ades */   5'h05 ;

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

assign cp0_cause_ti_set = cp0_count[32:1]==cp0_compare;
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
assign cp0_badvaddr_wen = rine | rdae | ades;
always @(posedge clk)
	if(cp0_badvaddr_wen)
		cp0_badvaddr <= bad_vaddr;

	//count
always @(posedge clk)
	if(cp0_wen && cp0_addr_d[`COUNT_NUM] && cp0_addr[2:0]==3'h0)
		cp0_count <= {cp0_wdata, 1'b0};
	else
		cp0_count <= cp0_count + 1'b1;

	//compare
always @(posedge clk)
	if(cp0_wen && cp0_addr_d[`COMPARE_NUM] && cp0_addr[2:0]==3'h0)
		cp0_compare <= cp0_wdata;

//tlb
assign tlbp_entryhi = cp0_entryhi;
assign tlb_index    = cp0_index[$clog2(TLBNUM)-1:0];
assign tlbwi_entry  = {cp0_entryhi [31:13],
	                   cp0_entryhi [ 7: 0],
	                   cp0_entrylo1[0] && cp0_entrylo0[0],
	                   cp0_entrylo0[25: 1],
	                   cp0_entrylo1[25: 1]};

always @(posedge clk)
	if(rst)
		cp0_index[31:$clog2(TLBNUM)] <= {(32-$clog2(TLBNUM)){1'h0}};  //???rst 31?
	else if(tlbp_wen)
		cp0_index <= tlbp_index;
	else if(cp0_wen && cp0_addr_d[`INDEX_NUM] && cp0_addr[2:0]==3'h0)
		cp0_index[$clog2(TLBNUM)-1:0] <= cp0_wdata[$clog2(TLBNUM)-1:0];

always @(posedge clk)
	if(rst)
		cp0_entryhi[12:8] <= 5'h0;
	else if(tlbr_wen)
		cp0_entryhi <= {tlbr_entry[77:59], 5'h0, tlbr_entry[58:51]};
	else if(cp0_wen && cp0_addr_d[`ENTRYHI_NUM] && cp0_addr[2:0]==3'h0) begin
		cp0_entryhi[31:13] <= cp0_wdata[31:13];
		cp0_entryhi[ 7: 0] <= cp0_wdata[ 7: 0];
	end	

always @(posedge clk)
	if(rst)
		cp0_entrylo1[31:30] <= 2'h0;
	else if(tlbr_wen)
		cp0_entrylo1 <= {6'h0, tlbr_entry[24:0], tlbr_entry[50]};
	else if(cp0_wen && cp0_addr_d[`ENTRYLO1_NUM] && cp0_addr[2:0]==3'h0)
		cp0_entrylo1[29:0] <= cp0_wdata[29:0];

always @(posedge clk)
	if(rst)
		cp0_entrylo0[31:30] <= 2'h0;
	else if(tlbr_wen)
		cp0_entrylo0 <= {6'h0, tlbr_entry[50:25], tlbr_entry[50]};
	else if(cp0_wen && cp0_addr_d[`ENTRYLO0_NUM] && cp0_addr[2:0]==3'h0)
		cp0_entrylo0[29:0] <= cp0_wdata[29:0];



















endmodule
