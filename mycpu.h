`ifndef MYCPU_H
    `define MYCPU_H

    `define BR_BUS_WD       34
    `define EXC_ERET_BUS_WD 34
    `define STALL_BUS_WD    10
    `define FORWARD_BUS_WD  33
    `define FS_TO_DS_BUS_WD 74
    `define DS_TO_ES_BUS_WD 188
    `define ES_TO_MS_BUS_WD 140
    `define MS_TO_WS_BUS_WD 126
    `define WS_TO_RF_BUS_WD 42

    `define BADVADDR_NUM 8
    `define COUNT_NUM    9
    `define COMPARE_NUM  11
    `define STATUS_NUM   12
    `define CAUSE_NUM    13
    `define EPC_NUM      14
`endif
