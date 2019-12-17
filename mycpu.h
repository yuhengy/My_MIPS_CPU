`ifndef MYCPU_H
    `define MYCPU_H

    `define BR_BUS_WD       34
    `define EXC_ERET_BUS_WD 34
    `define STALL_BUS_WD    10
    `define FORWARD_BUS_WD  33
    `define FS_TO_DS_BUS_WD 81
    `define DS_TO_ES_BUS_WD 195
    `define ES_TO_MS_BUS_WD 140
    `define MS_TO_WS_BUS_WD 162
    `define WS_TO_RF_BUS_WD 42

    `define BADVADDR_NUM 5'd8
    `define COUNT_NUM    5'd9
    `define COMPARE_NUM  5'd11
    `define STATUS_NUM   5'd12
    `define CAUSE_NUM    5'd13
    `define EPC_NUM      5'd14

    `define INDEX_NUM    5'd0
    `define ENTRYLO0_NUM 5'd2
    `define ENTRYLO1_NUM 5'd3
    `define ENTRYHI_NUM  5'd10

    `define TLB_ENTRY_WD 78
`endif
