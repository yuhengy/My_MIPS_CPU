`include "mycpu.h"

module exe_stage(
    input                          clk           ,
    input                          reset         ,
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
    // data sram interface
    output        data_sram_en   ,
    output [ 3:0] data_sram_wen  ,
    output [31:0] data_sram_addr ,
    output [31:0] data_sram_wdata
);

reg         es_valid      ;
wire        es_ready_go   ;

reg  [`DS_TO_ES_BUS_WD -1:0] ds_to_es_bus_r;
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
assign {es_hl_from_rs  ,  //161:161
        es_inst_load   ,  //160:154
        es_inst_store  ,  //153:149
        es_alu_op      ,  //148:137
        es_mul_op      ,  //136:135
        es_div_op      ,  //134:133
        es_load_op     ,  //132:132
        es_ld_extd_op  ,  //131:127
        es_src1_is_sa  ,  //126:126
        es_src1_is_pc  ,  //125:125
        es_src1_is_hi  ,  //124:124
        es_src1_is_lo  ,  //123:123
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

assign es_res_from_mem = es_load_op;
assign es_res_from_mul = es_mul_op[0] | es_mul_op[1];
assign es_res_from_div = es_div_op[0] | es_div_op[1];

assign es_to_ms_bus = {es_res_from_mem,  //82:82
                       es_inst_load   ,  //81:75
                       es_ld_extd_op  ,  //74:70
                       es_gr_we       ,  //69:69
                       es_dest        ,  //68:64
                       es_alu_result  ,  //63:32
                       es_pc             //31:0
                      };

assign stall_es_bus = {{4{es_valid && es_gr_we}},
                       es_dest};
assign forward_es_bus = {es_valid && !es_res_from_mem,
                         es_alu_result};

assign es_ready_go    = !(es_res_from_div && !es_div_out_valid);
assign es_allowin     = !es_valid || es_ready_go && ms_allowin;
assign es_to_ms_valid =  es_valid && es_ready_go;
always @(posedge clk) begin
    if (reset) begin
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
                                      es_rs_value;
assign es_alu_src2 = es_src2_is_imm ? {{16{es_imm[15]}}, es_imm[15:0]} :
                     es_src2_is_uimm? { 16'h0          , es_imm[15:0]} :
                     es_src2_is_8   ? 32'd8 :
                                      es_rt_value;

alu u_alu(
    .alu_op     (es_alu_op    ),
    .alu_src1   (es_alu_src1  ),
    .alu_src2   (es_alu_src2  ),
    .alu_result (es_alu_result)
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
    .div_op         (es_div_op          ),
    .divisor        (es_rt_value        ),
    .dividend       (es_rs_value        ),
    .div_in_valid   (es_res_from_div    ),
    .div_result     (es_div_result      ),
    .div_out_valid  (es_div_out_valid   ),
    .div_out_ready  (1                  )
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
    if (hi_we)
        hi <= hi_wdata;
    
    if (lo_we)
        lo <= lo_wdata;
end

assign data_sram_en    = 1'b1;
assign data_sram_wen   = es_mem_we & es_valid;
assign data_sram_addr  = es_alu_result;

st_decode u_st_decode(
    .inst_store(es_inst_store),
    .addr(data_sram_addr[1:0]),

    .st_rshift_op(es_st_rshift_op),
    .mem_we(es_mem_we)
);

st_select u_st_select(
    .st_rshift_op    (es_st_rshift_op),
    .data_from_reg   (es_rt_value    ),

    .data_sram_wdata (data_sram_wdata)
);

endmodule
