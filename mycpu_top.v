module mycpu_top(
    input         clk,
    input         resetn,
    // inst sram interface
    output        inst_sram_en,
    output [ 3:0] inst_sram_wen,
    output [31:0] inst_sram_addr,
    output [31:0] inst_sram_wdata,
    input  [31:0] inst_sram_rdata,
    // data sram interface
    output        data_sram_en,
    output [ 3:0] data_sram_wen,
    output [31:0] data_sram_addr,
    output [31:0] data_sram_wdata,
    input  [31:0] data_sram_rdata,
    // trace debug interface
    output [31:0] debug_wb_pc,
    output [ 3:0] debug_wb_rf_wen,
    output [ 4:0] debug_wb_rf_wnum,
    output [31:0] debug_wb_rf_wdata
);
reg         reset;
always @(posedge clk) reset <= ~resetn;

wire [5:0]   ext_int_in;
assign ext_int_in = 6'h0;

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
    .inst_sram_en   (inst_sram_en   ),
    .inst_sram_wen  (inst_sram_wen  ),
    .inst_sram_addr (inst_sram_addr ),
    .inst_sram_wdata(inst_sram_wdata),
    .inst_sram_rdata(inst_sram_rdata)
);
// ID stage
id_stage id_stage(
    .clk            (clk            ),
    .reset          (reset          ),
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
    // data sram interface
    .data_sram_en   (data_sram_en   ),
    .data_sram_wen  (data_sram_wen  ),
    .data_sram_addr (data_sram_addr ),
    .data_sram_wdata(data_sram_wdata)
);
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
    //from data-sram
    .data_sram_rdata(data_sram_rdata)
);
// WB stage
wb_stage wb_stage(
    .clk            (clk            ),
    .reset          (reset          ),
    .ext_int_in     (ext_int_in     ),
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
    .send_flush     (flush          ),
    //exc eret
    .ws_exc_eret_bus(ws_to_es_exc_eret_bus),
    .exc_eret_bus   (exc_eret_bus   ),
    //trace debug interface
    .debug_wb_pc      (debug_wb_pc      ),
    .debug_wb_rf_wen  (debug_wb_rf_wen  ),
    .debug_wb_rf_wnum (debug_wb_rf_wnum ),
    .debug_wb_rf_wdata(debug_wb_rf_wdata)
);

endmodule
