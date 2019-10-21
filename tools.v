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

    input  [ 1:0] div_op,
    input  [31:0] divisor,
    input  [31:0] dividend,
    input         div_in_valid,

    output [63:0] div_result,
    output        div_out_valid,
    input         div_out_ready
);
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
    else if(div_op[0] && m_axis_dout_tvalid_sgn
         || div_op[1] && m_axis_dout_tvalid_usgn)
        div_out_valid_r <= 1'h1;
assign  div_out_valid_w  = (div_op[0] && m_axis_dout_tvalid_sgn
                         || div_op[1] && m_axis_dout_tvalid_usgn) || div_out_valid_r;
assign  div_out_valid    = div_out_valid_w;

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

);

endmodule


module st_decode(
    input  [4:0] store_op,
    input  [1:0] addr,

    output [3:0] sel,   // rshift amount on selector
    output [3:0] mem_we
);

wire    sw;
wire    sb;
wire    sh;
wire    swl;
wire    swr;

wire [3:0] addr_d;

assign  sw  = store_op[4];
assign  sb  = store_op[3];
assign  sh  = store_op[2];
assign  swl = store_op[1];
assign  swr = store_op[0];

decoder_2_4 u_dec(.in(addr), .out(addr_d));

assign  sel[0]  = sw || sb && addr_d[0]
                ||sh && addr_d[0]
                ||swl&& addr_d[3]
                ||swr&& addr_d[0];
assign  sel[1]  = sb && addr_d[3]
                ||swl&& addr_d[2]
                ||swr&& addr_d[3];
assign  sel[2]  = sb && addr_d[2]
                ||sh && addr_d[2]
                ||swl&& addr_d[1]
                ||swr&& addr_d[2];
assign  sel[3]  = sb && addr_d[1]
                ||swl&& addr_d[0]
                ||swr&& addr_d[1];

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
    input  [ 3:0] ld_rshift_op, //get in ID
    input  [ 4:0] ld_extd_op,
    input  [31:0] data_sram_rdata,

    output [31:0] mem_result
);

endmodule

module st_select(
    input  [ 3:0] st_rshift_op,
    input  [31:0] data_from_reg,

    output [31:0] data_sram_wdata
);

endmodule




