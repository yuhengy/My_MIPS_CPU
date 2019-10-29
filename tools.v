module decoder_2_4(
    input  [ 1:0] in,
    output [ 3:0] out
);

genvar i;
generate for (i=0; i<4; i=i+1) begin : gen_for_dec_2_4
    assign out[i] = (in == i);
end endgenerate

endmodule

module decoder_5_32(
    input  [ 4:0] in,
    output [31:0] out
);

genvar i;
generate for (i=0; i<32; i=i+1) begin : gen_for_dec_5_32
    assign out[i] = (in == i);
end endgenerate

endmodule


module decoder_6_64(
    input  [ 5:0] in,
    output [63:0] out
);

genvar i;
generate for (i=0; i<64; i=i+1) begin : gen_for_dec_6_64
    assign out[i] = (in == i);
end endgenerate

endmodule

module multiplier(
	input  [ 1:0] mul_op,
	input  [31:0] mul_src1,
	input  [31:0] mul_src2,

	output [63:0] mul_result
);
wire [63:0] signed_prod;
wire [63:0] unsigned_prod;
assign signed_prod   = $signed(mul_src1) * $signed(mul_src2);
assign unsigned_prod = mul_src1 * mul_src2;
assign mul_result    = {64{mul_op[0]}} & signed_prod
                     | {64{mul_op[1]}} & unsigned_prod;
endmodule


//To fit 5 pipeline states
//only accept next in_valid during or after last out_valid && out_ready
//keep out_valid until shaking hands with div_out_ready(es_allowin)

//To be a more general module with no limitation on input
//actively ignore all in_valid until div_out_valid && out_ready
//i.e. with compatibility on random in_valids during this period
//and doesn't treat them as mew inputs
module divider(
    input         clk,
    input         rst,
    input         flush,

    input  [ 1:0] div_op,
    input  [31:0] divisor,
    input  [31:0] dividend,
    input         div_in_valid,

    output [63:0] div_result,
    output        div_out_valid,
    input         div_out_ready
);
reg  flush_r;

reg  div_in_valid_r ;
wire div_in_valid_w ;
reg  div_busy_r;
wire div_busy_w;
reg  div_out_valid_r;
wire div_out_valid_w;

wire        s_axis_divisor_tvalid_sgn  ;
wire        s_axis_divisor_tvalid_usgn ;
wire        s_axis_divisor_tready_sgn  ;
wire        s_axis_divisor_tready_usgn ;
wire        s_axis_dividend_tvalid_sgn ;
wire        s_axis_dividend_tvalid_usgn;
wire        s_axis_dividend_tready_sgn ;
wire        s_axis_dividend_tready_usgn;
wire [63:0] m_axis_dout_tdata_sgn      ;
wire [63:0] m_axis_dout_tdata_usgn     ;
wire        m_axis_dout_tvalid_sgn     ;
wire        m_axis_dout_tvalid_usgn    ;

//flush
always @(posedge clk)
    if(rst)
        flush_r <= 1'b0;
    else if(flush)
        flush_r <= 1'b1;
    else if(flush_r && div_out_valid_w)
        flush_r <= 1'b0;

//all three priorities are strictly needed
always @(posedge clk)
    if(rst)
        div_in_valid_r <= 1'h0;
    else if(div_op[0] && s_axis_divisor_tready_sgn  && s_axis_dividend_tready_sgn
         || div_op[1] && s_axis_divisor_tready_usgn && s_axis_dividend_tready_usgn)
        div_in_valid_r <= 1'h0;
    else if(div_in_valid && !div_busy_w)
        div_in_valid_r <= 1'h1;
assign  div_in_valid_w  = div_in_valid_r || div_in_valid && !div_busy_w;

always @(posedge clk)
    if(rst)
        div_busy_r <= 1'h0;
    else if(div_in_valid)
        div_busy_r <= 1'h1;
    else if(div_out_valid_w && div_out_ready)
        div_busy_r <= 1'h0;
assign  div_busy_w  = div_busy_r && !(div_out_valid_w && div_out_ready);

always @(posedge clk)
    if(rst)
        div_out_valid_r <= 1'h0;
    else if(div_out_ready || div_in_valid && !div_busy_w)
        div_out_valid_r <= 1'h0;
    else if((div_op[0] || flush_r) && m_axis_dout_tvalid_sgn
         || (div_op[1] || flush_r) && m_axis_dout_tvalid_usgn)
        div_out_valid_r <= 1'h1;
assign  div_out_valid_w  = ((div_op[0] || flush_r) && m_axis_dout_tvalid_sgn
                         || (div_op[1] || flush_r) && m_axis_dout_tvalid_usgn) || div_out_valid_r;
assign  div_out_valid    = div_out_valid_w && !flush_r;

assign s_axis_divisor_tvalid_sgn   = div_in_valid_w && div_op[0];
assign s_axis_dividend_tvalid_sgn  = s_axis_divisor_tvalid_sgn;
assign s_axis_divisor_tvalid_usgn  = div_in_valid_w && div_op[1];
assign s_axis_dividend_tvalid_usgn = s_axis_divisor_tvalid_usgn;

mydiv_sgn u_mydiv_sgn(
    .aclk                  (clk                       ),

    .s_axis_divisor_tdata  (divisor                   ),
    .s_axis_divisor_tready (s_axis_divisor_tready_sgn ),
    .s_axis_divisor_tvalid (s_axis_divisor_tvalid_sgn ),

    .s_axis_dividend_tdata (dividend                  ),
    .s_axis_dividend_tready(s_axis_dividend_tready_sgn),
    .s_axis_dividend_tvalid(s_axis_dividend_tvalid_sgn),

    .m_axis_dout_tdata     (m_axis_dout_tdata_sgn     ),
    .m_axis_dout_tvalid    (m_axis_dout_tvalid_sgn    )
);

mydiv_usgn u_mydiv_usgn(
    .aclk                  (clk                        ),

    .s_axis_divisor_tdata  (divisor                    ),
    .s_axis_divisor_tready (s_axis_divisor_tready_usgn ),
    .s_axis_divisor_tvalid (s_axis_divisor_tvalid_usgn ),

    .s_axis_dividend_tdata (dividend                   ),
    .s_axis_dividend_tready(s_axis_dividend_tready_usgn),
    .s_axis_dividend_tvalid(s_axis_dividend_tvalid_usgn),

    .m_axis_dout_tdata     (m_axis_dout_tdata_usgn     ),
    .m_axis_dout_tvalid    (m_axis_dout_tvalid_usgn    )
);

assign div_result = {64{div_op[0]}} & {m_axis_dout_tdata_sgn[31:0], m_axis_dout_tdata_sgn[63:32]}
                  | {64{div_op[1]}} & {m_axis_dout_tdata_usgn[31:0], m_axis_dout_tdata_usgn[63:32]};

endmodule

module br_comp(
    input  [ 5:0] br_op,
    input  [31:0] br_src1,
    input  [31:0] br_src2,

    output        br_happen
);

wire op_beq;
wire op_bne;
wire op_bgez;
wire op_bgtz;
wire op_blez;
wire op_bltz;

wire src1_eq_src2;
wire src1_gez;
wire src1_ltz;
wire src1_zero;

assign op_beq   = br_op[0];
assign op_bne   = br_op[1];
assign op_bgez  = br_op[2];
assign op_bgtz  = br_op[3];
assign op_blez  = br_op[4];
assign op_bltz  = br_op[5];

assign src1_eq_src2 = (br_src1 == br_src2);
assign src1_gez     = ~br_src1[31];
assign src1_ltz     = br_src1[31];
assign src1_zero    = (br_src1 == 32'b0);

assign br_happen =  op_beq  &&  src1_eq_src2
                ||  op_bne  && !src1_eq_src2
                ||  op_bgez &&  src1_gez
                ||  op_bgtz && (src1_gez && !src1_zero)
                ||  op_blez && (src1_ltz ||  src1_zero)
                ||  op_bltz &&  src1_ltz;

endmodule


module ld_decode(
    input   [6:0] inst_load,
    input   [1:0] addr,
    input         gr_we_1,  // 1 bit we

    output  [3:0] ld_rshift_op,
    output  [3:0] gr_we
);

wire    lw;
wire    lb;
wire    lbu;
wire    lh;
wire    lhu;
wire    lwl;
wire    lwr;
wire    non_load;

wire [3:0] addr_d;

assign  lw  = inst_load[6];
assign  lb  = inst_load[5];
assign  lbu = inst_load[4];
assign  lh  = inst_load[3];
assign  lhu = inst_load[2];
assign  lwl = inst_load[1];
assign  lwr = inst_load[0];
assign  non_load = (inst_load == 7'b0); // replicate gr_we_1

decoder_2_4 u_dec(.in(addr), .out(addr_d));

assign  ld_rshift_op[0]  = lw
                        ||(lb || lbu) && addr_d[0]
                        ||(lh || lhu) && addr_d[0]
                        || lwl        && addr_d[3]
                        || lwr        && addr_d[0];
assign  ld_rshift_op[1]  =(lb || lbu) && addr_d[1]
                        || lwl        && addr_d[0]
                        || lwr        && addr_d[1];
assign  ld_rshift_op[2]  =(lb || lbu) && addr_d[2]
                        ||(lh || lhu) && addr_d[2]
                        || lwl        && addr_d[1]
                        || lwr        && addr_d[2];
assign  ld_rshift_op[3]  =(lb || lbu) && addr_d[3]
                        || lwl        && addr_d[2]
                        || lwr        && addr_d[3];

assign gr_we[0]  = lw || lb || lbu || lh || lhu || non_load && gr_we_1
                || lwl && addr_d[3]
                || lwr;
assign gr_we[1]  = lw || lb || lbu || lh || lhu || non_load && gr_we_1
                || lwl && (addr_d[3] || addr_d[2])
                || lwr && (addr_d[0] || addr_d[1] || addr_d[2]);
assign gr_we[2]  = lw || lb || lbu || lh || lhu || non_load && gr_we_1
                || lwl && (addr_d[3] || addr_d[2] || addr_d[1])
                || lwr && (addr_d[0] || addr_d[1]);
assign gr_we[3]  = lw || lb || lbu || lh || lhu || non_load && gr_we_1
                || lwl
                || lwr && addr_d[0];

endmodule


module st_decode(
    input  [4:0] inst_store,
    input  [1:0] addr,

    output [3:0] st_rshift_op,   // rshift amount on selector
    output [3:0] mem_we
);

wire    sw;
wire    sb;
wire    sh;
wire    swl;
wire    swr;

wire [3:0] addr_d;

assign  sw  = inst_store[4];
assign  sb  = inst_store[3];
assign  sh  = inst_store[2];
assign  swl = inst_store[1];
assign  swr = inst_store[0];

decoder_2_4 u_dec(.in(addr), .out(addr_d));

assign  st_rshift_op[0]  = sw 
                        || sb && addr_d[0]
                        || sh && addr_d[0]
                        || swl&& addr_d[3]
                        || swr&& addr_d[0];
assign  st_rshift_op[1]  = sb && addr_d[3]
                        || swl&& addr_d[2]
                        || swr&& addr_d[3];
assign  st_rshift_op[2]  = sb && addr_d[2]
                        || sh && addr_d[2]
                        || swl&& addr_d[1]
                        || swr&& addr_d[2];
assign  st_rshift_op[3]  = sb && addr_d[1]
                        || swl&& addr_d[0]
                        || swr&& addr_d[1];

assign mem_we[0] = sw || sb && addr_d[0]
                || sh && addr_d[0]
                || swl
                || swr&& addr_d[0];
assign mem_we[1] = sw || sb && addr_d[1]
                || sh && addr_d[0]
                || swl&& (addr_d[3] || addr_d[2] || addr_d[1])
                || swr&& (addr_d[0] || addr_d[1]);
assign mem_we[2] = sw || sb && addr_d[2]
                || sh && addr_d[2]
                || swl&& (addr_d[3] || addr_d[2])
                || swr&& (addr_d[0] || addr_d[1] || addr_d[2]);
assign mem_we[3] = sw || sb && addr_d[3]
                || sh && addr_d[2]
                || swl&& addr_d[3]
                || swr;

endmodule


module ld_select(
    input  [ 3:0] ld_rshift_op,
    input  [ 4:0] ld_extd_op,
    input  [31:0] data_sram_rdata,

    output [31:0] mem_result
);
wire [31:0] mem_result_unextd;
wire        ext_b;
wire        ext_bu;
wire        ext_h;
wire        ext_hu;
wire        ext_non;

assign ext_b    = ld_extd_op[4];
assign ext_bu   = ld_extd_op[3];
assign ext_h    = ld_extd_op[2];
assign ext_hu   = ld_extd_op[1];
assign ext_non  = ld_extd_op[0];

assign mem_result_unextd = {32{ld_rshift_op[0]}} & {data_sram_rdata}
                         | {32{ld_rshift_op[1]}} & {data_sram_rdata[7:0], data_sram_rdata[31:8]}
                         | {32{ld_rshift_op[2]}} & {data_sram_rdata[15:0], data_sram_rdata[31:16]}
                         | {32{ld_rshift_op[3]}} & {data_sram_rdata[23:0], data_sram_rdata[31:24]};
assign mem_result   = {32{ext_b}}   & {{24{mem_result_unextd[7]}}, mem_result_unextd[7:0]}
                    | {32{ext_bu}}  & {24'b0, mem_result_unextd[7:0]}
                    | {32{ext_h}}   & {{16{mem_result_unextd[15]}}, mem_result_unextd[15:0]}
                    | {32{ext_hu}}  & {16'b0, mem_result_unextd[15:0]}
                    | {32{ext_non}} & {mem_result_unextd};

endmodule


module st_select(
    input  [ 3:0] st_rshift_op,
    input  [31:0] data_from_reg,

    output [31:0] data_sram_wdata
);

assign data_sram_wdata  = {32{st_rshift_op[0]}} & {data_from_reg}
                        | {32{st_rshift_op[1]}} & {data_from_reg[7:0], data_from_reg[31:8]}
                        | {32{st_rshift_op[2]}} & {data_from_reg[15:0], data_from_reg[31:16]}
                        | {32{st_rshift_op[3]}} & {data_from_reg[23:0], data_from_reg[31:24]};

endmodule

module forward_merge(
    input  [ 2:0] forward,
    input  [11:0] forward_en,
    input  [95:0] forward_data,
    input  [31:0] rf_rdata,

    output [31:0] merge_value
);
wire             forward_es,      forward_ms,      forward_ws;
wire [ 3:0]   forward_en_es,   forward_en_ms,   forward_en_ws;
wire [31:0] forward_data_es, forward_data_ms, forward_data_ws;
wire [ 3:0] no_forward;
assign {     forward_es,      forward_ms,      forward_ws} = forward;
assign {  forward_en_es,   forward_en_ms,   forward_en_ws} = forward_en;
assign {forward_data_es, forward_data_ms, forward_data_ws} = forward_data;
assign no_forward = ~ ({4{forward_es}} & forward_en_es
                     | {4{forward_ms}} & forward_en_ms
                     | {4{forward_ws}} & forward_en_ws);

assign merge_value[ 7: 0] = {8{forward_es & forward_en_es[0]}} & forward_data_es[ 7: 0]
                          | {8{forward_ms & forward_en_ms[0]}} & forward_data_ms[ 7: 0]
                          | {8{forward_ws & forward_en_ws[0]}} & forward_data_ws[ 7: 0]
                          | {8{                no_forward[0]}} &        rf_rdata[ 7: 0];
assign merge_value[15: 8] = {8{forward_es & forward_en_es[1]}} & forward_data_es[15: 8]
                          | {8{forward_ms & forward_en_ms[1]}} & forward_data_ms[15: 8]
                          | {8{forward_ws & forward_en_ws[1]}} & forward_data_ws[15: 8]
                          | {8{                no_forward[1]}} &        rf_rdata[15: 8];
assign merge_value[23:16] = {8{forward_es & forward_en_es[2]}} & forward_data_es[23:16]
                          | {8{forward_ms & forward_en_ms[2]}} & forward_data_ms[23:16]
                          | {8{forward_ws & forward_en_ws[2]}} & forward_data_ws[23:16]
                          | {8{                no_forward[2]}} &        rf_rdata[23:16];
assign merge_value[31:24] = {8{forward_es & forward_en_es[3]}} & forward_data_es[31:24]
                          | {8{forward_ms & forward_en_ms[3]}} & forward_data_ms[31:24]
                          | {8{forward_ws & forward_en_ws[3]}} & forward_data_ws[31:24]
                          | {8{                no_forward[3]}} &        rf_rdata[31:24];

endmodule











