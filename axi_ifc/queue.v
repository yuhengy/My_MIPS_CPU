module queue #
(
	parameter QUEUE_WID         = 100,
	parameter QUEUE_ELEMENT_NUM = 4  ,

	parameter FUNC_RANDOM_IN     = 0  ,
	parameter FUNC_HAZARD_DETECT = 0  ,
	parameter FUNC_FORWARD       = 1
)
(
	input                  clk         ,
	input                  rst         ,

	input  [QUEUE_WID-1:0] element_in  ,
	input                  in_valid    ,
	output                 in_ready    ,  //not full or out_ready
	input                  in_ready_co ,  //another in_valid

	output [QUEUE_WID-1:0] element_out ,
	output                 out_valid   , //not empty or in_valid
	//input                  out_valid_co,
	//for a more general module to support out_valid_co, need redesign to avoid logic loop
	input                  out_ready   ,

//FUNC_RANDOM_IN==1
	output [QUEUE_ELEMENT_NUM-1:0] tail_tok         ,
	output [QUEUE_WID-1:0]         head_element     ,
	input                          random_in_valid_1,
	input  [QUEUE_WID-1:0]         random_in_1      ,
	input  [QUEUE_ELEMENT_NUM-1:0] tok_1            ,
	input                          random_in_valid_2,
	input  [QUEUE_WID-1:0]         random_in_2      ,
	input  [QUEUE_ELEMENT_NUM-1:0] tok_2            ,

//FUNC_HAZARD_DETECT==1
	input  [QUEUE_WID-1:0] detect_1,
	output                 hazard_1,
	input  [QUEUE_WID-1:0] detect_2,
	output                 hazard_2
);

reg [QUEUE_WID-1:0]         queue [QUEUE_ELEMENT_NUM-1:0];
reg [QUEUE_ELEMENT_NUM-1:0] head;  //one-hot code
reg [QUEUE_ELEMENT_NUM-1:0] tail;  //one-hot code
wire enqueue, dequeue;  //both enqueue and dequeue when forward
wire forward, replace;
wire empty, full;
reg keepfull_or_elementup_last_clk;

//FUNC_RANDOM_IN==1
reg [QUEUE_ELEMENT_NUM-1:0] have_random_in;
wire random_in_forward_1, random_in_forward_2;

//FUNC_HAZARD_DETECT==1
reg  [QUEUE_ELEMENT_NUM-1:0] valid_element;  //update valid_element every cycle
wire [QUEUE_ELEMENT_NUM-1:0] hazard_happen_1, hazard_happen_2;

//-----------general for all queue------------
//element out
wire [QUEUE_ELEMENT_NUM-1:0] queue_T [QUEUE_WID-1:0];
wire [QUEUE_WID-1:0] element_out_r;
genvar i, j;
generate for(i=0; i<QUEUE_ELEMENT_NUM; i=i+1) begin: queue_T_i
	for(j=0; j<QUEUE_WID; j=j+1) begin: queue_T_j
		assign queue_T[j][i] = queue[i][j];
	end
end endgenerate
generate for(i=0; i<QUEUE_WID; i=i+1) begin: queue_dequeue
	assign element_out_r[i] = |(queue_T[i] & head);
end endgenerate

generate if(FUNC_RANDOM_IN==1) begin: generate_element_out_random_in
	assign element_out = random_in_forward_1? random_in_1:
	                     random_in_forward_2? random_in_2:
	                                          element_out_r;
end else begin: generate_element_out_not_random_in
		assign element_out = forward? element_in: element_out_r;
end endgenerate


//element in
generate if(FUNC_RANDOM_IN==1) begin: generate_element_in_random_in
	for(i=0; i<QUEUE_ELEMENT_NUM; i=i+1) begin: queue_enqueue
		always @(posedge clk)  //these conditions won't happen together
			if(enqueue && tail[i])
				queue[i] <= element_in;
			else if(random_in_valid_1 && tok_1[i])
				queue[i] <= random_in_1;
			else if(random_in_valid_2 && tok_2[i])
				queue[i] <= random_in_2;
	end
end else begin: generate_element_in_not_random_in
	for(i=0; i<QUEUE_ELEMENT_NUM; i=i+1) begin: queue_enqueue
		always @(posedge clk)
			if(enqueue && tail[i])
				queue[i] <= element_in;
	end
end endgenerate

//head, tail
generate if(QUEUE_ELEMENT_NUM==1) begin: generate_element_num_is_1
	always @(posedge clk)
		if(rst)
			head <= {{(QUEUE_ELEMENT_NUM-1){1'b0}},1'b1};
	always @(posedge clk)
		if(rst)
			tail <= {{(QUEUE_ELEMENT_NUM-1){1'b0}},1'b1};
end else begin: generate_element_num_isnot_1
	always @(posedge clk)
		if(rst)
			head <= {{(QUEUE_ELEMENT_NUM-1){1'b0}},1'b1};
		else if(dequeue)
			head <= {head[QUEUE_ELEMENT_NUM-2:0], head[QUEUE_ELEMENT_NUM-1]};
	always @(posedge clk)
		if(rst)
			tail <= {{(QUEUE_ELEMENT_NUM-1){1'b0}},1'b1};
		else if(enqueue)
			tail <= {tail[QUEUE_ELEMENT_NUM-2:0], tail[QUEUE_ELEMENT_NUM-1]};
end endgenerate

//control logic
assign in_ready  = !full || replace;  //when full, out_valid must be 1
generate if(FUNC_RANDOM_IN==1) begin: generate_out_valid_random_in
	assign out_valid = (!empty || forward)
	                && ((&(have_random_in&head)) || random_in_forward_1 || random_in_forward_2);
end else begin: generate_out_valid_not_random_in
	assign out_valid = !empty || forward;
end endgenerate

assign enqueue = in_valid  && in_ready  && in_ready_co ;
assign dequeue = out_ready && out_valid;

generate if(FUNC_FORWARD==1) begin: generate_forward_haveforward
	assign forward = in_valid  && in_ready_co  && empty;
end else begin: generate_forward_notforward
	assign forward = 1'h0;
end endgenerate

generate if(FUNC_RANDOM_IN==1) begin: generate_replace_random_in
	assign replace = out_ready && full
	              && ((&(have_random_in&head)) || random_in_forward_1 || random_in_forward_2);
end else begin: generate_replace_not_random_in
	assign replace = out_ready && full;
end endgenerate

assign empty   = head==tail && !keepfull_or_elementup_last_clk;
assign full    = head==tail &&  keepfull_or_elementup_last_clk;
always @(posedge clk)
	if(rst)
		keepfull_or_elementup_last_clk <= 1'h0;
	else if(full && (!dequeue || enqueue&&dequeue)
		 || enqueue && !dequeue)
		keepfull_or_elementup_last_clk <= 1'h1;
	else
		keepfull_or_elementup_last_clk <= 1'h0;


//-----------specific for FUNC_RANDOM_IN==1------------
generate if(FUNC_RANDOM_IN==1) begin: generate_haverandomin_random_in

//messy fix
	for(i=0; i<QUEUE_ELEMENT_NUM; i=i+1) begin: set_valid_element_random_in
		always @(posedge clk)
			if(rst)
				valid_element[i] <= 1'h0;
			else if(enqueue && !(forward && dequeue) && !(replace && dequeue) && tail[i])
				valid_element[i] <= 1'h1;
			else if(dequeue && !(forward && enqueue) && !(replace && enqueue) && head[i])
				valid_element[i] <= 1'h0;
			//do nothing when forward or replace
	end
		//random in forward
		assign random_in_forward_1 = random_in_valid_1 && tok_1==head;
		assign random_in_forward_2 = random_in_valid_2 && tok_2==head;

		//extra information for random in
		assign tail_tok = tail;
		assign head_element = forward? element_in: element_out_r;
	for(i=0; i<QUEUE_ELEMENT_NUM; i=i+1) begin: set_have_random_in
		//control: have random in
		always @(posedge clk)  //random in may be dequeue forwardly
			if(rst)
				have_random_in[i] <= 1'h0;
			else if(dequeue && head[i])
				have_random_in[i] <= 1'h0;
			else if(random_in_valid_1 && tok_1[i] && valid_element[i]) //messy fix
				have_random_in[i] <= 1'h1;
			else if(random_in_valid_2 && tok_2[i] && valid_element[i])
				have_random_in[i] <= 1'h1;
	end
end endgenerate

//-----------specific for FUNC_HAZARD_DETECT==1------------
generate if(FUNC_HAZARD_DETECT==1) begin: generate_valid_element_hazard_detect
//set_valid_element
	for(i=0; i<QUEUE_ELEMENT_NUM; i=i+1) begin: set_valid_element
		always @(posedge clk)
			if(rst)
				valid_element[i] <= 1'h0;
			else if(enqueue && !(forward && dequeue) && !(replace && dequeue) && tail[i])
				valid_element[i] <= 1'h1;
			else if(dequeue && !(forward && enqueue) && !(replace && enqueue) && head[i])
				valid_element[i] <= 1'h0;
			//do nothing when forward or replace
	end

//hazard
	for(i=0; i<QUEUE_ELEMENT_NUM; i=i+1) begin: find_hazard_element
		assign hazard_happen_1[i] = detect_1[3:0]==queue[i][3:0] && valid_element[i] && !(head[i] && out_ready &&(!empty));  //ok?
		assign hazard_happen_2[i] = detect_2[3:0]==queue[i][3:0] && valid_element[i] && !(head[i] && out_ready &&(!empty));  //ok?
		/*** for higher frequency
		assign hazard_happen_1[i] = detect_1[QUEUE_ELEMENT_NUM/2:0]==queue[i][QUEUE_ELEMENT_NUM/2:0] && !(head[i] && out_ready &&(!empty));
		assign hazard_happen_2[i] = detect_2[QUEUE_ELEMENT_NUM/2:0]==queue[i][QUEUE_ELEMENT_NUM/2:0] && !(head[i] && out_ready &&(!empty));
		***/
	end
	assign hazard_1 = |hazard_happen_1;
	assign hazard_2 = |hazard_happen_2;
end endgenerate

endmodule