`include "defines.v"

module mp_reg(
    input   clk,
    input   rst,

//Reg Update Path from Core
    input   swi,
    input   exi,
    input   stall,
    input   mie_set,
    input[7:0]  perf,
    input[31:0] pc_epc,

//Reg Output Path
    //Core
    output reg[31:0] mvec,
    output reg[31:0] mepc,
    output reg       mie,
    output reg       m32,
    output reg[31:0] mask,
    //Memory Controller
    output reg[15:0] cr0,
    output reg[15:0] cr1,
    output reg[15:0] cr2,
    output reg[15:0] cr3,
    //Cache
    output reg[15:0] cr4,

//Bus Mgmt Path
    input 			 mgmt_req,
	input[31:0] 	 mgmt_adr,
	output reg		 mgmt_ack,
	input          	 mgmt_rwn,
	input[1:0]     	 mgmt_wen,
	input[31:0] 	 mgmt_txd,
	output reg		 mgmt_rxe,
	output reg[31:0] mgmt_rxd
);

reg mgmt_fin;
reg busy, issue;

always @(posedge clk or posedge rst)
begin
    if(rst)
    begin
        busy    <= 0;
        issue   <= 0;
    end else
    begin
        busy    <= !mgmt_fin && mgmt_req;
        issue   <= !busy     && mgmt_req;
    end
end

reg         rwn;
reg[1:0]    wen;

reg[15:0]   cr_cmd;
reg[31:0]   cr_din;
reg[31:0]   cr_dou;

always @(posedge clk)
begin
    rwn     <= mgmt_rwn;
    wen     <= mgmt_wen;
    cr_cmd  <= mgmt_adr;
    cr_din  <= mgmt_txd;
end

wire valid = issue && ((cr_cmd & `MASK_REG) == `ADDR_REG);
wire update = valid && wen[0];

always @(posedge clk or posedge rst)
begin
    if(rst)
    begin
        mgmt_fin <= 0;
        mgmt_ack <= 0;
    end else
    begin
        mgmt_fin <= issue;
        mgmt_ack <= valid;
    end
end

always @(posedge clk or posedge rst)
begin
    if(rst)
    begin
        mgmt_rxe <= 0;
    end else
    begin
        mgmt_rxe <= valid && rwn;
        mgmt_rxd <= valid ? cr_dou : 0;
    end
end

reg[31:0] tick_sys;
reg[31:0] tick_icm;
reg[31:0] tick_dcm;
reg[31:0] tick_haz;
reg[31:0] tick_bru;
reg[31:0] tick_alu;
reg[31:0] tick_mem;
reg[31:0] tick_sru;

always @(posedge clk or posedge rst)
begin
    if(rst)
    begin
        tick_sys <= 0;
        tick_icm <= 0;
        tick_dcm <= 0;
        tick_haz <= 0;
        tick_bru <= 0;
        tick_alu <= 0;
        tick_mem <= 0;
        tick_sru <= 0;
    end else
    begin
        tick_sys <= tick_sys + perf[0];
        tick_icm <= tick_icm + perf[1];
        tick_dcm <= tick_dcm + perf[2];
        tick_haz <= tick_haz + perf[3];
        tick_bru <= tick_bru + perf[4];
        tick_alu <= tick_alu + perf[5];
        tick_mem <= tick_mem + perf[6];
        tick_sru <= tick_sru + perf[7];
    end
end

//Read Datapath
always @(*)
begin
    case(cr_cmd)
    `ADDR_MVEC:  cr_dou <= mvec;
    `ADDR_MEPC:  cr_dou <= mepc;
    `ADDR_MSTA:  cr_dou <= {14'h0, m32, mie};
    `ADDR_MASK:  cr_dou <= mask;
    `ADDR_MCR0:  cr_dou <= cr0;
    `ADDR_MCR1:  cr_dou <= cr1;
    `ADDR_MCR2:  cr_dou <= cr2;
    `ADDR_MCR3:  cr_dou <= cr3;
    `ADDR_MSTK:  cr_dou <= tick_sys;
    `ADDR_MICM:  cr_dou <= tick_icm;
    `ADDR_MDCM:  cr_dou <= tick_dcm;
    `ADDR_MCPS:  cr_dou <= tick_haz;
    `ADDR_MBRU:  cr_dou <= tick_bru;
    `ADDR_MALU:  cr_dou <= tick_alu;
    `ADDR_MLSU:  cr_dou <= tick_mem;
    `ADDR_MSRU:  cr_dou <= tick_sru;
    default:     cr_dou <= 0;
    endcase
end

wire int = swi || (mie ? exi : 0);

//Core Register
always @(posedge clk)
begin
    mvec[31:16] <= valid && wen[1] && (cr_cmd == `ADDR_MVEC) ? cr_din[31:16] : mvec[31:16];
    mvec[15:0]  <= valid && wen[0] && (cr_cmd == `ADDR_MVEC) ? cr_din[15:0]  : mvec[15:0];
    mepc[31:16] <= valid && wen[1] && (cr_cmd == `ADDR_MEPC) ? cr_din[31:16] : (int ? pc_epc[31:16] : mepc[31:16]);
    mepc[15:0]  <= valid && wen[0] && (cr_cmd == `ADDR_MEPC) ? cr_din[15:0]  : (int ? pc_epc[15:0]  : mepc[15:0]);
    mask[31:16] <= valid && wen[1] && (cr_cmd == `ADDR_MASK) ? cr_din[31:16] : mask[31:16];
    mask[15:0]  <= valid && wen[0] && (cr_cmd == `ADDR_MASK) ? cr_din[15:0]  : mask[15:0];
end

`ifdef DEBUG
always @(posedge clk)
begin
    if(update && (cr_cmd == `ADDR_MCR3))
        $write("%c", cr_din[7:0]);
end
`endif

//Core Status Register
always @(posedge clk or posedge rst)
begin
    if(rst)
    begin
        mie  <= 0;
        m32  <= 0;
    end else
    begin
        mie  <= (!int || stall) && (update && (cr_cmd == `ADDR_MSTA) ? cr_din[0] : mie_set || mie);
        m32  <= update && (cr_cmd == `ADDR_MSTA) ? cr_din[1] : m32;
    end
end

//MC PHY Register
always @(posedge clk)
begin
    cr0 <= update && (cr_cmd == `ADDR_MCR0) ? cr_din : cr0;
    cr1 <= update && (cr_cmd == `ADDR_MCR1) ? cr_din : cr1;
    cr2 <= update && (cr_cmd == `ADDR_MCR2) ? cr_din : cr2;
    cr3 <= update && (cr_cmd == `ADDR_MCR3) ? cr_din : cr3;
end

endmodule
