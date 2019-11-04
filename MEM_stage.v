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
    output [                  1:0] ms_exc_eret_bus,
    //from data-sram
    input  [31                 :0] data_sram_rdata
);

reg         ms_valid;
wire        ms_ready_go;

reg [`ES_TO_MS_BUS_WD -1:0] es_to_ms_bus_r;

wire [31:0] old_es_badvaddr;
wire        old_es_exc     ;
wire [ 7:0] old_es_exc_type;
wire        ms_bd          ;
wire        ms_exc         ;
wire [ 7:0] ms_exc_type    ;
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
assign {old_es_badvaddr,  //135:104
        ms_bd          ,  //103:103
        old_es_exc     ,  //102:102
        old_es_exc_type,  //101:94
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

assign ms_to_ws_bus = {ms_badvaddr    ,  //125:94
                       ms_bd          ,  // 93:93
                       ms_exc         ,  // 92:92
                       ms_exc_type    ,  // 91:84
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
assign forward_ms_bus = {ms_valid && !ms_res_from_cp0,
                         ms_mem_alu_result};

assign ms_exc_eret_bus = {2{ms_valid}} & {ms_exc, ms_eret_flush};

assign ms_ready_go    = 1'b1;
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

assign ms_mem_alu_result = ms_res_from_mem ? mem_result
                                         : ms_alu_result;

// exceptions
assign ms_exc      = old_es_exc || ms_adel;
assign ms_exc_type = old_es_exc_type | {2'h0, ms_adel, 5'h00};
assign ms_badvaddr = (old_es_exc_type[6] || old_es_exc_type[4]) ? old_es_badvaddr : // Address Error on Ins or Store
                     /* AdEL */                                   ms_alu_result;

endmodule
