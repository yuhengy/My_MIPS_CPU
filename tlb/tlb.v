module tlb #
(
    parameter TLBNUM = 16
)
(
    //input                       rst,
    input                       clk,

    //search port 0
    input  [              18:0] s0_vpn2,
    input                       s0_odd_page,
    input  [               7:0] s0_asid,
    output                      s0_found,
    output [$clog2(TLBNUM)-1:0] s0_index,
    output [              19:0] s0_pfn,
    output [               2:0] s0_c,
    output                      s0_d,
    output                      s0_v,
    output                      s0_Refill_r,
    output                      s0_Invalid_r,

    //search port 1
    input  [              18:0] s1_vpn2,
    input                       s1_odd_page,
    input  [               7:0] s1_asid,
    output                      s1_found,
    output [$clog2(TLBNUM)-1:0] s1_index,
    output [              19:0] s1_pfn,
    output [               2:0] s1_c,
    output                      s1_d,
    output                      s1_v,
    input                       store,
    output                      s1_Refill_r,
    output                      s1_Invalid_r,
    output                      s1_Refill_s,
    output                      s1_Invalid_s,
    output                      s1_Modified,

    //write port
    input                       we,
    input  [$clog2(TLBNUM)-1:0] w_index,
    input  [              18:0] w_vpn2,
    input  [               7:0] w_asid,
    input                       w_g,
    input  [              19:0] w_pfn0,
    input  [               2:0] w_c0,
    input                       w_d0,
    input                       w_v0,
    input  [              19:0] w_pfn1,
    input  [               2:0] w_c1,
    input                       w_d1,
    input                       w_v1,

    //read port
    input  [$clog2(TLBNUM)-1:0] r_index,
    output [              18:0] r_vpn2,
    output [               7:0] r_asid,
    output                      r_g,
    output [              19:0] r_pfn0,
    output [               2:0] r_c0,
    output                      r_d0,
    output                      r_v0,
    output [              19:0] r_pfn1,
    output [               2:0] r_c1,
    output                      r_d1,
    output                      r_v1
);

reg [18:0] tlb_vpn2 [TLBNUM-1:0];
reg [ 7:0] tlb_asid [TLBNUM-1:0];
reg        tlb_g    [TLBNUM-1:0];
reg [19:0] tlb_pfn0 [TLBNUM-1:0];
reg [ 2:0] tlb_c0   [TLBNUM-1:0];
reg        tlb_d0   [TLBNUM-1:0];
reg        tlb_v0   [TLBNUM-1:0];
reg [19:0] tlb_pfn1 [TLBNUM-1:0];
reg [ 2:0] tlb_c1   [TLBNUM-1:0];
reg        tlb_d1   [TLBNUM-1:0];
reg        tlb_v1   [TLBNUM-1:0];

//write
always @(posedge clk)
    if(we) begin
        tlb_vpn2[w_index] <= w_vpn2;
        tlb_asid[w_index] <= w_asid;
        tlb_g   [w_index] <= w_g;
        tlb_pfn0[w_index] <= w_pfn0;
        tlb_c0  [w_index] <= w_c0;
        tlb_d0  [w_index] <= w_d0;
        tlb_v0  [w_index] <= w_v0;
        tlb_pfn1[w_index] <= w_pfn1;
        tlb_c1  [w_index] <= w_c1;
        tlb_d1  [w_index] <= w_d1;
        tlb_v1  [w_index] <= w_v1;
    end

//Transpose for out select
wire [TLBNUM-1:0] tlb_vpn2_T [18:0];
wire [TLBNUM-1:0] tlb_asid_T [ 7:0];
wire [TLBNUM-1:0] tlb_g_T          ;
wire [TLBNUM-1:0] tlb_pfn0_T [19:0];
wire [TLBNUM-1:0] tlb_c0_T   [ 2:0];
wire [TLBNUM-1:0] tlb_d0_T         ;
wire [TLBNUM-1:0] tlb_v0_T         ;
wire [TLBNUM-1:0] tlb_pfn1_T [19:0];
wire [TLBNUM-1:0] tlb_c1_T   [ 2:0];
wire [TLBNUM-1:0] tlb_d1_T         ;
wire [TLBNUM-1:0] tlb_v1_T         ;
wire [TLBNUM-1:0] tlb_index_T  [$clog2(TLBNUM)-1:0];

genvar i, j;
generate for(i=0; i<TLBNUM; i=i+1) begin: Transpse_i
    for(j=0; j<19; j=j+1) begin: tlb_vpn2_T_j
        assign tlb_vpn2_T [j][i] = tlb_vpn2[i][j];
    end
    for(j=0; j< 8; j=j+1) begin: tlb_asid_T_j
        assign tlb_asid_T [j][i] = tlb_asid[i][j];
    end
        assign tlb_g_T       [i] = tlb_g   [i]   ;
    for(j=0; j<20; j=j+1) begin: tlb_pfn0_T_j
        assign tlb_pfn0_T [j][i] = tlb_pfn0[i][j];
    end
    for(j=0; j< 3; j=j+1) begin: tlb_c0_T_j
        assign tlb_c0_T   [j][i] = tlb_c0  [i][j];
    end
        assign tlb_d0_T      [i] = tlb_d0  [i]   ;
        assign tlb_v0_T      [i] = tlb_v0  [i]   ;
    for(j=0; j<20; j=j+1) begin: tlb_pfn1_T_j
        assign tlb_pfn1_T [j][i] = tlb_pfn1[i][j];
    end
    for(j=0; j< 3; j=j+1) begin: tlb_c1_T_j
        assign tlb_c1_T   [j][i] = tlb_c1  [i][j];
    end
        assign tlb_d1_T      [i] = tlb_d1  [i]   ;
        assign tlb_v1_T      [i] = tlb_v1  [i]   ;
    for(j=0; j<$clog2(TLBNUM); j=j+1) begin: tlb_index_T_j
        assign tlb_index_T[j][i] = (i>>j);
    end
end endgenerate

//search port 0
    //s0_found_entry
wire [TLBNUM-1:0] s0_found_entry;
generate for(i=0; i<TLBNUM; i=i+1) begin: gen_s0_found_entry
    assign s0_found_entry[i] = (s0_vpn2==tlb_vpn2[i]) && ((s0_asid==tlb_asid[i]) || tlb_g[i]);
end endgenerate
    //found
    assign s0_found = |s0_found_entry;

    //out
generate for(j=0; j<$clog2(TLBNUM); j=j+1) begin: gen_s0_index
    assign s0_index [j]= |(s0_found_entry & tlb_index_T[j]);
end endgenerate
generate for(j=0; j<20; j=j+1) begin: gen_s0_pfn
    assign s0_pfn   [j]= |(s0_found_entry & (s0_odd_page? tlb_pfn1_T[j]:
                                                          tlb_pfn0_T[j]));
end endgenerate
generate for(j=0; j< 3; j=j+1) begin: gen_s0_c
    assign s0_c     [j]= |(s0_found_entry & (s0_odd_page? tlb_c1_T[j]:
                                                          tlb_c0_T[j]));
end endgenerate
    assign s0_d        = |(s0_found_entry & (s0_odd_page? tlb_d1_T   :
                                                          tlb_d0_T   ));
    assign s0_v        = |(s0_found_entry & (s0_odd_page? tlb_v1_T   :
                                                          tlb_v0_T   ));

//search port 1
    //s1_found_entry
wire [TLBNUM-1:0] s1_found_entry;
generate for(i=0; i<TLBNUM; i=i+1) begin: gen_s1_found_entry
    assign s1_found_entry[i] = (s1_vpn2==tlb_vpn2[i]) && ((s1_asid==tlb_asid[i]) || tlb_g[i]);
end endgenerate
    //found
    assign s1_found = |s1_found_entry;

    //out
generate for(j=0; j<$clog2(TLBNUM); j=j+1) begin: gen_s1_index
    assign s1_index [j]= |(s1_found_entry & tlb_index_T[j]);
end endgenerate
generate for(j=0; j<20; j=j+1) begin: gen_s1_pfn
    assign s1_pfn   [j]= |(s1_found_entry & (s1_odd_page? tlb_pfn1_T[j]:
                                                          tlb_pfn0_T[j]));
end endgenerate
generate for(j=0; j< 3; j=j+1) begin: gen_s1_c
    assign s1_c     [j]= |(s1_found_entry & (s1_odd_page? tlb_c1_T[j]:
                                                          tlb_c0_T[j]));
end endgenerate
    assign s1_d        = |(s1_found_entry & (s1_odd_page? tlb_d1_T   :
                                                          tlb_d0_T   ));
    assign s1_v        = |(s1_found_entry & (s1_odd_page? tlb_v1_T   :
                                                          tlb_v0_T   ));

//read port
    //r_index_entry
wire [TLBNUM-1:0] r_index_entry;
generate for(i=0; i<TLBNUM; i=i+1) begin: gen_r_index_entry
    assign r_index_entry[i] = r_index==i;
end endgenerate

    //out
generate for(j=0; j<19; j=j+1) begin: gen_r_vpn2
    assign r_vpn2[j] = |(r_index_entry & tlb_vpn2_T[j]);
end endgenerate
generate for(j=0; j< 8; j=j+1) begin: gen_r_asid
    assign r_asid[j] = |(r_index_entry & tlb_asid_T[j]);
end endgenerate
    assign r_g = |(r_index_entry & tlb_g_T);
generate for(j=0; j<20; j=j+1) begin: gen_r_pfn0
    assign r_pfn0[j] = |(r_index_entry & tlb_pfn0_T[j]);
end endgenerate
generate for(j=0; j< 3; j=j+1) begin: gen_r_c0
    assign r_c0  [j] = |(r_index_entry & tlb_c0_T  [j]);
end endgenerate
    assign r_d0      = |(r_index_entry & tlb_d0_T);
    assign r_v0      = |(r_index_entry & tlb_v0_T);
generate for(j=0; j<20; j=j+1) begin: gen_r_pfn1
    assign r_pfn1[j] = |(r_index_entry & tlb_pfn1_T[j]);
end endgenerate
generate for(j=0; j< 3; j=j+1) begin: gen_r_c1
    assign r_c1  [j] = |(r_index_entry & tlb_c1_T  [j]);
end endgenerate
    assign r_d1      = |(r_index_entry & tlb_d1_T     );
    assign r_v1      = |(r_index_entry & tlb_v1_T     );

TLB_exc_judge TLB_exc_judge_s0(
    .found(s0_found),
    .V    (s0_v    ),
    .D    (s0_d    ),
    .store(1'h0    ),

    .Refill_r(s0_Refill_r),
    .Invalid_r(s0_Invalid_r)
    //.Refill_Invalid_s(),
    //.Modified()
);
TLB_exc_judge TLB_exc_judge_s1(
    .found(s1_found),
    .V    (s1_v    ),
    .D    (s1_d    ),
    .store(store   ),

    .Refill_r (s1_Refill_r ),
    .Invalid_r(s1_Invalid_r),
    .Refill_s (s1_Refill_s ),
    .Invalid_s(s1_Invalid_s),
    .Modified (s1_Modified )
);

endmodule