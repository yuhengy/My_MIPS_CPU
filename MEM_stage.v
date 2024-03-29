`include "mycpu.h"

module mem_stage(
    input                          clk           ,
    input                          reset         ,
    input                          flush         ,
    //allowin
    input                          ws_allowin    ,
    output                         ms_allowin    ,
    //from es
    input                          es_to_ms_valid,
    input  [`ES_TO_MS_BUS_WD -1:0] es_to_ms_bus  ,
    //to ws
    output                         ms_to_ws_valid,
    output [`MS_TO_WS_BUS_WD -1:0] ms_to_ws_bus  ,
    //ms to id stall
    output [`STALL_BUS_WD    -1:0] stall_ms_bus  ,
    output [`FORWARD_BUS_WD  -1:0] forward_ms_bus,
    //ms to es exc/eret bus
    output [                  2:0] ms_exc_eret_bus,
    //TLBP stall
    output                         ms_entryhi_hazard,
    //from data-sram
    input                          data_sram_data_ok,
    input  [31                 :0] data_sram_rdata
);

reg         ms_valid;
wire        ms_ready_go;

reg [`ES_TO_MS_BUS_WD -1:0] es_to_ms_bus_r;

wire        ms_tlb_flush   ;
wire        ms_inst_tlbr   ;
wire        ms_inst_tlbwi  ;
wire        ms_inst_tlbp   ;
wire [31:0] ms_cp0_index_wdata;
wire        ms_store_op    ;
wire        old_es_exc     ;
wire [14:0] old_es_exc_type;
wire        ms_bd          ;
wire        ms_exc         ;
wire [14:0] ms_exc_type    ;
wire        ms_eret_flush  ;
wire        ms_cp0_wen     ;
wire        ms_res_from_cp0;
wire [ 7:0] ms_cp0_addr    ;
wire        ms_res_from_mem;
wire [ 6:0] ms_inst_load   ;
wire [ 3:0] ms_ld_rshift_op;
wire [ 4:0] ms_ld_extd_op  ;
wire        ms_gr_we_1     ;
wire [ 3:0] ms_gr_we       ;
wire [ 4:0] ms_dest        ;
wire [31:0] ms_alu_result  ;
wire [31:0] ms_pc          ;
assign {ms_tlb_flush   ,  //147:147
        ms_inst_tlbr   ,  //146:146
        ms_inst_tlbwi  ,  //145:145
        ms_inst_tlbp   ,  //144:144
        ms_cp0_index_wdata,//143:112
        ms_store_op    ,  //111:111
        ms_bd          ,  //110:110
        old_es_exc     ,  //109:109
        old_es_exc_type,  //108:94
        ms_eret_flush  ,  //93:93
        ms_cp0_wen     ,  //92:92
        ms_res_from_cp0,  //91:91
        ms_cp0_addr    ,  //90:83
        ms_res_from_mem,  //82:82
        ms_inst_load   ,  //81:75
        ms_ld_extd_op  ,  //74:70
        ms_gr_we_1     ,  //69:69
        ms_dest        ,  //68:64
        ms_alu_result  ,  //63:32
        ms_pc             //31:0
       } = es_to_ms_bus_r;

wire [31:0] ms_badvaddr;
wire [31:0] mem_result;
wire [31:0] ms_mem_alu_result;
wire        ms_entryhi_wen;
wire [31:0] ms_tlbp_index;

assign ms_to_ws_bus = {ms_tlb_flush   ,  //169:169
                       ms_tlbp_index  ,  //168:137
                       ms_entryhi_wen ,  //136:136
                       ms_inst_tlbr   ,  //135:135
                       ms_inst_tlbwi  ,  //134:134
                       ms_inst_tlbp   ,  //133:133
                       ms_badvaddr    ,  //132:101
                       ms_bd          ,  //100:100
                       ms_exc         ,  // 99:99
                       ms_exc_type    ,  // 98:84
                       ms_eret_flush  ,  // 83:83
                       ms_cp0_wen     ,  // 82:82
                       ms_res_from_cp0,  // 81:81
                       ms_cp0_addr    ,  // 80:73
                       ms_gr_we       ,  // 72:69
                       ms_dest        ,  // 68:64
                       ms_mem_alu_result,// 63:32
                       ms_pc             // 31: 0
                      };

assign stall_ms_bus = {ms_valid && ms_gr_we_1, {4{ms_valid}} & ms_gr_we,
                       ms_dest};
assign forward_ms_bus = {ms_to_ws_valid && !ms_res_from_cp0,
                         ms_mem_alu_result};

assign ms_exc_eret_bus = {3{ms_valid}} & {ms_tlb_flush, ms_exc, ms_eret_flush};

assign ms_tlbp_index = ms_cp0_index_wdata;

wire        old_es_tlb_exc;

assign  old_es_tlb_exc = |(old_es_exc_type[12:8]);

assign ms_ready_go    = !((ms_res_from_mem || ms_store_op) && !old_es_tlb_exc && !data_sram_data_ok);
assign ms_allowin     = !ms_valid || ms_ready_go && ws_allowin;
assign ms_to_ws_valid = ms_valid && ms_ready_go;
always @(posedge clk) begin
    if (reset) begin
        ms_valid <= 1'b0;
    end
    else if (flush) begin
        ms_valid <= 1'b0;
    end
    else if (ms_allowin) begin
        ms_valid <= es_to_ms_valid;
    end
    if (es_to_ms_valid && ms_allowin) begin
        es_to_ms_bus_r <= es_to_ms_bus;
    end
end

wire    ms_adel;

ld_decode u_ld_decode(
    .inst_load(ms_inst_load),
    .addr(ms_alu_result[1:0]),
    .gr_we_1(ms_gr_we_1),

    .ld_rshift_op(ms_ld_rshift_op),
    .gr_we(ms_gr_we),
    .adel(ms_adel)
);

ld_select u_ld_select(
    .ld_rshift_op    (ms_ld_rshift_op),
    .ld_extd_op      (ms_ld_extd_op  ),
    .data_sram_rdata (data_sram_rdata),

    .mem_result      (mem_result     )
);

assign ms_mem_alu_result = ms_res_from_mem ? mem_result :
                                             ms_alu_result;

assign ms_entryhi_hazard = ms_valid && ms_entryhi_wen;

assign ms_entryhi_wen = ms_inst_tlbr ||
                    ms_cp0_wen && (ms_cp0_addr == {`ENTRYHI_NUM, 3'b0});

// exceptions
assign ms_exc      = old_es_exc || ms_adel;
assign ms_exc_type = old_es_exc_type | {9'h0, ms_adel, 5'h00};
assign ms_badvaddr = (old_es_exc_type[14] || old_es_exc_type[13] || old_es_exc_type[6]) ? ms_pc :   // TLB / Address Error on Ins
                     /* Data */           ms_alu_result;

endmodule
