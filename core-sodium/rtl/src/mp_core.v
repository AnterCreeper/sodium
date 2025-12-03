`include "defines.v"

module mp_sync_rst(
    input clk,
    input ext_rst, //async reset
    input aux_rst, //sync reset
    output reg sysinit,
    output reg syssetn
);

reg sync_rst;
always @(negedge clk or posedge ext_rst)
begin
    if(ext_rst)
        sync_rst <= 1'b1;
    else
        sync_rst <= aux_rst;
end
always @(negedge clk or posedge ext_rst)
begin
    if(ext_rst)
        syssetn <= 1'b1;
    else
        syssetn <= sync_rst;
end
always @(posedge clk or posedge syssetn)
begin
    if(syssetn)
        sysinit <= 1;
    else
        sysinit <= 0;
end
endmodule

module mp_regfile(
    input sys_clk,

    input[4:0]   rs1,
    input[4:0]   rs2,
    output[15:0] rs1_data16,
    output[15:0] rs2_data16,
    output[31:0] rs1_data32,
    output[31:0] rs2_data32,

    input        wb,
    input        wb32,
    input[4:0]   wb_rd,
    input[31:0]  wb_rd_data32
);

wire[1:0]  wb_mask = wb32 ? 2'b11 : {wb_rd[0], !wb_rd[0]};
wire[31:0] wb_data = wb32 ? wb_rd_data32 : {wb_rd_data32[15:0], wb_rd_data32[15:0]};

wire[31:0] rs1_mem, rs2_mem;
dffs_dp_async #(4, 32, 1)   //16x32 DFFs, async read
regfile_0 (
    .CLK(sys_clk),

    .CENA(~wb),
    .WENA(~wb_mask),
    .AA(wb_rd[4:1]),
    .DA(wb_data),

    .AB(rs1[4:1]),
    .QB(rs1_mem)
);

dffs_dp_async #(4, 32, 1)   //16x32 DFFs, async read
regfile_1 (
    .CLK(sys_clk),

    .CENA(~wb),
    .WENA(~wb_mask),
    .AA(wb_rd[4:1]),
    .DA(wb_data),

    .AB(rs2[4:1]),
    .QB(rs2_mem)
);

assign rs1_data32 = rs1[4:1] == 0 ? 0 : rs1_mem;
assign rs2_data32 = rs2[4:1] == 0 ? 0 : rs2_mem;
assign rs1_data16 = rs1[4:0] == 0 ? 0 : (rs1[0] ? rs1_mem[31:16] : rs1_mem[15:0]);
assign rs2_data16 = rs2[4:0] == 0 ? 0 : (rs2[0] ? rs2_mem[31:16] : rs2_mem[15:0]);

endmodule

module mp_core(
    input sys_clk,
    input ext_rst,
    input aux_rst,
    output sys_init,

    //Interrupt
    input           mie,
    input           exi,
    input[4:0]      exi_code,
    output          swi,
    output          mie_set,
    output[31:0]    pc_epc,

    //Config Register
    input           m32,
    input[31:0]     mvec, //interrupt vector
    input[31:0]     mepc, //exception pc

    //Performace Line
    output[7:0]     perf,

    //Invalid Path
    input           invd_req,
    output          invd_ack,
    input[15:0]     invd_adr,

    //L2 Cache
    output          mem_request,
    input           mem_finish,
    input           mem_partial,
    output          mem_rwn,
    output[15:0]    mem_addr,
    output[15:0]    mem_commit,
    output[127:0]   mem_write_data,
    input           mem_replace,
    input[4:0]      mem_replace_set,
    input[6:0]      mem_replace_tag,
    input[127:0]    mem_replace_dat,

    //Management Command
    output 			mgmt_req,
	input 			mgmt_ack,
	output          mgmt_rwn,
	output[31:0] 	mgmt_adr,
    //Management Data
	output[1:0]     mgmt_wen,
	output[31:0] 	mgmt_txd,
	input 			mgmt_rxe,
	input[31:0] 	mgmt_rxd
);

//Reset Module
wire sys_setn;
mp_sync_rst rst(
    .clk(sys_clk),
    .ext_rst(ext_rst),
    .aux_rst(aux_rst),
    .sysinit(sys_init),
    .syssetn(sys_setn)
);

//Sys Regs
wire[31:0] instru;
wire[31:0] pc;

wire icache_vld;
wire icache_ack;

//Sys Statue
wire stall_lsu; //load store unit stall
wire stall_sru; //special register unit stall
wire stall_wfi; //wait for interrupt stall
wire stall_haz; //hazard stall
wire stall = !icache_vld || stall_lsu || stall_sru || stall_wfi || stall_haz || sys_init;

//I cache
wire[31:0] fetch_addr;
wire[29:0] icache_addr;
wire[31:0] icache_data;

assign icache_ack = sys_init || !stall;
assign icache_addr = {m32 ? 0 : fetch_addr[31:16], fetch_addr[15:2]};

mp_icache   icache(
    .sys_clk    (sys_clk),
    .sys_setn   (sys_setn),

    .icache_ack (icache_ack),
    .icache_addr(icache_addr),
    .icache_vld (icache_vld),
    .icache_data(icache_data)
);

assign instru = sys_init || !icache_vld ? 32'h0 : icache_data;

//Decoder
wire[4:0] rd, rs1, rs2;
assign rd  = instru[8:4];
assign rs1 = instru[16:12];
assign rs2 = instru[21:17];

wire[3:0] opcode4 = instru[3:0];

wire a, b, c, d;
assign a = opcode4[2];
assign b = opcode4[1];
assign c = opcode4[0];
assign d = opcode4[3];

wire[1:0] tag2      = instru[31:30];
wire[2:0] tag3      = {instru[31:30], opcode4 == `FMT_I ? 1'b0 : instru[29]};
wire[4:0] tag5      = instru[8:4];
wire[2:0] func3     = instru[11:9];
wire[4:0] pos5      = instru[21:17];
wire[6:0] flag7     = instru[28:22];

wire[15:0] imm16;
assign imm16 = {a ? {3{instru[28]}} : instru[31:29],    //3
                instru[28:22],                          //7
                b ? instru[21:17] : instru[8:4],        //5
                a ? instru[29] : 1'b0};                 //1

wire signext;
assign signext = a ? instru[28] : (
                 opcode4 == `FMT_HT ? instru[31] : (
                 opcode4 == `FMT_J && (func3 == `FUNC_B && func3 == `FUNC_BL) ? instru[21] :
                 instru[16]));

wire[15:0] imm16e;
assign imm16e = {{6{signext}}, //6
                 opcode4 == `FMT_J && (func3 == `FUNC_B && func3 == `FUNC_BL) ? rs2 : {5{signext}}, //5
                 !a && (d || !b) ? rs1 : {5{signext}}}; //5

wire[31:0] imm32;
assign imm32 = {imm16e, imm16}; //00010 00000

//Register File
wire[31:0] rs1_data32, rs2_data32;
wire[15:0] rs1_data16, rs2_data16;

reg wb, wb32;
reg [4:0] wb_rd;
reg[31:0] wb_rd_data32;

mp_regfile regfile(
    .sys_clk(sys_clk),
    .rs1(rs1),
    .rs2(rs2),
    .rs1_data32(rs1_data32),
    .rs2_data32(rs2_data32),
    .rs1_data16(rs1_data16),
    .rs2_data16(rs2_data16),
    .wb     (wb),
    .wb32   (wb32),
    .wb_rd  (wb_rd),
    .wb_rd_data32(wb_rd_data32)
);

//Decoder
wire issue_jmp = opcode4 == `FMT_J || opcode4 == `FMT_B;
wire issue_alu = !stall && (opcode4 == `FMT_I || opcode4 == `FMT_R);
wire issue_wfi = !stall && opcode4 == `FMT_HT && func3 == `FUNC_USR && tag5 == `TAG_WFI;
wire issue_swi = !stall && opcode4 == `FMT_HT && func3 == `FUNC_ECALL;
wire issue_mem = !stall && opcode4 == `FMT_LS;
wire issue_sru = !stall && opcode4 == `FMT_SR;
wire issue_byp = !stall && opcode4 == `FMT_LRA;

assign perf[0] = !sys_init && !stall_wfi;  //Systick
assign perf[1] = !icache_vld;              //I$ miss
assign perf[2] = stall_lsu;                //D$ miss
assign perf[3] = stall_haz || stall_sru;   //IPC stall
assign perf[4] = issue_jmp && !stall;      //Branch issue
assign perf[5] = issue_alu && !stall;      //ALU issue
assign perf[6] = issue_mem && !stall;      //Mem issue
assign perf[7] = issue_sru && !stall;      //SysReg issue

assign swi     = issue_swi;
assign mie_set = issue_wfi || (issue_jmp && d && func3 == `FUNC_MRET);

wire[3:0]  alu_shift    = func3 == `FUNC_AU ? 0 : flag7[2:0] + 1;
wire[15:0] alu_data_in1 = rs1_data16;
wire[15:0] alu_data_in2 = opcode4 == `FMT_I ? imm16 : rs2_data16;

wire       lsu_rwn   = func3[0];
wire       lsu_invd  = func3 == `FUNC_INVD;
wire       lsu_zero  = func3 == `FUNC_ZERO;
wire       lsu_clean = func3 == `FUNC_CLEAN;
wire       lsu_flush = func3 == `FUNC_FLUSH;

wire[31:0] lsu_data_in = rs1_data32;
wire[15:0] lsu_addr_in = rs2_data16 + imm16;

reg[7:0]   lsu_mask;
always @(*)
begin
    case(tag2)
    `TAG_LSW:   lsu_mask[3:0] = 4'b1111;
    `TAG_LSH:   lsu_mask[3:0] = lsu_addr_in[1] ? 4'b1100 : 4'b0011;
    `TAG_LSB, `TAG_LBU:
    case(lsu_addr_in[1:0])
    2'b00:      lsu_mask[3:0] = 4'b0001;
    2'b01:      lsu_mask[3:0] = 4'b0010;
    2'b10:      lsu_mask[3:0] = 4'b0100;
    2'b11:      lsu_mask[3:0] = 4'b1000;
    endcase
    endcase
    if(lsu_flush)
                lsu_mask[7:4] = 4'b0000;
    else
    case(lsu_addr_in[3:2])
    2'b00:      lsu_mask[7:4] = 4'b0001;
    2'b01:      lsu_mask[7:4] = 4'b0010;
    2'b10:      lsu_mask[7:4] = 4'b0100;
    2'b11:      lsu_mask[7:4] = 4'b1000;
    endcase
end
wire[31:0] lsu_seek = 1 << lsu_addr_in[8:4];

wire       byp_zero  = func3 == `FUNC_LRA_ZERO;
wire       byp_m32   = m32 && !byp_zero;
wire[4:0]  byp_shift = func3 == `FUNC_LRA_ZERO ? 0  : (
                       func3 == `FUNC_LRA_PC ?   1  : (
                       func3 == `FUNC_LRA_PC12 ? 13 : (
                       func3 == `FUNC_LRA_PC20 ? 21 :
                       5'bx)));
wire[31:0] byp_data  = (byp_zero ? 0 : pc) + ({imm32[31], imm32[31:1]} << byp_shift);

//Writeback and Forward Regs
wire[4:0] bru_wb_rd;
wire bru_wb, alu_wb, byp_wb, lsu_wb, evb_wb;
wire alu_wb32, lsu_wb32, evb_wb32, byp_wb32;

wire[31:0] bru_wb_data;
wire[31:0] alu_wb_data;
wire[31:0] byp_wb_data;
wire[31:0] lsu_wb_data;
wire[31:0] evb_wb_data;

reg        alu_fwd_en1;
reg        alu_fwd_en2;
reg[1:0]   mem_fwd_en1;
reg[15:0]  alu_fwd_data1;
reg[15:0]  alu_fwd_data2;
reg[31:0]  mem_fwd_data1;

//Execution
mp_branch   bpu(
    .sys_clk    (sys_clk),
    .sys_setn   (sys_setn),

    .stall      (stall),
    .stall_wfi  (stall_wfi),

    .issue_swi  (issue_swi),
    .issue_jmp  (issue_jmp),
    .issue_wfi  (issue_wfi),

    .type       (d),
    .tag3       (tag3),
    .tag5       (tag5),
    .func3      (func3),
    .imm32      (imm32),

    .m32        (m32),
    .rb_data16  (rs2_data16),
    .rb_data32  (rs2_data32),

    .pc         (pc),
    .pc_epc     (pc_epc),
    .fetch_addr (fetch_addr),

    .mie        (mie),
    .exi        (exi),
    .exi_code   (exi_code),

    .mvec       (mvec),
    .mepc       (mepc),

    .wb         (bru_wb),
    .wb_rd      (bru_wb_rd),
    .wb_data    (bru_wb_data)
);

mp_bypass   bypass(
    .sys_clk     (sys_clk),
    .sys_setn   (sys_setn),

    .issue      (issue_byp),

    .m32        (byp_m32),
    .data       (byp_data),

    .wb         (byp_wb),
    .wb32       (byp_wb32),
    .wb_data    (byp_wb_data)
);

mp_alu      alu(
    .sys_clk     (sys_clk),
    .sys_setn   (sys_setn),

    .issue      (issue_alu),
    .func3      (func3),
    .tag3       (tag3),
    .flag7      (flag7),

    .shift      (alu_shift),
    .data_in1   (alu_data_in1),
    .data_in2   (alu_data_in2),

    .fwd_en1    (alu_fwd_en1),
    .fwd_en2    (alu_fwd_en2),
    .fwd_data1  (alu_fwd_data1),
    .fwd_data2  (alu_fwd_data2),

    .wb         (alu_wb),
    .wb32       (alu_wb32),
    .wb_data    (alu_wb_data)
);

mp_dcache   lsu(
    .sys_clk    (sys_clk),
    .sys_rst    (sys_setn),

    .stall      (stall_lsu),
    .issue      (issue_mem),

    .sel        (rs1[0]),
    .tag2       (tag2),
    .lsu_rwn    (lsu_rwn),
    .lsu_seek   (lsu_seek),
    .lsu_mask   (lsu_mask),

    .lsu_zero   (lsu_zero),
    .lsu_invd   (lsu_invd),
    .lsu_flush  (lsu_flush),
    .lsu_clean  (lsu_clean),

    .lsu_data_in(lsu_data_in),
    .lsu_addr_in(lsu_addr_in),

    .fwd_en     (mem_fwd_en1),
    .fwd_data   (mem_fwd_data1),

    .wb         (lsu_wb),
    .wb32       (lsu_wb32),
    .wb_data    (lsu_wb_data),

    .invd_req   (invd_req),
    .invd_ack   (invd_ack),
    .invd_adr   (invd_adr),

    .mem_request    (mem_request),
    .mem_finish     (mem_finish),
    .mem_partial    (mem_partial),
    .mem_rwn        (mem_rwn),
    .mem_addr       (mem_addr),
    .mem_commit     (mem_commit),
    .mem_write_data (mem_write_data),
    .mem_replace    (mem_replace),
    .mem_replace_set(mem_replace_set),
    .mem_replace_tag(mem_replace_tag),
    .mem_replace_dat(mem_replace_dat)
);

mp_sysbus   sysbus(
    .sys_clk     (sys_clk),
    .sys_setn   (sys_setn),

    .stall      (stall_sru),
    .issue      (issue_sru),

    .sel        (rs1[0]),
    .tag2       (tag2),
    .pos5       (pos5),
    .func3      (func3),

    .evb_data_in(rs1_data32),
    .evb_addr_in(imm16[12:0]),

    .fwd_en     (mem_fwd_en1),
    .fwd_data   (mem_fwd_data1),

    .wb         (evb_wb),
    .wb32       (evb_wb32),
    .wb_data    (evb_wb_data),

    //External Port
    .mgmt_req   (mgmt_req),
    .mgmt_adr   (mgmt_adr),
    .mgmt_ack   (mgmt_ack),
    .mgmt_rwn   (mgmt_rwn),
    .mgmt_wen   (mgmt_wen),
    .mgmt_txd   (mgmt_txd),
    .mgmt_rxe   (mgmt_rxe),
    .mgmt_rxd   (mgmt_rxd)
);

//Writeback
reg[4:0] ex_rd;
always @(posedge sys_clk)
begin
    if(!stall) ex_rd <= opcode4 == `FMT_LS || opcode4 == `FMT_SR ? rs1 : rd;
end
always @(*)
begin
    wb      <= bru_wb || alu_wb || lsu_wb || evb_wb || byp_wb;
    wb32    <= alu_wb32 || lsu_wb32 || evb_wb32 || byp_wb32;
    wb_rd   <= bru_wb ? bru_wb_rd : ex_rd;
    case({bru_wb, alu_wb, lsu_wb, evb_wb, byp_wb})
    5'b10000: wb_rd_data32 <= bru_wb_data;
    5'b01000: wb_rd_data32 <= alu_wb_data;
    5'b00100: wb_rd_data32 <= lsu_wb_data;
    5'b00010: wb_rd_data32 <= evb_wb_data;
    5'b00001: wb_rd_data32 <= byp_wb_data;
    default:  wb_rd_data32 <= 32'bx;
    endcase
end

//Data Forwarding Logic
wire pre_fwd1 = rs1[4:1] == 0 ? 1'b0 : (wb_rd[4:1] == rs1[4:1] ? wb : 0);
wire pre_fwd2 = rs2[4:1] == 0 ? 1'b0 : (wb_rd[4:1] == rs2[4:1] ? wb : 0);

assign stall_haz = (opcode4 == `FMT_LS || issue_jmp) && pre_fwd2 ? wb32 || (wb_rd[0] == rs2[0]) : 0;

always @(posedge sys_clk or posedge sys_setn)
begin
    if(sys_setn)
    begin
        alu_fwd_en1 <= 0;
        alu_fwd_en2 <= 0;
        mem_fwd_en1 <= 0;
    end else
    if(!stall)
    begin
        alu_fwd_en1 <= pre_fwd1 ?                      wb32 || (wb_rd[0] == rs1[0]) : 0;
        alu_fwd_en2 <= pre_fwd2 && opcode4 != `FMT_I ? wb32 || (wb_rd[0] == rs2[0]) : 0;
        alu_fwd_data1 <= rs1[0] && wb32 ? wb_rd_data32[31:16] : wb_rd_data32[15:0];
        alu_fwd_data2 <= rs2[0] && wb32 ? wb_rd_data32[31:16] : wb_rd_data32[15:0];
        mem_fwd_en1 <= pre_fwd1 ? (wb32 ? 2'b11 : {wb_rd[0], !wb_rd[0]}) : 0;
        mem_fwd_data1 <= wb32 ? wb_rd_data32 : {wb_rd_data32[15:0], wb_rd_data32[15:0]};
    end
end

endmodule
