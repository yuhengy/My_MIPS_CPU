`include "mycpu.h"

module exe_stage #
(
    parameter TLBNUM = 16
)
(
    input                          clk           ,
    input                          reset         ,
    input                          flush         ,
    //allowin
    input                          ms_allowin    ,
    output                         es_allowin    ,
    //from ds
    input                          ds_to_es_valid,
    input  [`DS_TO_ES_BUS_WD -1:0] ds_to_es_bus  ,
    //to ms
    output                         es_to_ms_valid,
    output [`ES_TO_MS_BUS_WD -1:0] es_to_ms_bus  ,
    //es to id stall
    output [`STALL_BUS_WD    -1:0] stall_es_bus  ,
    output [`FORWARD_BUS_WD  -1:0] forward_es_bus,
    //ms, ws exc
    input  [                  5:0] es_exc_eret_bus,
    // TLB Probe
    output                      tlbp_valid,
    input                       tlbp_found,
    input  [$clog2(TLBNUM)-1:0] tlbp_index,
    input  [               1:0] entryhi_stall_bus,

    //TLB V2P
    output [                 19:0] data_vpn2_odd  ,
    output                         exe_store      ,
    input  [                 19:0] data_pfn       ,
    input                          TLB_refil_dr   ,
    input                          TLB_inval_dr   ,
    input                          TLB_refil_ds   ,
    input                          TLB_inval_ds   ,
    input                          TLB_exec_Mod   ,

    // data sram interface
    output        data_sram_req  ,
    output        data_sram_wr   ,
    output [ 3:0] data_sram_wen  ,
    output [31:0] data_sram_addr ,
    output [31:0] data_sram_wdata,
    input         data_sram_addr_ok
);

reg         es_valid      ;
wire        es_ready_go   ;

reg  [`DS_TO_ES_BUS_WD -1:0] ds_to_es_bus_r;

wire        es_inst_tlbr  ;
wire        es_inst_tlbwi ;
wire        es_inst_tlbp  ;
wire        es_store_op   ;
wire        es_ov_check   ; // Need to check ALU Overflow
wire        es_bd         ;
wire        es_ms_ws_exc_eret;
wire        old_ds_exc    ;
wire [14:0] old_ds_exc_type;
wire        es_exc        ;
wire [14:0] es_exc_type   ;
wire        es_eret_flush ;
wire        es_cp0_wen    ;
wire        es_res_from_cp0;
wire [ 7:0] es_cp0_addr   ;
wire        es_hl_from_rs ;
wire [ 6:0] es_inst_load  ;
wire [ 4:0] es_inst_store ;
wire [11:0] es_alu_op     ;
wire [ 1:0] es_mul_op     ;
wire [ 1:0] es_div_op     ;
wire        es_load_op    ;
wire [ 4:0] es_ld_extd_op ;
wire [ 3:0] es_st_rshift_op;
wire        es_src1_is_sa ;  
wire        es_src1_is_pc ;
wire        es_src1_is_hi ;
wire        es_src1_is_lo ;
wire        es_src1_is_0  ;
wire        es_src2_is_imm;
wire        es_src2_is_uimm; 
wire        es_src2_is_8  ;
wire        es_gr_we      ;
wire        es_hi_we      ;
wire        es_lo_we      ;
wire [ 3:0] es_mem_we     ;
wire [ 4:0] es_dest       ;
wire [15:0] es_imm        ;
wire [31:0] es_rs_value   ;
wire [31:0] es_rt_value   ;
wire [31:0] es_pc         ;
assign {es_inst_tlbr   ,  //194:194
        es_inst_tlbwi  ,  //193:193
        es_inst_tlbp   ,  //192:192
        es_ov_check    ,  //191:191
        es_bd          ,  //190:190
        old_ds_exc     ,  //189:189
        old_ds_exc_type,  //188:174
        es_eret_flush  ,  //173:173
        es_cp0_wen     ,  //172:172
        es_res_from_cp0,  //171:171
        es_cp0_addr    ,  //170:163
        es_hl_from_rs  ,  //162:162
        es_inst_load   ,  //161:155
        es_inst_store  ,  //154:150
        es_alu_op      ,  //149:138
        es_mul_op      ,  //137:136
        es_div_op      ,  //135:134
        es_load_op     ,  //133:133
        es_ld_extd_op  ,  //132:128
        es_src1_is_sa  ,  //127:127
        es_src1_is_pc  ,  //126:126
        es_src1_is_hi  ,  //125:125
        es_src1_is_lo  ,  //124:124
        es_src1_is_0   ,  //123:123
        es_src2_is_imm ,  //122:122
        es_src2_is_uimm,  //121:121
        es_src2_is_8   ,  //120:120
        es_gr_we       ,  //119:119
        es_hi_we       ,  //118:118
        es_lo_we       ,  //117:117
        es_dest        ,  //116:112
        es_imm         ,  //111:96
        es_rs_value    ,  //95 :64
        es_rt_value    ,  //63 :32
        es_pc             //31 :0
       } = ds_to_es_bus_r;


wire [31:0] es_alu_src1   ;
wire [31:0] es_alu_src2   ;
wire [31:0] es_alu_result ;
wire        es_alu_ov     ; // ALU Overflow
wire [63:0] es_mul_result ;
wire [63:0] es_div_result ;
wire [63:0] es_hl_result  ;

wire        es_div_out_valid;
wire        es_hl_res_valid;
wire        es_res_from_mem;
wire        es_res_from_mul;
wire        es_res_from_div;

reg [31:0] hi;
reg [31:0] lo;

wire        hi_we;
wire        lo_we;
wire [31:0] hi_wdata;
wire [31:0] lo_wdata;

wire [31:0] es_cp0_index_wdata;
wire [ 7:0] es_cp0_real_addr;

assign es_res_from_mem = es_load_op;
assign es_res_from_mul = es_mul_op[0] | es_mul_op[1];
assign es_res_from_div = es_div_op[0] | es_div_op[1];

assign tlbp_valid = es_inst_tlbp;
assign es_cp0_index_wdata = {
    !tlbp_found,
    {(31-$clog2(TLBNUM)){1'b0}},
    tlbp_index
};
assign es_cp0_real_addr = es_cp0_addr;

assign es_to_ms_bus = {es_tlb_flush   ,  //147:147
                       es_inst_tlbr   ,  //146:146
                       es_inst_tlbwi  ,  //145:145
                       es_inst_tlbp   ,  //144:144
                       es_cp0_index_wdata,//143:112
                       es_store_op    ,  //111:111
                       es_bd          ,  //110:110
                       es_exc         ,  //109:109
                       es_exc_type    ,  //108:94
                       es_eret_flush  ,  //93:93
                       es_cp0_wen     ,  //92:92
                       es_res_from_cp0,  //91:91
                       es_cp0_real_addr,  //90:83
                       es_res_from_mem,  //82:82
                       es_inst_load   ,  //81:75
                       es_ld_extd_op  ,  //74:70
                       es_gr_we       ,  //69:69
                       es_dest        ,  //68:64
                       es_alu_result  ,  //63:32
                       es_pc             //31:0
                      };

assign stall_es_bus = {{5{es_valid && es_gr_we}},
                       es_dest};
assign forward_es_bus = {es_valid && !es_res_from_mem && !es_res_from_cp0,
                         es_alu_result};

assign es_ready_go    = !((es_res_from_div && !es_div_out_valid)
                        ||(es_inst_tlbp && |(entryhi_stall_bus)));
assign es_allowin     = !es_valid || es_ready_go && ms_allowin;
assign es_to_ms_valid =  es_valid && es_ready_go;
always @(posedge clk) begin
    if (reset) begin
        es_valid <= 1'b0;
    end
    else if (flush) begin
        es_valid <= 1'b0;
    end
    else if (es_allowin) begin
        es_valid <= ds_to_es_valid;
    end
    if (ds_to_es_valid && es_allowin) begin
        ds_to_es_bus_r <= ds_to_es_bus;
    end
end

assign es_alu_src1 = es_src1_is_sa  ? {27'b0, es_imm[10:6]} : 
                     es_src1_is_pc  ? es_pc[31:0] :
                     es_src1_is_hi  ? hi :
                     es_src1_is_lo  ? lo :
                     es_src1_is_0   ? 32'b0 :
                                      es_rs_value;
assign es_alu_src2 = es_src2_is_imm ? {{16{es_imm[15]}}, es_imm[15:0]} :
                     es_src2_is_uimm? { 16'h0          , es_imm[15:0]} :
                     es_src2_is_8   ? 32'd8 :
                                      es_rt_value;

alu u_alu(
    .alu_op     (es_alu_op    ),
    .alu_src1   (es_alu_src1  ),
    .alu_src2   (es_alu_src2  ),
    .alu_result (es_alu_result),
    .alu_ov     (es_alu_ov    )
);

multiplier u_multiplier(
    .mul_op     (es_mul_op    ),
    .mul_src1   (es_alu_src1  ),
    .mul_src2   (es_alu_src2  ),
    .mul_result (es_mul_result)
);

divider u_divider(
    .clk            (clk                ),
    .rst            (reset              ),
    .flush          (flush              ),
    .div_op         (es_div_op          ),
    .divisor        (es_rt_value        ),
    .dividend       (es_rs_value        ),
    .div_in_valid   (es_res_from_div && !es_div_out_valid && es_valid),
    .div_result     (es_div_result      ),
    .div_out_valid  (es_div_out_valid   ),
    .div_out_ready  (ms_allowin         )
);

assign es_hl_result = es_res_from_div ? es_div_result :
                      /* mul */         es_mul_result;

assign es_hl_res_valid = es_hl_from_rs || es_res_from_mul || (es_res_from_div && es_div_out_valid);
assign hi_we    = es_valid && es_hi_we && es_hl_res_valid;
assign lo_we    = es_valid && es_lo_we && es_hl_res_valid;

assign hi_wdata = es_hl_from_rs ? es_rs_value :
                  /* mult/div */  es_hl_result[63:32];
assign lo_wdata = es_hl_from_rs ? es_rs_value :
                  /* mult/div */  es_hl_result[31:0];

always @(posedge clk) begin
    if (hi_we && !es_ms_ws_exc_eret)
        hi <= hi_wdata;
    
    if (lo_we && !es_ms_ws_exc_eret)
        lo <= lo_wdata;
end

wire    unmapped;

wire    es_tlblda_refill;   // TLB Refill: Load data
wire    es_tlbs_refill;     // TLB Refill: Store
wire    es_tlblda_invalid;  // TLB Invalid: Load data
wire    es_tlbs_invalid;    // TLB Invalid: Store
wire    es_mod;             // TLB Modified
wire    es_tlb_flush;

assign  data_vpn2_odd = es_alu_result[31:12];
assign  exe_store = es_store_op;

assign  unmapped = (es_alu_result[31:30] == 2'b10);

assign es_tlblda_refill     = es_load_op && TLB_refil_dr && !unmapped;
assign es_tlblda_invalid    = es_load_op && TLB_inval_dr && !unmapped;
assign es_tlbs_refill       = es_store_op && TLB_refil_ds && !unmapped;
assign es_tlbs_invalid      = es_store_op && TLB_inval_ds && !unmapped;
assign es_mod               = es_store_op && TLB_exec_Mod && !unmapped;
assign es_tlb_flush         = es_inst_tlbr  ||
                              es_inst_tlbwi ||
                              es_cp0_wen && (es_cp0_addr == {`ENTRYHI_NUM, 3'b0});

assign data_sram_req   = (es_to_ms_valid && ms_allowin) && (
                        (es_load_op && !(es_tlblda_refill || es_tlblda_invalid))
                        || (es_store_op && !(es_tlbs_refill || es_tlbs_invalid || es_mod))
                        );
assign data_sram_wr    = es_store_op;
assign data_sram_wen   = es_mem_we & {4{es_valid && !es_ms_ws_exc_eret}} ;
assign data_sram_addr  = unmapped ? {3'b000, es_alu_result[28:0]} :
                            {data_pfn, es_alu_result[11:0]};

assign es_store_op = |es_inst_store;

wire    es_ades;    // Address Error on Store
wire    es_ov;      // Overflow

st_decode u_st_decode(
    .inst_store(es_inst_store),
    .addr(data_sram_addr[1:0]),

    .st_rshift_op(es_st_rshift_op),
    .mem_we(es_mem_we),
    .ades(es_ades)
);

st_select u_st_select(
    .st_rshift_op    (es_st_rshift_op),
    .data_from_reg   (es_rt_value    ),

    .data_sram_wdata (data_sram_wdata)
);

//exc
assign es_ov    = es_ov_check && es_alu_ov;

assign es_ms_ws_exc_eret = es_exc || es_eret_flush || es_tlb_flush || (|es_exc_eret_bus);
assign es_exc            = old_ds_exc || es_ades || es_ov ||
    es_tlblda_refill || es_tlblda_invalid || es_tlbs_refill || es_tlbs_invalid || es_mod;
assign es_exc_type       = old_ds_exc_type | {
    2'h0, es_tlblda_refill, es_tlblda_invalid, es_tlbs_refill, es_tlbs_invalid, es_mod,
    3'h0, es_ades, 3'h0, es_ov};

endmodule
