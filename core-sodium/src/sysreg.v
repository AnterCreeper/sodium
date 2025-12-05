`include "defines.v"

module sysreg_core(
    input   clk,
    input   rst,
    input   init,

//Reg Update Path from Core
    input       swi,
    input       exi,
    input       mie_set,
    input[7:0]  perf,
    input[31:0] pc_epc,

//Reg Output Path
    //Core
    output[31:0] mvec,
    output[31:0] mepc,
    output[31:0] mask,
    output       mie,
    output       m32,

    //Memory Controller
    output[15:0] cr0,
    output[15:0] cr1,
    output[15:0] cr2,
    output[15:0] cr3,

`ifdef DEBUG
    output reg sim_stop,
`endif

//Bus Mgmt Path
    input 			 mgmt_req,
	input[31:0] 	 mgmt_adr,
	output reg		 mgmt_ack,
	input          	 mgmt_rwn,
	input[1:0]     	 mgmt_wen,
	input[31:0] 	 mgmt_txd,
	output reg		 mgmt_rxe,
	output[31:0]     mgmt_rxd
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

reg[15:0]   cfg_cmd;
reg[31:0]   cfg_din;
wire[31:0]  cfg_dout;

always @(posedge clk)
begin
    rwn     <= mgmt_rwn;
    wen     <= mgmt_wen;
    cfg_cmd <= mgmt_adr;
    cfg_din <= mgmt_txd;
end

wire valid = issue && ((cfg_cmd & `MASK_REG) == `ADDR_REG);

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
    if(rst) mgmt_rxe <= 0;
    else    mgmt_rxe <= valid && rwn;
end

assign mgmt_rxd = mgmt_rxe ? cfg_dout : 0;

wire[31:0] update;
wire[31:0] old_data[31:0];
wire[31:0] new_data[31:0];

//Description Table
assign update[`ADDR_MSTK] = 1;
assign update[`ADDR_MICM] = 1;
assign update[`ADDR_MDCM] = 1;
assign update[`ADDR_MCPS] = 1;
assign update[`ADDR_MBRU] = 1;
assign update[`ADDR_MALU] = 1;
assign update[`ADDR_MLSU] = 1;
assign update[`ADDR_MSRU] = 1;

assign new_data[`ADDR_MSTK] = init ? 0 : old_data[`ADDR_MSTK] + perf[0]; //Systick
assign new_data[`ADDR_MICM] = init ? 0 : old_data[`ADDR_MICM] + perf[1]; //I$ miss
assign new_data[`ADDR_MDCM] = init ? 0 : old_data[`ADDR_MDCM] + perf[2]; //D$ miss
assign new_data[`ADDR_MCPS] = init ? 0 : old_data[`ADDR_MCPS] + perf[3]; //IPC stall
assign new_data[`ADDR_MBRU] = init ? 0 : old_data[`ADDR_MBRU] + perf[4]; //Branch issue
assign new_data[`ADDR_MALU] = init ? 0 : old_data[`ADDR_MALU] + perf[5]; //ALU issue
assign new_data[`ADDR_MLSU] = init ? 0 : old_data[`ADDR_MLSU] + perf[6]; //Mem issue
assign new_data[`ADDR_MSRU] = init ? 0 : old_data[`ADDR_MSRU] + perf[7]; //SysReg issue

assign update[`ADDR_MVEC] = 0;
assign update[`ADDR_MASK] = 0;
assign update[`ADDR_MEPC] = swi || (mie ? exi : 0);
assign update[`ADDR_MSTA] = init || mie_set;

assign new_data[`ADDR_MEPC] = pc_epc;
assign new_data[`ADDR_MSTA] = init ? 0 : old_data[`ADDR_MSTA] | 2'b10;

assign update[`ADDR_MCR0] = 0;
assign update[`ADDR_MCR1] = 0;
assign update[`ADDR_MCR2] = 0;
assign update[`ADDR_MCR3] = 0;

assign mvec = old_data[`ADDR_MVEC];
assign mask = old_data[`ADDR_MASK];
assign mepc = old_data[`ADDR_MEPC];
assign mie  = old_data[`ADDR_MSTA][0];
assign m32  = old_data[`ADDR_MSTA][1];
assign cr0  = old_data[`ADDR_MCR0];
assign cr1  = old_data[`ADDR_MCR1];
assign cr2  = old_data[`ADDR_MCR2];
assign cr3  = old_data[`ADDR_MCR3];

//Regmap DFF Files
wire[1023:0] _new_data;
wire[1023:0] _old_data;
`PACK_ARRAY(32, 32, _new_data, new_data)
`UNPK_ARRAY(32, 32, old_data, _old_data)
dffs_dp_mask #(5, 32, 1) //32x32 DFFs with mask
sysreg_mem(
    .CLK(clk),
    .CENA(~valid),
    .WENA(~wen),
    .AA(cfg_cmd[4:0]),
    .DA(cfg_din),
    .QA(cfg_dout),
    .WENB(~update),
    .DB(_new_data),
    .MASK(`REG_MASK),
    .DFF(_old_data)
);

`ifdef DEBUG
initial sim_stop = 0;
always @(posedge clk)
begin
    if(valid && wen[0] && (cfg_cmd == `ADDR_MDB1))
        $write("%c", cfg_din[7:0]);
end
always @(posedge clk)
begin
    if(valid && wen[0] && (cfg_cmd == `ADDR_MDB0))
    begin
    case(cfg_din[15:0])
    `DEBUG_CMD_HALT:  sim_stop <= 1;
    endcase
    end
end

wire[31:0] tick_systick = old_data[`ADDR_MSTK];
wire[31:0] tick_istall  = old_data[`ADDR_MICM];
wire[31:0] tick_dstall  = old_data[`ADDR_MDCM];
wire[31:0] tick_hazard  = old_data[`ADDR_MCPS];
wire[31:0] tick_calc    = old_data[`ADDR_MALU];
wire[31:0] tick_ldst    = old_data[`ADDR_MLSU];
wire[31:0] tick_branch  = old_data[`ADDR_MBRU];
wire[31:0] tick_sysreg  = old_data[`ADDR_MSRU];

`endif

endmodule
