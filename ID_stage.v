`include "mycpu.h"

module id_stage(
    input                          clk           ,
    input                          reset         ,
    //allowin
    input                          es_allowin    ,
    output                         ds_allowin    ,
    //from fs
    input                          fs_to_ds_valid,
    input  [`FS_TO_DS_BUS_WD -1:0] fs_to_ds_bus  ,
    //to es
    output                         ds_to_es_valid,
    output [`DS_TO_ES_BUS_WD -1:0] ds_to_es_bus  ,
    //to fs
    output [`BR_BUS_WD       -1:0] br_bus        ,
    //to rf: for write back
    input  [`WS_TO_RF_BUS_WD -1:0] ws_to_rf_bus  ,
    input  [`HI_LO_BUS_WD    -1:0] hi_lo_ds_bus  ,
    //to judge if stall
    input  [`STALL_BUS_WD*3  -1:0] stall_ds_bus  ,
    input  [`FORWARD_BUS_WD*3-1:0] forward_ds_bus
);

reg         ds_valid   ;
wire        ds_ready_go;

wire [31                 :0] fs_pc;
reg  [`FS_TO_DS_BUS_WD -1:0] fs_to_ds_bus_r;
assign fs_pc = fs_to_ds_bus[31:0];

wire [31:0] ds_inst;
wire [31:0] ds_pc  ;
assign {ds_inst,
        ds_pc  } = fs_to_ds_bus_r;

wire        rf_we   ;
wire [ 4:0] rf_waddr;
wire [31:0] rf_wdata;
assign {rf_we   ,  //37:37
        rf_waddr,  //36:32
        rf_wdata   //31:0
       } = ws_to_rf_bus;

wire        reg1_stall_valid;
wire        reg2_stall_valid;
wire        es_we;
wire [ 4:0] es_dest;
wire        ms_we;
wire [ 4:0] ms_dest;
wire        ws_we;
wire [ 4:0] ws_dest;
wire        es_forward_valid;
wire [31:0] es_forward_data;
wire        ms_forward_valid;
wire [31:0] ms_forward_data;
wire        ws_forward_valid;
wire [31:0] ws_forward_data;
wire        stall_reg1_es;
wire        stall_reg1_ms;
wire        stall_reg1_ws;
wire        stall_reg2_es;
wire        stall_reg2_ms;
wire        stall_reg2_ws;
wire        stall_reg1_happen;
wire        stall_reg2_happen;
wire        stall_happen;
wire        forward_reg1_es;
wire        forward_reg1_ms;
wire        forward_reg1_ws;
wire        forward_reg2_es;
wire        forward_reg2_ms;
wire        forward_reg2_ws;
wire        forward_reg1_happen;
wire        forward_reg2_happen;
wire        forward_happen;
assign {es_we            ,es_dest,
        ms_we            ,ms_dest,
        ws_we            ,ws_dest}         = stall_ds_bus;
assign {es_forward_valid ,es_forward_data,
        ms_forward_valid ,ms_forward_data,
        ws_forward_valid ,ws_forward_data} = forward_ds_bus;

wire        br_taken;
wire [31:0] br_target;



wire [11:0] alu_op;
wire [ 1:0] mul_op;
wire [ 1:0] div_op;
wire        load_op;
wire        src1_is_sa;
wire        src1_is_pc;
wire        src2_is_imm;
wire        src2_is_uimm;
wire        src2_is_8;
wire        res_from_mem;
wire        gr_we;
wire        hl_we;
wire        mem_we;
wire [ 4:0] dest;
wire [15:0] imm;
wire [31:0] rs_value;
wire [31:0] rt_value;

wire [ 5:0] op;
wire [ 4:0] rs;
wire [ 4:0] rt;
wire [ 4:0] rd;
wire [ 4:0] sa;
wire [ 5:0] func;
wire [25:0] jidx;
wire [63:0] op_d;
wire [31:0] rs_d;
wire [31:0] rt_d;
wire [31:0] rd_d;
wire [31:0] sa_d;
wire [63:0] func_d;

wire        inst_add;
wire        inst_addu;
wire        inst_sub;
wire        inst_subu;
wire        inst_mult;
wire        inst_slt;
wire        inst_sltu;
wire        inst_sltiu;
wire        inst_and;
wire        inst_or;
wire        inst_ori;
wire        inst_xor;
wire        inst_nor;
wire        inst_sll;
wire        inst_sllv;
wire        inst_srl;
wire        inst_sra;
wire        inst_srav;
wire        inst_addiu;
wire        inst_lui;
wire        inst_lw;
wire        inst_sw;
wire        inst_beq;
wire        inst_bne;
wire        inst_jal;
wire        inst_jr;

wire        dst_is_r31;  
wire        dst_is_rt;   

wire [ 4:0] rf_raddr1;
wire [31:0] rf_rdata1;
wire [ 4:0] rf_raddr2;
wire [31:0] rf_rdata2;

wire        rs_eq_rt;

assign br_bus       = {br_taken,br_target};

assign ds_to_es_bus = {alu_op      ,  //141:130
                       mul_op      ,  //129:128
                       div_op      ,  //127:126
                       load_op     ,  //125:125
                       src1_is_sa  ,  //124:124
                       src1_is_pc  ,  //123:123
                       src2_is_imm ,  //122:122
                       src2_is_uimm,  //121:121
                       src2_is_8   ,  //120:120
                       gr_we       ,  //119:119
                       hl_we       ,  //118:118
                       mem_we      ,  //117:117
                       dest        ,  //116:112
                       imm         ,  //111:96
                       rs_value    ,  //95 :64
                       rt_value    ,  //63 :32
                       ds_pc          //31 :0
                      };

assign ds_ready_go    = !stall_happen || forward_happen;
assign ds_allowin     = !ds_valid || ds_ready_go && es_allowin;
assign ds_to_es_valid = ds_valid && ds_ready_go;
always @(posedge clk) begin
    if (reset) begin
        ds_valid <= 1'b0;
    end
    else if (ds_allowin) begin
        ds_valid <= fs_to_ds_valid;
    end
    if (fs_to_ds_valid && ds_allowin) begin
        fs_to_ds_bus_r <= fs_to_ds_bus;
    end
end

assign op   = ds_inst[31:26];
assign rs   = ds_inst[25:21];
assign rt   = ds_inst[20:16];
assign rd   = ds_inst[15:11];
assign sa   = ds_inst[10: 6];
assign func = ds_inst[ 5: 0];
assign imm  = ds_inst[15: 0];
assign jidx = ds_inst[25: 0];

decoder_6_64 u_dec0(.in(op  ), .out(op_d  ));
decoder_6_64 u_dec1(.in(func), .out(func_d));
decoder_5_32 u_dec2(.in(rs  ), .out(rs_d  ));
decoder_5_32 u_dec3(.in(rt  ), .out(rt_d  ));
decoder_5_32 u_dec4(.in(rd  ), .out(rd_d  ));
decoder_5_32 u_dec5(.in(sa  ), .out(sa_d  ));

assign inst_add    = op_d[6'h00] & func_d[6'h20] & sa_d[5'h00];
assign inst_addu   = op_d[6'h00] & func_d[6'h21] & sa_d[5'h00];
assign inst_sub    = op_d[6'h00] & func_d[6'h22] & sa_d[5'h00];
assign inst_subu   = op_d[6'h00] & func_d[6'h23] & sa_d[5'h00];
assign inst_mult   = op_d[6'h00] & func_d[6'h18] & sa_d[5'h00] & rd_d[5'h00];
assign inst_slt    = op_d[6'h00] & func_d[6'h2a] & sa_d[5'h00];
assign inst_sltu   = op_d[6'h00] & func_d[6'h2b] & sa_d[5'h00];
assign inst_sltiu  = op_d[6'h0b];
assign inst_and    = op_d[6'h00] & func_d[6'h24] & sa_d[5'h00];
assign inst_or     = op_d[6'h00] & func_d[6'h25] & sa_d[5'h00];
assign inst_ori    = op_d[6'h0d];
assign inst_xor    = op_d[6'h00] & func_d[6'h26] & sa_d[5'h00];
assign inst_nor    = op_d[6'h00] & func_d[6'h27] & sa_d[5'h00];
assign inst_sll    = op_d[6'h00] & func_d[6'h00] & rs_d[5'h00];
assign inst_sllv   = op_d[6'h00] & func_d[6'h04] & rs_d[5'h00];
assign inst_srl    = op_d[6'h00] & func_d[6'h02] & rs_d[5'h00];
assign inst_sra    = op_d[6'h00] & func_d[6'h03] & rs_d[5'h00];
assign inst_srav   = op_d[6'h00] & func_d[6'h07] & rs_d[5'h00];
assign inst_addiu  = op_d[6'h09];
assign inst_lui    = op_d[6'h0f] & rs_d[5'h00];
assign inst_lw     = op_d[6'h23];
assign inst_sw     = op_d[6'h2b];
assign inst_beq    = op_d[6'h04];
assign inst_bne    = op_d[6'h05];
assign inst_jal    = op_d[6'h03];
assign inst_jr     = op_d[6'h00] & func_d[6'h08] & rt_d[5'h00] & rd_d[5'h00] & sa_d[5'h00];

assign alu_op[ 0] = inst_add | inst_addu | inst_addiu | inst_lw | inst_sw | inst_jal;
assign alu_op[ 1] = inst_sub | inst_subu;
assign alu_op[ 2] = inst_slt;
assign alu_op[ 3] = inst_sltu | inst_sltiu;
assign alu_op[ 4] = inst_and;
assign alu_op[ 5] = inst_nor;
assign alu_op[ 6] = inst_or | inst_ori;
assign alu_op[ 7] = inst_xor;
assign alu_op[ 8] = inst_sll | inst_sllv;
assign alu_op[ 9] = inst_srl;
assign alu_op[10] = inst_sra | inst_srav;
assign alu_op[11] = inst_lui;
assign mul_op[ 0] = inst_mult;

assign load_op    = inst_lw;

assign src1_is_sa   = inst_sll   | inst_srl   | inst_sra;
assign src1_is_pc   = inst_jal;
assign src2_is_imm  = inst_addiu | inst_sltiu | inst_lui | inst_lw | inst_sw;
assign src2_is_uimm = inst_ori;
assign src2_is_8    = inst_jal;
assign res_from_mem = inst_lw;
assign dst_is_r31   = inst_jal;
assign dst_is_rt    = inst_addiu | inst_sltiu | inst_ori | inst_lui | inst_lw;
assign gr_we        = ~inst_sw & ~inst_beq & ~inst_bne & ~inst_jr;
assign hl_we        = inst_mult;
assign mem_we       = inst_sw;

assign dest         = dst_is_r31 ? 5'd31 :
                      dst_is_rt  ? rt    : 
                                   rd;

assign rf_raddr1 = rs;
assign rf_raddr2 = rt;
regfile u_regfile(
    .clk    (clk      ),
    .raddr1 (rf_raddr1),
    .rdata1 (rf_rdata1),
    .raddr2 (rf_raddr2),
    .rdata2 (rf_rdata2),
    .we     (rf_we    ),
    .waddr  (rf_waddr ),
    .wdata  (rf_wdata )
    );

assign rs_value = forward_reg1_es? es_forward_data:
                  forward_reg1_ms? ms_forward_data:
                  forward_reg1_ws? ws_forward_data:
                                         rf_rdata1;
assign rt_value = forward_reg2_es? es_forward_data:
                  forward_reg2_ms? ms_forward_data:
                  forward_reg2_ws? ws_forward_data:
                                         rf_rdata2;

assign reg1_stall_valid = rf_raddr1!=5'h0 && !src1_is_sa  && !src1_is_pc;
assign reg2_stall_valid = rf_raddr2!=5'h0 && (!src2_is_imm || inst_sw) && !src2_is_8 ;
assign stall_reg1_es = reg1_stall_valid && es_we && rf_raddr1==es_dest;
assign stall_reg1_ms = reg1_stall_valid && ms_we && rf_raddr1==ms_dest;
assign stall_reg1_ws = reg1_stall_valid && ws_we && rf_raddr1==ws_dest;
assign stall_reg2_es = reg2_stall_valid && es_we && rf_raddr2==es_dest;
assign stall_reg2_ms = reg2_stall_valid && ms_we && rf_raddr2==ms_dest;
assign stall_reg2_ws = reg2_stall_valid && ws_we && rf_raddr2==ws_dest;
assign stall_reg1_happen = stall_reg1_es || stall_reg1_ms || stall_reg1_ws;
assign stall_reg2_happen = stall_reg2_es || stall_reg2_ms || stall_reg2_ws;
assign stall_happen = stall_reg1_happen || stall_reg2_happen;

assign forward_reg1_es = es_forward_valid && stall_reg1_es;
assign forward_reg1_ms = ms_forward_valid && stall_reg1_ms && !stall_reg1_es;
assign forward_reg1_ws = ws_forward_valid && stall_reg1_ws && !stall_reg1_es && !stall_reg1_ms;
assign forward_reg2_es = es_forward_valid && stall_reg2_es;
assign forward_reg2_ms = ms_forward_valid && stall_reg2_ms && !stall_reg2_es;
assign forward_reg2_ws = ws_forward_valid && stall_reg2_ws && !stall_reg2_es && !stall_reg2_ms;
assign forward_reg1_happen = forward_reg1_es || forward_reg1_ms || forward_reg1_ws;
assign forward_reg2_happen = forward_reg2_es || forward_reg2_ms || forward_reg2_ws;
assign forward_happen = !stall_reg1_happen && forward_reg2_happen
                     || !stall_reg2_happen && forward_reg1_happen
                     || forward_reg1_happen && forward_reg2_happen;

assign rs_eq_rt = (rs_value == rt_value);
assign br_taken = (   inst_beq  &&  rs_eq_rt
                   || inst_bne  && !rs_eq_rt
                   || inst_jal
                   || inst_jr
                  ) && ds_valid;
assign br_target = (inst_beq || inst_bne) ? (fs_pc + {{14{imm[15]}}, imm[15:0], 2'b0}) :
                   (inst_jr)              ? rs_value :
                  /*inst_jal*/              {fs_pc[31:28], jidx[25:0], 2'b0};

endmodule
