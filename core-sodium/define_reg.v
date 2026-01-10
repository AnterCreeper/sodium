//CSR Address Space
`define MASK_REG        16'hffe0    //32
`define ADDR_REG        16'h0000    //0x0000 - 0x001f

`define MASK_IRQ        16'hffe0    //32
`define ADDR_IRQ        16'h0020    //0x0020 - 0x003f

`define MASK_MC         16'hfff0    //16
`define ADDR_MC         16'h0040    //0x0040 - 0x004f

`define MASK_DBG        16'hfffe    //2
`define ADDR_DBG        16'h0050    //0x0050

`define ADDR_MDB0       16'h0050
`define ADDR_MDB1       16'h0051

`define MASK_MDC        16'hff00    //256
`define ADDR_MDC        16'h0100    //0x0100 - 0x01ff

//System CSR Regmap
//1: rw, 0: ro
`define REG_MASK        32'h0007000f

`define ADDR_MSTK       16'h0013
`define ADDR_MCR2       16'h0012
`define ADDR_MCR1       16'h0011
`define ADDR_MCR0       16'h0010

`define ADDR_MASK       16'h0003
`define ADDR_MSTA       16'h0002
`define ADDR_MEPC       16'h0001
`define ADDR_MVEC       16'h0000
