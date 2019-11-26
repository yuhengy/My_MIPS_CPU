module cpu_axi_interface #
(
    parameter DATA_WID = 32,
    parameter STRB_WID = 4 ,  // = DATA_WID / 8
    parameter ADDR_WID = 32,
    parameter ID_WID   = 4 ,

    parameter RID0_INFO_NUM          = 1 ,
    parameter RID1_INFO_NUM          = 1 ,
    parameter RID1_TOK_NUM           = 1 ,  // > RID1_INFO_NUM
    parameter WID1_INFO_NUM          = 1 ,
    parameter WID1_TOK_NUM           = 1 ,  // > W_INFO_NUM
    parameter INST_RESPONSE_BUFF_NUM = 1 ,  // > RID0_TOK_NUM
    parameter DATA_REORDER_BUFF_NUM  = 1   // > RID1_TOK_NUM + WID1_TOK_NUM
    //INST_REORDER_BUFF_NUM + DATA_REORDER_BUFF_NUM > R_TOK_NUM + W_TOK_NUM
)
(
    input clk         ,
    input resetn      ,

    //inst sram-like 
    input                 inst_req    ,
    input                 inst_wr     ,
    input  [1:0]          inst_size   ,
    input  [ADDR_WID-1:0] inst_addr   ,
    input  [DATA_WID-1:0] inst_wdata  ,
    output [DATA_WID-1:0] inst_rdata  ,
    output                inst_addr_ok,
    output                inst_data_ok,
    
    //data sram-like 
    input                 data_req    ,
    input                 data_wr     ,
    input  [1:0]          data_size   ,
    input  [ADDR_WID-1:0] data_addr   ,
    input  [DATA_WID-1:0] data_wdata  ,
    output [DATA_WID-1:0] data_rdata  ,
    output                data_addr_ok,
    output                data_data_ok,

    //axi
    //ar
    output [ID_WID-1:0]   arid   ,
    output [ADDR_WID-1:0] araddr ,
    output [7:0]          arlen  ,
    output [2:0]          arsize ,
    output [1:0]          arburst,
    output [1:0]          arlock ,
    output [3:0]          arcache,
    output [2:0]          arprot ,
    output                arvalid,
    input                 arready,
    //r              
    input [ID_WID-1:0]    rid    ,
    input [DATA_WID-1:0]  rdata  ,
    input [1:0]           rresp  ,
    input                 rlast  ,
    input                 rvalid ,
    output                rready ,
    //aw           
    output [ID_WID-1:0]   awid   ,
    output [ADDR_WID-1:0] awaddr ,
    output [7:0]          awlen  ,
    output [2:0]          awsize ,
    output [1:0]          awburst,
    output [1:0]          awlock ,
    output [3:0]          awcache,
    output [2:0]          awprot ,
    output                awvalid,
    input                 awready,
    //w          
    output [ID_WID-1:0]   wid    ,
    output [DATA_WID-1:0] wdata  ,
    output [STRB_WID-1:0] wstrb  ,
    output                wlast  ,
    output                wvalid ,
    input                 wready ,
    //b              
    input [ID_WID-1:0]    bid    ,
    input [1:0]           bresp  ,
    input                 bvalid ,
    output                bready
);

wire [STRB_WID-1:0] compute_strb;
wire inst_RAW_hazard, data_RAW_hazard;

wire data_addr_ok_read;
//shake hand for hazard wait and wait
wire inst_req_hazardwait;
wire inst_addr_ok_wait, inst_addr_ok_response;
wire data_req_read_hazardwait;
wire data_addr_ok_read_wait, data_addr_ok_read_tok, data_addr_ok_reorder;
//shake hand for sram and wait
wire data_addr_ok_write_wait_addr, data_addr_ok_write_wait_data, data_addr_ok_write_tok;

//buffer for hazard, to configure the queue into a hazard_wait function
wire [ADDR_WID-1:0] inst_hazard_wait_buff_todetect, data_read_hazard_wait_buff_todetect;
//addr between hazard wait and wait queue
wire [ADDR_WID-1:0] inst_addr_hazardwait, data_addr_read_hazardwait;

//control/src for AXI_ar AUX
reg                 axi_ar_from_inst;
wire                arvalid_inst, arvalid_data;
wire [ADDR_WID-1:0] araddr_inst, araddr_data;


wire axi_rid0_finish, axi_rid1_finish, axi_bid1_finish;

//tok: one-hot code to record location in re-order buffer
//     , whose queue should be larger than wait buffer
wire [DATA_REORDER_BUFF_NUM-1:0]  tok_in, arid1_tok_out, wid1_tok_out;
reg  [INST_RESPONSE_BUFF_NUM-1:0] inst_response_tok;  //init same index as queue
//messy fix
reg last_data_addr_ok_read;

assign compute_strb[0] =   (data_addr[1:0] == 2'h0)
                        || (data_addr[1:0] == 2'h1) && (data_size == 2'h1)
                        || (data_addr[1:0] == 2'h2) && (data_size == 2'h2)
                        || (data_addr[1:0] == 2'h3) && (data_size == 2'h2);
assign compute_strb[1] =   (data_addr[1:0] == 2'h0) && (data_size == 2'h1)
                        || (data_addr[1:0] == 2'h1)
                        || (data_size == 2'h2);
assign compute_strb[2] =   (data_addr[1:0] == 2'h2)
                        || (data_size == 2'h2);
assign compute_strb[3] =   (data_addr[1:0] == 2'h0) && (data_size == 2'h2)
                        || (data_addr[1:0] == 2'h1) && (data_size == 2'h2)
                        || (data_addr[1:0] == 2'h2) && (data_size == 2'h1)
                        || (data_addr[1:0] == 2'h3);



assign axi_rid0_finish  = rvalid   && rready  && rid=={ID_WID{1'b0}};
assign axi_rid1_finish  = rvalid   && rready  && rid=={{(ID_WID-1){1'b0}},1'b1};
assign axi_bid1_finish  = bvalid   && bready;  // && bid==ID_WID'h1;

assign data_addr_ok = data_wr && data_addr_ok_write_wait_addr && data_addr_ok_write_wait_data && data_addr_ok_write_tok && data_addr_ok_reorder && last_data_addr_ok_read
                  || !data_wr && data_addr_ok_read;

always @(posedge clk)
    if(!resetn)
        axi_ar_from_inst <= 1'h0;
    else if(arvalid && arready)
        axi_ar_from_inst <= 1'h0;
    else if(!arvalid_data && arvalid_inst)
        axi_ar_from_inst <= 1'h1;
assign arvalid          = axi_ar_from_inst && arvalid_inst || !axi_ar_from_inst && arvalid_data;
assign araddr           = axi_ar_from_inst? araddr_inst: araddr_data;
assign arid             = axi_ar_from_inst? {ID_WID{1'b0}} : {{(ID_WID-1){1'b0}},1'b1};

generate if(INST_RESPONSE_BUFF_NUM==1) begin: INST_RESPONSE_BUFF_NUM_is_1
    always @(posedge clk)
        if(!resetn)
            inst_response_tok <= {{(INST_RESPONSE_BUFF_NUM-1){1'b0}},1'b1};
        else if(axi_rid0_finish)
            inst_response_tok <= inst_response_tok;
end else begin: INST_RESPONSE_BUFF_NUM_isnot_1
    always @(posedge clk)
        if(!resetn)
            inst_response_tok <= {{(INST_RESPONSE_BUFF_NUM-1){1'b0}},1'b1};
        else if(axi_rid0_finish)
            inst_response_tok <= {inst_response_tok[INST_RESPONSE_BUFF_NUM-2:0], inst_response_tok[INST_RESPONSE_BUFF_NUM-1]};
end endgenerate

always @(posedge clk)
    if(!resetn)
        last_data_addr_ok_read <= 1'h0;
    else
        last_data_addr_ok_read <= data_addr_ok_read && !(data_req && !data_wr && data_addr_ok_read);

assign rready  = 1'h1;  //because pre-allocated but unused re-order buffer
assign bready  = 1'h1;  //because pre-allocated but unused re-order buffer
assign arlen   = 8'h0;
assign arsize  = 3'h2;
assign arburst = 2'h1;
assign arlock  = 2'h0;
assign arcache = 4'h0;
assign arprot  = 3'h0;
assign awid    = {{(ID_WID-1){1'b0}},1'b1};
assign awaddr[1:0] = 2'h0;
assign awlen   = 8'h0;
assign awsize  = 3'h2;
assign awburst = 2'h1;
assign awlock  = 2'h0;
assign awcache = 4'h0;
assign awprot  = 3'h0;
assign wid     = {{(ID_WID-1){1'b0}},1'b1};
assign wlast   = 1'h1;

//inst hazard wait buffer
queue #(
    .QUEUE_WID        (ADDR_WID),
    .QUEUE_ELEMENT_NUM(1),
    .FUNC_RANDOM_IN    (1))
inst_hazard_wait_buff(
    .clk(clk),
    .rst(!resetn),

    .element_in(inst_addr),
    .in_valid(inst_req && !inst_wr),
    .in_ready(inst_addr_ok),
    .in_ready_co(1'h1),
    .element_out(inst_addr_hazardwait),
    .out_valid(inst_req_hazardwait),
    .out_ready(inst_addr_ok_wait && inst_addr_ok_response),

    .head_element(inst_hazard_wait_buff_todetect),
    .random_in_1(inst_hazard_wait_buff_todetect),
    .tok_1(1'h1),
    .random_in_valid_1(!inst_RAW_hazard),

    //.random_in_2(),
    //.tok_2(),
    .random_in_valid_2(1'h0)
);
//data hazard wait buffer

queue #(
    .QUEUE_WID        (ADDR_WID),
    .QUEUE_ELEMENT_NUM(1),
    .FUNC_RANDOM_IN    (1))
data_read_hazard_wait_buff(
    .clk(clk),
    .rst(!resetn),

    .element_in(data_addr),
    .in_valid(data_req && !data_wr),
    .in_ready(data_addr_ok_read),
    .in_ready_co(1'h1),
    .element_out(data_addr_read_hazardwait),
    .out_valid(data_req_read_hazardwait),
    .out_ready(data_addr_ok_read_wait && data_addr_ok_read_tok && data_addr_ok_reorder),

    .head_element(data_read_hazard_wait_buff_todetect),
    .random_in_1(data_read_hazard_wait_buff_todetect),
    .tok_1(1'h1),
    .random_in_valid_1(!data_RAW_hazard),

    //.random_in_2(),
    //.tok_2(),
    .random_in_valid_2(1'h0)
);
//axi read ID0 wait buffer
queue #(
    .QUEUE_WID        (ADDR_WID),
    .QUEUE_ELEMENT_NUM(RID0_INFO_NUM))
queue_arid0(
    .clk(clk),
    .rst(!resetn),

    .element_in(inst_addr_hazardwait),
    .in_valid(inst_req_hazardwait),
    .in_ready(inst_addr_ok_wait),
    .in_ready_co(inst_addr_ok_response),

    .element_out(araddr_inst),
    .out_valid(arvalid_inst),
    .out_ready(arready && axi_ar_from_inst)  //no logic loop?
);

//axi read ID0 is inst, no re-order, so no token

//axi read ID1 wait buffer
queue #(
    .QUEUE_WID        (ADDR_WID),
    .QUEUE_ELEMENT_NUM(RID1_INFO_NUM))
queue_arid1(
    .clk(clk),
    .rst(!resetn),

    .element_in(data_addr_read_hazardwait),
    .in_valid(data_req_read_hazardwait),
    .in_ready(data_addr_ok_read_wait),
    .in_ready_co(data_addr_ok_read_tok && data_addr_ok_reorder),

    .element_out(araddr_data),
    .out_valid(arvalid_data),
    .out_ready(arready && !axi_ar_from_inst)
);

queue #(
    .QUEUE_WID        (DATA_REORDER_BUFF_NUM),
    .QUEUE_ELEMENT_NUM(RID1_TOK_NUM),
    .FUNC_FORWARD(0))
queue_arid1_tok(
    .clk(clk),
    .rst(!resetn),

    .element_in(tok_in),
    .in_valid(data_req_read_hazardwait),
    .in_ready(data_addr_ok_read_tok),
    .in_ready_co(data_addr_ok_read_wait && data_addr_ok_reorder),

    .element_out(arid1_tok_out),
    //.out_valid(),
    .out_ready(axi_rid1_finish)  //no logic loop?
);

//axi write ID0 is inst, no write

//axi write ID1 wait buffer
queue #(
    .QUEUE_WID        (ADDR_WID-2),
    .QUEUE_ELEMENT_NUM(WID1_INFO_NUM))
queue_awid1(
    .clk(clk),
    .rst(!resetn),

    .element_in(data_addr[ADDR_WID-1:2]),
    .in_valid(data_req && data_wr),
    .in_ready(data_addr_ok_write_wait_addr),
    .in_ready_co(data_addr_ok_write_wait_data && data_addr_ok_write_tok && data_addr_ok_reorder && last_data_addr_ok_read),

    .element_out(awaddr[ADDR_WID-1:2]),
    .out_valid(awvalid),
    .out_ready(awready)
);

queue #(
    .QUEUE_WID        (DATA_WID + STRB_WID),
    .QUEUE_ELEMENT_NUM(WID1_INFO_NUM))
queue_wid1(
    .clk(clk),
    .rst(!resetn),

    .element_in({data_wdata,compute_strb}),
    .in_valid(data_req && data_wr),
    .in_ready(data_addr_ok_write_wait_data),
    .in_ready_co(data_addr_ok_write_wait_addr && data_addr_ok_write_tok && data_addr_ok_reorder && last_data_addr_ok_read),

    .element_out({wdata, wstrb}),
    .out_valid(wvalid),
    .out_ready(wready)
);

queue #(
    .QUEUE_WID        (DATA_REORDER_BUFF_NUM),
    .QUEUE_ELEMENT_NUM(WID1_TOK_NUM),
    .FUNC_FORWARD(0))
queue_wid1_tok(
    .clk(clk),
    .rst(!resetn),

    .element_in(tok_in),
    .in_valid(data_req && data_wr),
    .in_ready(data_addr_ok_write_tok),
    .in_ready_co(data_addr_ok_write_wait_addr && data_addr_ok_write_wait_data && data_addr_ok_reorder && last_data_addr_ok_read),

    .element_out(wid1_tok_out),
    //.out_valid(),
    .out_ready(axi_bid1_finish)  //no logic loop
);

//sram inst response buffer
queue #(
    .QUEUE_WID        (DATA_WID),
    .QUEUE_ELEMENT_NUM(INST_RESPONSE_BUFF_NUM),
    .FUNC_RANDOM_IN(1))
queue_inst_response_buff(
    .clk(clk),
    .rst(!resetn),

    //.element_in(),
    .in_valid(inst_req_hazardwait),
    .in_ready(inst_addr_ok_response),
    .in_ready_co(inst_addr_ok_wait),
    //.tail_tok(),

    .random_in_1(rdata),
    .tok_1(inst_response_tok),
    .random_in_valid_1(axi_rid0_finish),

    //.random_in_2(),
    //.tok_2(wid1_tok_out),
    .random_in_valid_2(1'h0),    

    .element_out(inst_rdata),
    .out_valid(inst_data_ok),
    .out_ready(1'h1)
);

//sram data re-order buffer
queue #(
    .QUEUE_WID        (DATA_WID),
    .QUEUE_ELEMENT_NUM(DATA_REORDER_BUFF_NUM),
    .FUNC_RANDOM_IN(1))
queue_data_reorder_buff(
    .clk(clk),
    .rst(!resetn),

    //.element_in(),
    .in_valid(data_wr && data_req
           || data_req_read_hazardwait),
    .in_ready(data_addr_ok_reorder),
    .in_ready_co(data_wr && data_addr_ok_write_wait_addr && data_addr_ok_write_wait_data && data_addr_ok_write_tok && last_data_addr_ok_read
              || data_req_read_hazardwait && data_addr_ok_read_wait && data_addr_ok_read_tok),
    .tail_tok(tok_in),

    .random_in_1(rdata),
    .tok_1(arid1_tok_out),
    .random_in_valid_1(axi_rid1_finish),

    //.random_in_2(),  //this is a waste
    .tok_2(wid1_tok_out),
    .random_in_valid_2(axi_bid1_finish),

    .element_out(data_rdata),
    .out_valid(data_data_ok),
    .out_ready(1'h1)
);

queue #(
    .QUEUE_WID        (ADDR_WID-2),
    .QUEUE_ELEMENT_NUM(WID1_TOK_NUM),
    .FUNC_HAZARD_DETECT(1))
queue_hazard_detect(
    .clk(clk),
    .rst(!resetn),

    .element_in(data_addr[ADDR_WID-1:2]),
    .in_valid(data_req && data_wr),
    //.in_ready(),
    .in_ready_co(/*data_addr_ok_write_tok && */data_addr_ok_write_wait_addr && data_addr_ok_write_wait_data && data_addr_ok_reorder && last_data_addr_ok_read),

    //.element_out(),
    //.out_valid(),
    .out_ready(axi_bid1_finish),

    .detect_1(inst_hazard_wait_buff_todetect[ADDR_WID-1:2]),
    .hazard_1(inst_RAW_hazard),
    .detect_2(data_read_hazard_wait_buff_todetect[ADDR_WID-1:2]),
    .hazard_2(data_RAW_hazard)
);

endmodule