//Mgmt Address
`define MASK_REG        16'hffe0    //32
`define ADDR_REG        16'h0000    //0x0000 - 0x001f

`define MASK_MC         16'hfff0    //16
`define ADDR_MC         16'h0020    //0x0020 - 0x002f

`define MASK_IRQ        16'hfff0    //16
`define ADDR_IRQ        16'h0030    //0x0030 - 0x003f

`define ADDR_MVEC       16'h0000
`define ADDR_MEPC       16'h0001
`define ADDR_MSTA       16'h0002
`define ADDR_MASK       16'h0003

`define ADDR_MCR0       16'h0010
`define ADDR_MCR1       16'h0011
`define ADDR_MCR2       16'h0012
`define ADDR_MCR3       16'h0013
`define ADDR_MSTK       16'h0014
`define ADDR_MICM       16'h0015
`define ADDR_MDCM       16'h0016
`define ADDR_MCPS       16'h0017
`define ADDR_MBRU       16'h0018
`define ADDR_MALU       16'h0019
`define ADDR_MLSU       16'h001a
`define ADDR_MSRU       16'h001b
