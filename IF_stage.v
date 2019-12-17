`include "mycpu.h"

module if_stage(
    input                          clk            ,
    input                          reset          ,
    input                          flush          ,
    //allwoin
    input                          ds_allowin     ,
    //brbus
    input  [`BR_BUS_WD       -1:0] br_bus         ,
    //exceretbus
    input  [`EXC_ERET_BUS_WD -1:0] exc_eret_bus   ,
    //to ds
    output                         fs_to_ds_valid ,
    output [`FS_TO_DS_BUS_WD -1:0] fs_to_ds_bus   ,

    //TLB V2P
    output [                 19:0] inst_vpn2_odd  ,
    input  [                 19:0] inst_pfn       ,
    input                          TLB_refil_inst ,
    input                          TLB_inval_inst ,

    // inst sram interface
    output        inst_sram_req  ,
    output [ 3:0] inst_sram_wen  ,
    output [31:0] inst_sram_addr ,
    output [31:0] inst_sram_wdata,
    input         inst_sram_addr_ok,
    input         inst_sram_data_ok,
    input  [31:0] inst_sram_rdata
);

reg         fs_valid;
wire        fs_ready_go;
wire        fs_allowin;
wire        to_fs_valid;

wire [31:0] seq_pc;
wire [31:0] nextpc;

reg         buf_npc_valid;
reg  [31:0] buf_npc;
wire [31:0] true_npc;

wire         br_bd;
wire         fs_bd;
wire         br_taken;
wire [ 31:0] br_target;
assign {br_bd, br_taken,br_target} = br_bus;

wire        fs_exc;
wire [ 7:0] fs_exc_type;
wire [31:0] fs_inst;
reg  [31:0] fs_pc;
assign fs_to_ds_bus = {fs_bd   ,
                       fs_exc  ,
                       fs_exc_type,
                       fs_inst ,
                       fs_pc   };

reg         buf_inst_valid;
reg  [31:0] buf_inst;

reg         buf_bd;
reg         buf_bd_valid;

wire         fs_adel;   // Address Error on IF

//exc eret bus
wire         nextpc_is_TLBrefill;
wire         nextpc_is_exc;
wire         nextpc_is_epc;
wire [31:0]  epc;
assign {nextpc_is_TLBrefill, nextpc_is_exc, nextpc_is_epc, epc} = exc_eret_bus;

// pre-IF stage
assign to_fs_valid  = ~reset;
assign seq_pc       = fs_pc + 3'h4;
assign nextpc       = nextpc_is_TLBrefill? 32'hbfc00200:
                      nextpc_is_exc? 32'hbfc00380:
                      nextpc_is_epc? epc         :
                      br_taken     ? br_target   : 
                                     seq_pc      ; 
assign true_npc = (buf_npc_valid&&!flush) ? buf_npc : nextpc;

always @(posedge clk) begin
    if (reset) begin
        buf_npc_valid <= 0;
    end
    else if (to_fs_valid && fs_allowin || flush) begin
        buf_npc_valid <= 0;
    end
    else if (!buf_npc_valid && ds_allowin) begin
        buf_npc_valid <= 1;
    end

    if (!buf_npc_valid && ds_allowin) begin
        buf_npc <= nextpc;
    end
end

//when flush, may ignore next inst_sram_data_ok
//limitaion: only one inst_req on fly
reg ignore_next_inst_sram_data_ok;
wire inst_sram_data_ok_after_ignore;
always @(posedge clk)
    if(reset)
        ignore_next_inst_sram_data_ok <= 1'h0;
    //not havegot_notgetting_last_inst_sram_data_ok && not getting_inst_sram_data_ok
    else if(flush && !buf_inst_valid && !(inst_sram_data_ok || pre_IF_TLB_refil || pre_IF_TLB_inval))
        ignore_next_inst_sram_data_ok <= 1'h1;
    else if(inst_sram_data_ok || pre_IF_TLB_refil || pre_IF_TLB_inval)
        ignore_next_inst_sram_data_ok <= 1'h0;
assign inst_sram_data_ok_after_ignore = (inst_sram_data_ok || pre_IF_TLB_refil || pre_IF_TLB_inval) && !ignore_next_inst_sram_data_ok;

//TLB exception
wire inst_unmapped;
reg  pre_IF_TLB_refil, pre_IF_TLB_inval;
reg  fs_TLB_refil    , fs_TLB_inval    ;
assign inst_unmapped = true_npc[31:30]==4'b10;
always @(posedge clk)
    if(reset)
        pre_IF_TLB_refil <= 1'h0;
    else if(to_fs_valid && fs_allowin || flush)
        pre_IF_TLB_refil <= TLB_refil_inst && !inst_unmapped;
    else if(pre_IF_TLB_refil)
        pre_IF_TLB_refil <= 1'h0;
always @(posedge clk)
    if(reset)
        pre_IF_TLB_inval <= 1'h0;
    else if(to_fs_valid && fs_allowin || flush)
        pre_IF_TLB_inval <= TLB_inval_inst && !inst_unmapped;
    else if(pre_IF_TLB_inval)
        pre_IF_TLB_inval <= 1'h0;
always @(posedge clk)
    if(reset)
        fs_TLB_refil <= 1'h0;
    else if(to_fs_valid && fs_allowin || flush)
        fs_TLB_refil <= TLB_refil_inst && !inst_unmapped;
always @(posedge clk)
    if(reset)
        fs_TLB_inval <= 1'h0;
    else if(to_fs_valid && fs_allowin || flush)
        fs_TLB_inval <= TLB_inval_inst && !inst_unmapped;


// IF stage
assign fs_ready_go    = inst_sram_data_ok_after_ignore || buf_inst_valid;
assign fs_allowin     = !fs_valid || fs_ready_go && ds_allowin;
assign fs_to_ds_valid =  fs_valid && fs_ready_go;
always @(posedge clk) begin
    if (reset) begin
        fs_valid <= 1'b0;
    end
    else if (flush) begin
        fs_valid <= 1'b1;
    end
    else if (fs_allowin) begin
        fs_valid <= to_fs_valid;
    end

    if (reset) begin
        fs_pc <= 32'hbfbffffc;  //trick: to make nextpc be 0xbfc00000 during reset 
    end
    else if (to_fs_valid && fs_allowin || flush) begin
        fs_pc <= true_npc;
    end
end


assign inst_sram_req   = (to_fs_valid && fs_allowin || flush) && !((TLB_refil_inst||TLB_inval_inst) && !inst_unmapped);
assign inst_sram_wen   = 4'h0;
assign inst_sram_addr  = inst_unmapped ? {3'h0, true_npc[28:0]} : {inst_pfn, true_npc[11:0]};
assign inst_sram_wdata = 32'b0;

assign fs_inst         = buf_inst_valid ? buf_inst : inst_sram_rdata;

always @(posedge clk) begin
    if (reset) begin
        buf_inst_valid <= 0;
    end
    else if (fs_to_ds_valid && ds_allowin || flush) begin
        buf_inst_valid <= 0;
    end
    else if (inst_sram_data_ok_after_ignore /*&& !flush*/) begin
        buf_inst_valid <= 1;
    end

    if (inst_sram_data_ok_after_ignore) begin
        buf_inst <= inst_sram_rdata;
    end
end

assign fs_bd = buf_bd_valid ? buf_bd : br_bd;

always @(posedge clk) begin
    if (reset) begin
        buf_bd_valid <= 0;
    end
    else if (fs_to_ds_valid && ds_allowin || flush) begin
        buf_bd_valid <= 0;
    end
    else if (!buf_bd_valid) begin
        buf_bd_valid <= 1;
    end

    if (!buf_bd_valid) begin
        buf_bd <= br_bd;
    end
end

//exc
assign fs_exc      = |fs_exc_type;
assign fs_exc_type = {fs_TLB_refil, fs_TLB_inval, 6'h0, fs_adel, 6'h0};

assign fs_adel     = !(fs_pc[1:0] == 2'b00);

endmodule
