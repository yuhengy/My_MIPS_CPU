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

wire         fs_bd;
wire         br_taken;
wire [ 31:0] br_target;
assign {fs_bd, br_taken,br_target} = br_bus;

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

wire         fs_adel;   // Address Error on IF

//exc eret bus
wire         nextpc_is_exc;
wire         nextpc_is_epc;
wire [31:0]  epc;
assign {nextpc_is_exc, nextpc_is_epc, epc} = exc_eret_bus;

// pre-IF stage
assign to_fs_valid  = ~reset;
assign seq_pc       = fs_pc + 3'h4;
assign nextpc       = nextpc_is_exc? 32'hbfc00380:
                      nextpc_is_epc? epc         :
                      br_taken     ? br_target   : 
                                     seq_pc      ; 
assign true_npc = buf_npc_valid ? buf_npc : nextpc;

always @(posedge clk) begin
    if (reset) begin
        buf_npc_valid <= 0;
    end
    else if (to_fs_valid && fs_allowin) begin
        buf_npc_valid <= 0;
    end
    else if (!buf_npc_valid) begin
        buf_npc_valid <= 1;
    end

    if (!buf_npc_valid) begin
        buf_npc <= nextpc;
    end
end

// IF stage
assign fs_ready_go    = inst_sram_data_ok;
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
        fs_pc <= nextpc;
    end
end

assign inst_sram_req   = to_fs_valid && fs_allowin || flush;
assign inst_sram_wen   = 4'h0;
assign inst_sram_addr  = true_npc;
assign inst_sram_wdata = 32'b0;

assign fs_inst         = buf_inst_valid ? buf_inst : inst_sram_rdata;

always @(posedge clk) begin
    if (reset) begin
        buf_inst_valid <= 0;
    end
    else if (fs_to_ds_valid && ds_allowin) begin
        buf_inst_valid <= 0;
    end
    else if (!buf_inst_valid) begin
        buf_inst_valid <= 1;
    end

    if (!buf_inst_valid) begin
        buf_inst <= inst_sram_rdata;
    end
end

//exc
assign fs_exc      = |fs_exc_type;
assign fs_exc_type = {1'b0, fs_adel, 6'h00};

assign fs_adel     = !(fs_pc[1:0] == 2'b00);

endmodule
