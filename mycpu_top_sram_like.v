module mycpu_top_sram_like # (
    parameter TLBNUM = 16
)
(
    input  [ 5:0] ext_int_in,
    input         clk,
    input         resetn,
    // inst sram-like interface
    output        inst_sram_req,
    output        inst_sram_wr,
    output [ 1:0] inst_sram_size,
    output [ 3:0] inst_sram_wstrb,
    output [31:0] inst_sram_addr,
    output [31:0] inst_sram_wdata,
    input         inst_sram_addr_ok,
    input         inst_sram_data_ok,
    input  [31:0] inst_sram_rdata,
    // data sram interface
    output        data_sram_req,
    output        data_sram_wr,
    output [ 1:0] data_sram_size,
    output [ 3:0] data_sram_wstrb,
    output [31:0] data_sram_addr,
    output [31:0] data_sram_wdata,
    input         data_sram_addr_ok,
    input         data_sram_data_ok,
    input  [31:0] data_sram_rdata,
    // trace debug interface
    output [31:0] debug_wb_pc,
    output [ 3:0] debug_wb_rf_wen,
    output [ 4:0] debug_wb_rf_wnum,
    output [31:0] debug_wb_rf_wdata
);
reg         reset;
always @(posedge clk) reset <= ~resetn;

wire         int_happen;
wire         flush;
wire         ds_allowin;
wire         es_allowin;
wire         ms_allowin;
wire         ws_allowin;
wire         fs_to_ds_valid;
wire         ds_to_es_valid;
wire         es_to_ms_valid;
wire         ms_to_ws_valid;
wire [`FS_TO_DS_BUS_WD -1:0] fs_to_ds_bus;
wire [`DS_TO_ES_BUS_WD -1:0] ds_to_es_bus;
wire [`ES_TO_MS_BUS_WD -1:0] es_to_ms_bus;
wire [`MS_TO_WS_BUS_WD -1:0] ms_to_ws_bus;
wire [`WS_TO_RF_BUS_WD -1:0] ws_to_rf_bus;
wire [`BR_BUS_WD       -1:0] br_bus;
wire [                  1:0] ms_to_es_exc_eret_bus;
wire [                  1:0] ws_to_es_exc_eret_bus;
wire [`EXC_ERET_BUS_WD -1:0] exc_eret_bus;
wire [`STALL_BUS_WD    -1:0] stall_es_bus;
wire [`STALL_BUS_WD    -1:0] stall_ms_bus;
wire [`STALL_BUS_WD    -1:0] stall_ws_bus;
wire [`FORWARD_BUS_WD  -1:0] forward_es_bus;
wire [`FORWARD_BUS_WD  -1:0] forward_ms_bus;
wire [`FORWARD_BUS_WD  -1:0] forward_ws_bus;
wire [                  1:0] entryhi_stall_bus;
wire [31:0] cp0_entryhi;

wire [              18:0]   tlb_s0_vpn2;
wire                        tlb_s0_odd_page;
wire [               7:0]   tlb_s0_asid;
wire                        tlb_s0_found;
wire [$clog2(TLBNUM)-1:0]   tlb_s0_index;
wire [              19:0]   tlb_s0_pfn;
wire [               2:0]   tlb_s0_c;
wire                        tlb_s0_d;
wire                        tlb_s0_v;

wire [              18:0]   tlb_s1_vpn2;
wire                        tlb_s1_odd_page;
wire [               7:0]   tlb_s1_asid;
wire                        tlb_s1_found;
wire [$clog2(TLBNUM)-1:0]   tlb_s1_index;
wire [              19:0]   tlb_s1_pfn;
wire [               2:0]   tlb_s1_c;
wire                        tlb_s1_d;
wire                        tlb_s1_v;

wire [$clog2(TLBNUM)-1:0]   tlb_wr_index;

wire                        tlb_we;
wire [ `TLB_ENTRY_WD-1:0]   tlb_w_entry;

wire [ `TLB_ENTRY_WD-1:0]   tlb_r_entry;

wire tlbp_valid;

wire ws_send_flush;
reg tlb_flush_r;
wire ws_tlb_flush;

assign flush = ws_send_flush || tlb_flush_r;

always @(posedge clk) begin
    if (reset) begin
        tlb_flush_r <= 0;
    end
    else begin
        tlb_flush_r <= ws_tlb_flush;
    end
end

// IF stage
if_stage if_stage(
    .clk            (clk            ),
    .reset          (reset          ),
    .flush          (flush          ),
    //allowin
    .ds_allowin     (ds_allowin     ),
    //brbus
    .br_bus         (br_bus         ),
    //exc eret
    .exc_eret_bus   (exc_eret_bus   ),
    //outputs
    .fs_to_ds_valid (fs_to_ds_valid ),
    .fs_to_ds_bus   (fs_to_ds_bus   ),
    // inst sram interface
    .inst_sram_req  (inst_sram_req  ),
    .inst_sram_wen  (inst_sram_wstrb),
    .inst_sram_addr (inst_sram_addr ),
    .inst_sram_wdata(inst_sram_wdata),
    .inst_sram_addr_ok(inst_sram_addr_ok),
    .inst_sram_data_ok(inst_sram_data_ok),
    .inst_sram_rdata(inst_sram_rdata)
);

assign inst_sram_wr = 0;
assign inst_sram_size = 2'b10;

// ID stage
id_stage id_stage(
    .clk            (clk            ),
    .reset          (reset          ),
    .int_happen     (int_happen     ),
    .flush          (flush          ),
    //allowin
    .es_allowin     (es_allowin     ),
    .ds_allowin     (ds_allowin     ),
    //from fs
    .fs_to_ds_valid (fs_to_ds_valid ),
    .fs_to_ds_bus   (fs_to_ds_bus   ),
    //to es
    .ds_to_es_valid (ds_to_es_valid ),
    .ds_to_es_bus   (ds_to_es_bus   ),
    //to fs
    .br_bus         (br_bus         ),
    //to ds stall
    .stall_ds_bus   ({stall_es_bus   ,
                      stall_ms_bus   ,
                      stall_ws_bus }),
    .forward_ds_bus ({forward_es_bus ,
                      forward_ms_bus ,
                      forward_ws_bus}),
    //to rf: for write back
    .ws_to_rf_bus   (ws_to_rf_bus   )
);
// EXE stage
exe_stage exe_stage(
    .clk            (clk            ),
    .reset          (reset          ),
    .flush          (flush          ),
    //allowin
    .ms_allowin     (ms_allowin     ),
    .es_allowin     (es_allowin     ),
    //from ds
    .ds_to_es_valid (ds_to_es_valid ),
    .ds_to_es_bus   (ds_to_es_bus   ),
    //to ms
    .es_to_ms_valid (es_to_ms_valid ),
    .es_to_ms_bus   (es_to_ms_bus   ),
    //es to id stall
    .stall_es_bus   (stall_es_bus   ),
    .forward_es_bus (forward_es_bus ),
    //exc eret
    .es_exc_eret_bus({ms_to_es_exc_eret_bus,
                      ws_to_es_exc_eret_bus}),
    // TLB probe
    .tlbp_valid     (tlbp_valid     ),
    .tlbp_found     (tlb_s1_found   ),
    .tlbp_index     (tlb_s1_index   ),
    .entryhi_stall_bus(entryhi_stall_bus),
    // data sram interface
    .data_sram_req  (data_sram_req  ),
    .data_sram_wr   (data_sram_wr   ),
    .data_sram_wen  (data_sram_wstrb),
    .data_sram_addr (data_sram_addr ),
    .data_sram_wdata(data_sram_wdata),
    .data_sram_addr_ok(data_sram_addr_ok)
);

assign data_sram_size = 2'b10;

// MEM stage
mem_stage mem_stage(
    .clk            (clk            ),
    .reset          (reset          ),
    .flush          (flush          ),
    //allowin
    .ws_allowin     (ws_allowin     ),
    .ms_allowin     (ms_allowin     ),
    //from es
    .es_to_ms_valid (es_to_ms_valid ),
    .es_to_ms_bus   (es_to_ms_bus   ),
    //to ws
    .ms_to_ws_valid (ms_to_ws_valid ),
    .ms_to_ws_bus   (ms_to_ws_bus   ),
    //ms to id stall
    .stall_ms_bus   (stall_ms_bus   ),
    .forward_ms_bus (forward_ms_bus ),
    //exc eret
    .ms_exc_eret_bus(ms_to_es_exc_eret_bus),
    // TLBP: stall
    .ms_entryhi_hazard(entryhi_stall_bus[0]),
    //from data-sram
    .data_sram_data_ok(data_sram_data_ok),
    .data_sram_rdata(data_sram_rdata)
);
// WB stage
wb_stage wb_stage(
    .clk            (clk            ),
    .reset          (reset          ),
    .ext_int_in     (ext_int_in     ),
    .int_happen     (int_happen     ),
    .flush          (flush          ),
    //allowin
    .ws_allowin     (ws_allowin     ),
    //from ms
    .ms_to_ws_valid (ms_to_ws_valid ),
    .ms_to_ws_bus   (ms_to_ws_bus   ),
    //to rf: for write back
    .ws_to_rf_bus   (ws_to_rf_bus   ),
    //ws to id stall
    .stall_ws_bus   (stall_ws_bus   ),
    .forward_ws_bus (forward_ws_bus ),
    .send_flush     (ws_send_flush  ),
    .send_tlb_flush (ws_tlb_flush   ),
    //exc eret
    .ws_exc_eret_bus(ws_to_es_exc_eret_bus),
    .exc_eret_bus   (exc_eret_bus   ),
    // TLBP: stall
    .ws_entryhi_hazard(entryhi_stall_bus[1]),
    // TLBP
    .ws_entryhi     (cp0_entryhi    ),
    // TLBR, TLBWI
    .ws_tlb_index   (tlb_wr_index   ),
    .ws_tlb_wen     (tlb_we         ),
    .ws_tlbr_entry  (tlb_r_entry    ),
    .ws_tlbwi_entry (tlb_w_entry    ),
    //trace debug interface
    .debug_wb_pc      (debug_wb_pc      ),
    .debug_wb_rf_wen  (debug_wb_rf_wen  ),
    .debug_wb_rf_wnum (debug_wb_rf_wnum ),
    .debug_wb_rf_wdata(debug_wb_rf_wdata)
);

tlb u_tlb(
    .clk        (clk            ),

    // search port 0
    .s0_vpn2    (tlb_s0_vpn2    ),
    .s0_odd_page(tlb_s0_odd_page),
    .s0_asid    (tlb_s0_asid    ),
    .s0_found   (tlb_s0_found   ),
    .s0_index   (tlb_s0_index   ),
    .s0_pfn     (tlb_s0_pfn     ),
    .s0_c       (tlb_s0_c       ),
    .s0_d       (tlb_s0_d       ),
    .s0_v       (tlb_s0_v       ),

    // search port 1
    .s1_vpn2    (tlb_s1_vpn2    ),
    .s1_odd_page(tlb_s1_odd_page),
    .s1_asid    (tlb_s1_asid    ),
    .s1_found   (tlb_s1_found   ),
    .s1_index   (tlb_s1_index   ),
    .s1_pfn     (tlb_s1_pfn     ),
    .s1_c       (tlb_s1_c       ),
    .s1_d       (tlb_s1_d       ),
    .s1_v       (tlb_s1_v       ),

    // write port
    .we         (tlb_we         ),
    .w_index    (tlb_wr_index   ),
    .w_vpn2     (tlb_w_entry[77:59] ),
    .w_asid     (tlb_w_entry[58:51] ),
    .w_g        (tlb_w_entry[50]    ),
    .w_pfn0     (tlb_w_entry[49:30] ),
    .w_c0       (tlb_w_entry[29:27] ),
    .w_d0       (tlb_w_entry[26]    ),
    .w_v0       (tlb_w_entry[25]    ),
    .w_pfn1     (tlb_w_entry[24: 5] ),
    .w_c1       (tlb_w_entry[ 4: 2] ),
    .w_d1       (tlb_w_entry[ 1]    ),
    .w_v1       (tlb_w_entry[ 0]    ),

    // read port
    .r_index    (tlb_wr_index   ),
    .r_vpn2     (tlb_r_entry[77:59] ),
    .r_asid     (tlb_r_entry[58:51] ),
    .r_g        (tlb_r_entry[50]    ),
    .r_pfn0     (tlb_r_entry[49:30] ),
    .r_c0       (tlb_r_entry[29:27] ),
    .r_d0       (tlb_r_entry[26]    ),
    .r_v0       (tlb_r_entry[25]    ),
    .r_pfn1     (tlb_r_entry[24: 5] ),
    .r_c1       (tlb_r_entry[ 4: 2] ),
    .r_d1       (tlb_r_entry[ 1]    ),
    .r_v1       (tlb_r_entry[ 0]    )
);

assign tlb_s0_vpn2 = 19'b0;
assign tlb_s0_odd_page = 0;
assign tlb_s0_asid = 8'b0;
// TLBP ?
assign tlb_s1_vpn2 = cp0_entryhi[31:13];
assign tlb_s1_odd_page = 0;
assign tlb_s1_asid = cp0_entryhi[ 7: 0];

endmodule
