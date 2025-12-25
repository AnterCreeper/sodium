`define FMT_J       4'b1001
`define FMT_B       4'b0001
`define FMT_R       4'b0111
`define FMT_I       4'b1111
`define FMT_LS      4'b0101
`define FMT_SR      4'b1101
`define FMT_LRA     4'b1011
`define FMT_HT      4'b0011

`define FMT_jmp     3'b001 //FMT_J + FMT_B
`define FMT_alu     3'b111 //FMT_R + FMT_I
`define FMT_bus     3'b101 //FMT_LS + FMT_SR

`define FUNC_B      3'b000
`define FUNC_BL     3'b001
`define FUNC_BR     3'b100
`define FUNC_BLR    3'b101
`define FUNC_RET    3'b010
`define FUNC_MRET   3'b110

`define FUNC_BCEZ   3'b001
`define FUNC_BCNZ   3'b101
`define FUNC_BCGE   3'b011
`define FUNC_BCLT   3'b110
`define FUNC_BCGT   3'b010
`define FUNC_BCLE   3'b111

`define FUNC_AU     3'b000
`define FUNC_SU     3'b010
`define FUNC_LU     3'b001
`define FUNC_BM     3'b101
`define FUNC_MU     3'b011

`define TAG_ADD     3'b000 //I
`define TAG_ADD32   3'b010 //I
`define TAG_SUB     3'b011
`define TAG_SUB32   3'b001
`define TAG_SLT     3'b100 //I
`define TAG_SLTU    3'b110 //I
`define TAG_MOVZ    3'b101
`define TAG_MOVN    3'b111

`define TAG_OR      3'b000 //I
`define TAG_AND     3'b100 //I
`define TAG_XOR     3'b010 //I
`define TAG_ORN     3'b001
`define TAG_ANDN    3'b101
`define TAG_XNOR    3'b011

`define TAG_SLL     2'b00  //I
`define TAG_SRL     2'b01  //I
`define TAG_SRA     2'b10  //I
`define TAG_SRR     2'b11  //I

`define TAG_CMP     3'b011
`define TAG_BFI     3'b000 //I only
`define TAG_BFX     3'b010 //I only
`define TAG_TBE     3'b110 //I
`define TAG_REV     3'b001
`define TAG_CLZ     3'b101
`define TAG_PACK    3'b111 //I

`define FLAG_MIN    2'b00
`define FLAG_MAX    2'b10
`define FLAG_MINU   2'b01
`define FLAG_MAXU   2'b11

`define FUNC_L      3'b001
`define FUNC_LR     3'b011
`define FUNC_S      3'b000
`define FUNC_SC     3'b010
`define FUNC_ZERO   3'b100
`define FUNC_FLUSH  3'b101
`define FUNC_INVD   3'b110
`define FUNC_CLEAN  3'b111

`define TAG_LSW     2'b01
`define TAG_LSH     2'b00
`define TAG_LSB     2'b10
`define TAG_LBU     2'b11

`define FUNC_NM     3'b000
`define FUNC_DW     3'b100
`define FUNC_DR     3'b010

`define TAG_W     2'b11
`define TAG_H     2'b10
`define TAG_L     2'b01

`define FUNC_LRA_ZERO   3'b000
`define FUNC_LRA_PC     3'b100
`define FUNC_LRA_PC12   3'b101
`define FUNC_LRA_PC20   3'b110

`define FUNC_USR    3'b000

`define TAG_NOP     5'b00000
`define TAG_WFI     5'b00001
`define TAG_WFE     5'b00010
`define TAG_WFM     5'b00011
`define TAG_FENCE   5'b00100

`define FUNC_ECALL  3'b001

`define EVB_MASK_W      2'b11
`define EVB_MASK_H      2'b10
`define EVB_MASK_L      2'b01
`define EVB_MASK_DUMMY  2'b00

`define REG_RA      5'b00010
