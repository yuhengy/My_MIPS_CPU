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
assign signed_prod   = $signed(src1) * $signed(src2);
assign unsigned_prod = src1 * src2;
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

wire [31:0] s_axis_divisor_tdata       ;
wire        s_axis_divisor_tready      ;
wire        s_axis_divisor_tvalid_sgn  ;
wire        s_axis_divisor_tvalid_usgn ;
wire [31:0] s_axis_dividend_tdata      ;
wire        s_axis_dividend_tready     ;
wire        s_axis_dividend_tvalid_sgn ;
wire        s_axis_dividend_tvalid_usgn;
wire [63:0] m_axis_dout_tdata          ;
wire        m_axis_dout_tvalid_sgn     ;
wire        m_axis_dout_tvalid_usgn    ;


//all three priorities are strictly needed
always @(posedge clk)
    if(rst)
        div_in_valid_r <= 1'h0;
    else if(div_op[0] && s_axis_divisor_tready && s_axis_dividend_tready
          | div_op[1] && s_axis_divisor_tready && s_axis_dividend_tready)
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
    else if(div_out_ready)
        div_out_valid_r <= 1'h0;
    else if(m_axis_dout_tvalid)
        div_out_valid_r <= 1'h1;
assign  div_out_valid_w  = div_out_valid || div_out_valid_r;

XXXXX u_divider(
    .aclk                  (clk),

    .s_axis_divisor_tdata  (),
    .s_axis_divisor_tready (),
    .s_axis_divisor_tvalid (),

    .s_axis_dividend_tdata (),
    .s_axis_dividend_tready(),
    .s_axis_dividend_tvalid(),

    .m_axis_dout_tdata     (),
    .m_axis_dout_tvalid    ()
);


