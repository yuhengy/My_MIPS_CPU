`include "mycpu.h"

module wb_stage #
(
    parameter TLBNUM = 16
)
(
    input                           clk           ,
    input                           reset         ,
    input  [5:0]                    ext_int_in    ,
    output                          int_happen    ,
    input                           flush         ,
    //allowin
    output                          ws_allowin    ,
    //from ms
    input                           ms_to_ws_valid,
    input  [`MS_TO_WS_BUS_WD -1:0]  ms_to_ws_bus  ,
    //to rf: for write back
    output [`WS_TO_RF_BUS_WD -1:0]  ws_to_rf_bus  ,
    //ws to id stall
    output [`STALL_BUS_WD    -1:0]  stall_ws_bus  ,
    output [`FORWARD_BUS_WD  -1:0]  forward_ws_bus,
    output                          send_flush    ,
    output                          send_tlb_flush,
    //wb exc eret
    output [                  2:0]  ws_exc_eret_bus,
    //exc_eret_epc bus
    output [`EXC_ERET_BUS_WD -1:0]  exc_eret_bus  ,

    // Stall: TLBP
    output                          ws_entryhi_hazard,
    output [                 31:0]  ws_entryhi,
    //TLBR、TLBWI
    output [   $clog2(TLBNUM)-1:0]  ws_tlb_index   ,
    output                          ws_tlb_wen     ,
    input  [    `TLB_ENTRY_WD-1:0]  ws_tlbr_entry  ,
    output [    `TLB_ENTRY_WD-1:0]  ws_tlbwi_entry ,

    //trace debug interface
    output [31:0] debug_wb_pc     ,
    output [ 3:0] debug_wb_rf_wen ,
    output [ 4:0] debug_wb_rf_wnum,
    output [31:0] debug_wb_rf_wdata
);

reg         ws_valid;
wire        ws_ready_go;

reg [`MS_TO_WS_BUS_WD -1:0] ms_to_ws_bus_r;

wire        ws_tlb_flush   ;
wire [31:0] ws_tlbp_index  ;
wire        ws_entryhi_wen ;
wire        ws_inst_tlbr   ;
wire        ws_inst_tlbwi  ;
wire        ws_inst_tlbp   ;
wire [31:0] ws_badvaddr    ;
wire        ws_bd          ;
wire        ws_exc         ;
wire [14:0] ws_exc_type    ;
wire        ws_eret_flush  ;
wire        ws_cp0_wen     ;
wire        ws_res_from_cp0;
wire [ 7:0] ws_cp0_addr    ;
wire [ 3:0] ws_gr_we       ;
wire [ 4:0] ws_dest        ;
wire [31:0] ws_mem_alu_result;
wire [31:0] ws_final_result;
wire [31:0] ws_pc          ;
assign {ws_tlb_flush   ,  //169:169
        ws_tlbp_index  ,  //168:137
        ws_entryhi_wen ,  //136:136
        ws_inst_tlbr   ,  //135:135
        ws_inst_tlbwi  ,  //134:134
        ws_inst_tlbp   ,  //133:133
        ws_badvaddr    ,  //132:101
        ws_bd          ,  //100:100
        ws_exc         ,  // 99:99
        ws_exc_type    ,  // 98:84
        ws_eret_flush  ,  // 83:83
        ws_cp0_wen     ,  // 82:82
        ws_res_from_cp0,  // 81:81
        ws_cp0_addr    ,  // 80:73
        ws_gr_we       ,  // 72:69
        ws_dest        ,  // 68:64
        ws_mem_alu_result,// 63:32
        ws_pc             // 31: 0
       } = ms_to_ws_bus_r;

wire [3 :0] rf_we;
wire [4 :0] rf_waddr;
wire [31:0] rf_wdata;
assign ws_to_rf_bus = {rf_we   ,  //40:37
                       rf_waddr,  //36:32
                       rf_wdata   //31:0
                      };

wire [31:0] ws_cp0_rdata;
wire [31:0] ws_cp0_epc;

assign stall_ws_bus = {ws_valid && (|ws_gr_we), {4{ws_valid}} & ws_gr_we,
                       ws_dest};
assign forward_ws_bus = {ws_valid,
                         ws_final_result};

assign ws_exc_eret_bus = {ws_tlb_flush && ws_valid, ws_exc && ws_valid, ws_eret_flush && ws_valid};
assign exc_eret_bus    = {(ws_exc_type[14] || ws_exc_type[12] || ws_exc_type[10]) && ws_valid, ws_exc && ws_valid, ws_eret_flush && ws_valid, ws_cp0_epc};

assign ws_entryhi_hazard = ws_valid && ws_entryhi_wen;

assign ws_ready_go = 1'b1;
assign ws_allowin  = !ws_valid || ws_ready_go;
always @(posedge clk) begin
    if (reset) begin
        ws_valid <= 1'b0;
    end
    else if (flush) begin
        ws_valid <= 1'b0;
    end
    else if (ws_allowin) begin
        ws_valid <= ms_to_ws_valid;
    end
    if (ms_to_ws_valid && ws_allowin) begin
        ms_to_ws_bus_r <= ms_to_ws_bus;
    end
end

assign rf_we    = ws_gr_we & {4{ws_valid}} & {4{!ws_exc}};
assign rf_waddr = ws_dest;
assign rf_wdata = ws_final_result;

CP0_reg u_CP0_reg(
    .clk         (clk                        ),
    .rst         (reset                      ),

    .cp0_addr    (ws_cp0_addr                ),
    .cp0_wen     (ws_valid && ws_cp0_wen     ),
    .cp0_wdata   (ws_mem_alu_result          ),

    .cp0_rdata   (ws_cp0_rdata               ),

    .exc_type    ({15{ws_valid}} & ws_exc_type),
    .PC          (ws_pc                      ),
    .is_slot     (ws_bd                      ),
    .int_num     (ext_int_in                 ),
    .bad_vaddr   (ws_badvaddr                ),

    .EPC         (ws_cp0_epc                 ),
    .int_happen  (int_happen                 ),
    .eret        (ws_valid && ws_eret_flush  ),

    .tlbp_wen    (ws_inst_tlbp && ws_valid),
    .tlbp_entryhi(ws_entryhi),
    .tlbp_index  (ws_tlbp_index),
    .tlb_index   (ws_tlb_index),
    .tlbr_wen    (ws_inst_tlbr && ws_valid),
    .tlbr_entry  (ws_tlbr_entry),
    .tlbwi_entry (ws_tlbwi_entry)
);
assign send_flush = ws_valid && (ws_eret_flush || ws_exc);
assign send_tlb_flush = 1'h0;  //TODO Lab14
assign ws_final_result = ws_res_from_cp0? ws_cp0_rdata:
                                          ws_mem_alu_result;

assign ws_tlb_wen   = ws_inst_tlbwi && ws_valid;
// debug info generate
assign debug_wb_pc       = ws_pc;
assign debug_wb_rf_wen   = rf_we;
assign debug_wb_rf_wnum  = ws_dest;
assign debug_wb_rf_wdata = ws_final_result;

endmodule
