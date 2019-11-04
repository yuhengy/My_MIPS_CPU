`include "mycpu.h"

module wb_stage(
    input                           clk           ,
    input                           reset         ,
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
    //wb exc eret
    output [                  1:0]  ws_exc_eret_bus,
    //exc_eret_epc bus
    output [`EXC_ERET_BUS_WD -1:0]  exc_eret_bus  ,
    //trace debug interface
    output [31:0] debug_wb_pc     ,
    output [ 3:0] debug_wb_rf_wen ,
    output [ 4:0] debug_wb_rf_wnum,
    output [31:0] debug_wb_rf_wdata
);

reg         ws_valid;
wire        ws_ready_go;

reg [`MS_TO_WS_BUS_WD -1:0] ms_to_ws_bus_r;

wire [31:0] ws_badvaddr    ;
wire        ws_bd          ;
wire        ws_exc         ;
wire [ 7:0] ws_exc_type    ;
wire        ws_eret_flush  ;
wire        ws_cp0_wen     ;
wire        ws_res_from_cp0;
wire [ 7:0] ws_cp0_addr    ;
wire [ 3:0] ws_gr_we       ;
wire [ 4:0] ws_dest        ;
wire [31:0] ws_mem_alu_result;
wire [31:0] ws_final_result;
wire [31:0] ws_pc          ;
assign {ws_badvaddr    ,  //125:94
        ws_bd          ,  // 93:93
        ws_exc         ,  // 92:92
        ws_exc_type    ,  // 91:84
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

assign ws_exc_eret_bus = {ws_exc && ws_valid, ws_eret_flush && ws_valid};
assign exc_eret_bus    = {ws_exc && ws_valid, ws_eret_flush && ws_valid, ws_cp0_epc};

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

assign rf_we    = ws_gr_we & {4{ws_valid}};
assign rf_waddr = ws_dest;
assign rf_wdata = ws_final_result;

CP0_reg u_CP0_reg(
    .clk        (clk                        ),
    .rst        (reset                      ),

    .cp0_addr   (ws_cp0_addr                ),
    .cp0_wen    (ws_valid && ws_cp0_wen     ),
    .cp0_wdata  (ws_mem_alu_result          ),

    .cp0_rdata  (ws_cp0_rdata               ),

    .exc_type   ({8{ws_valid}} & ws_exc_type),
    .PC         (ws_pc                      ),
    .is_slot    (ws_bd                      ),
    .int_num    (0                          ),
    .bad_vaddr  (ws_badvaddr                ),

    .EPC        (ws_cp0_epc                 ),
    .int_happen (                           ),
    .eret       (ws_valid && ws_eret_flush  )
);
assign send_flush = ws_valid && (ws_eret_flush || ws_exc);
assign ws_final_result = ws_res_from_cp0? ws_cp0_rdata:
                                          ws_mem_alu_result;

// debug info generate
assign debug_wb_pc       = ws_pc;
assign debug_wb_rf_wen   = rf_we;
assign debug_wb_rf_wnum  = ws_dest;
assign debug_wb_rf_wdata = ws_final_result;

endmodule
