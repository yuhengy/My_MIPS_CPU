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

//to fit 5 pipeline states
//ignore all div_in_valid until div_out_valid
//keep div_out_valid until div_out_ready(es_allowin&&...to avoid X)
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

reg  div_in_valid_r       ;
reg  div_busy             ;
reg  div_out_valid_r      ;
wire div_out_valid_forward;

wire [31:0] s_axis_divisor_tdata  ;
wire        s_axis_divisor_tready ;
wire        s_axis_divisor_tvalid ;
wire [31:0] s_axis_dividend_tdata ;
wire        s_axis_dividend_tready;
wire        s_axis_dividend_tvalid;
wire [63:0] m_axis_dout_tdata     ;
wire        m_axis_dout_tvalid    ;

always @(posedge clk)
    if(div_in_valid && !div_busy)
        div_in_valid_r <= 1'h1;
    else if(s_axis_divisor_tready && s_axis_dividend_tready)
        div_in_valid_r <= 1'h0;

always @(posedge clk)
    if(rst)
        div_busy <= 1'h0;
    else if(div_out_ready)
        div_busy <= 1'h0;
    else if(div_in_valid)
        div_busy <= 1'h1;

always @(posedge clk)
    if(m_axis_dout_tvalid)
        


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


