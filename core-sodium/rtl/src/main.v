`include "defines.v"

module system(
	input       clk,
	input       rst,
	input[31:0] irq,
	output 		ram_cs,
	output 		ram_clk,
	inout[7:0] 	ram_adq,
	inout 		ram_rwds
);

wire aux_rst;
assign aux_rst = 0;

wire sys_init;

wire 		mgmt_req;
wire[31:0] 	mgmt_adr;
wire 		mgmt_ack;
wire        mgmt_rwn;
wire[1:0]   mgmt_wen;
wire[31:0] 	mgmt_txd;
wire 		mgmt_rxe;
wire[31:0] 	mgmt_rxd;

wire        mem_request;
wire        mem_finish;
wire        mem_partial;
wire        mem_rwn;
wire[15:0]  mem_addr;
wire[15:0]  mem_commit;
wire[127:0] mem_write_data;
wire        mem_replace;
wire[4:0]   mem_replace_set;
wire[6:0]   mem_replace_tag;
wire[127:0] mem_replace_dat;

wire        invd_req;
wire        invd_ack;
wire[15:0]  invd_addr;

wire 		host_req;
wire        host_rwn;
wire 		host_burst;
wire[31:0] 	host_addr;
wire 		host_ack;
wire[1:0] 	host_txm;
wire[15:0] 	host_txd;
wire 		host_txd_ack;
wire[15:0] 	host_rxd;
wire 		host_rxd_vld;

wire        m32;
wire[15:0]  cr0, cr1, cr2, cr3;
wire[31:0]  mvec, mepc;
wire[31:0]  mask;

wire[7:0]   perf;

//for SRAM

wire        mie;
wire        mie_set;
wire        swi;
wire[31:0]  pc_epc;

wire        exi;
wire[4:0]   exi_code;

//PIC
wire        pic_mgmt_ack;
wire        pic_mgmt_rxe;
wire[31:0]  pic_mgmt_rxd;
pic_core pic(
	.clk(clk),
	.rst(rst),

    .irq(irq & ~mask),

    .exi(exi),
    .exi_code(exi_code),

    .mgmt_req(mgmt_req),
    .mgmt_adr(mgmt_adr),
    .mgmt_ack(pic_mgmt_ack),
    .mgmt_rwn(mgmt_rwn),
    .mgmt_wen(mgmt_wen),
    .mgmt_txd(mgmt_txd),
    .mgmt_rxe(pic_mgmt_rxe),
    .mgmt_rxd(pic_mgmt_rxd)
);

//Core
mp_core core(
    .sys_clk    (clk),
    .ext_rst    (rst),
    .aux_rst    (aux_rst),
    .sys_init   (sys_init),

    .mie        (mie),
    .exi        (exi),
    .exi_code   (exi_code),
    .swi        (swi),
    .mie_set    (mie_set),
    .pc_epc     (pc_epc),

    .m32        (m32),
    .mvec       (mvec),
    .mepc       (mepc),
    .perf       (perf),

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
    .mem_replace_dat(mem_replace_dat),

    .invd_req   (invd_req),
    .invd_adr   (invd_addr),
    .invd_ack   (invd_ack),

    .mgmt_req   (mgmt_req),
    .mgmt_adr   (mgmt_adr),
    .mgmt_ack   (mgmt_ack),
    .mgmt_rwn   (mgmt_rwn),
    .mgmt_wen   (mgmt_wen),
    .mgmt_txd   (mgmt_txd),
    .mgmt_rxe   (mgmt_rxe),
    .mgmt_rxd   (mgmt_rxd)
);

assign invd_req  = 0;
assign invd_addr = 16'hx;

`ifdef DEBUG
wire        sim_stop;
`endif
wire        reg_mgmt_ack;
wire        reg_mgmt_rxe;
wire[31:0]  reg_mgmt_rxd;
sysreg_core sysreg(
	.clk(clk),
	.rst(rst),
	.init(sys_init),

    .swi(swi),
    .exi(exi),
    .perf(perf),
    .pc_epc(pc_epc),
    .mie_set(mie_set),

    .cr0(cr0),
    .cr1(cr1),
    .cr2(cr2),
    .cr3(cr3),
    .mie(mie),
    .m32(m32),
    .mvec(mvec),
    .mepc(mepc),
    .mask(mask),
`ifdef DEBUG
    .sim_stop(sim_stop),
`endif

    .mgmt_req(mgmt_req),
    .mgmt_adr(mgmt_adr),
    .mgmt_ack(reg_mgmt_ack),
    .mgmt_rwn(mgmt_rwn),
    .mgmt_wen(mgmt_wen),
    .mgmt_txd(mgmt_txd),
    .mgmt_rxe(reg_mgmt_rxe),
    .mgmt_rxd(reg_mgmt_rxd)
);

wire        mc_mgmt_ack;
wire        mc_mgmt_rxe;
wire[31:0]  mc_mgmt_rxd;

ram_core memory(
	.clk(clk),
	.rst(rst),

    .host_req   (host_req),
    .host_rwn   (host_rwn),
    .host_burst (host_burst),
    .host_addr  (host_addr),
    .host_ack   (host_ack),
    .host_txm   (host_txm),
    .host_txd   (host_txd),
    .host_txd_ack(host_txd_ack),
    .host_rxd   (host_rxd),
    .host_rxd_vld(host_rxd_vld),

    .mgmt_req(mgmt_req),
    .mgmt_adr(mgmt_adr),
    .mgmt_ack(mc_mgmt_ack),
    .mgmt_rwn(mgmt_rwn),
    .mgmt_wen(mgmt_wen),
    .mgmt_txd(mgmt_txd),
    .mgmt_rxe(mc_mgmt_rxe),
    .mgmt_rxd(mc_mgmt_rxd),

    .cr0(cr0),
    .cr1(cr1),
    .cr2(cr2),

	.ram_cs    (ram_cs),
	.ram_clk   (ram_clk),
	.ram_adq   (ram_adq),
	.ram_rwds  (ram_rwds)
);

assign mgmt_ack = reg_mgmt_ack | mc_mgmt_ack | pic_mgmt_ack;
assign mgmt_rxe = reg_mgmt_rxe | mc_mgmt_rxe | pic_mgmt_rxe;
assign mgmt_rxd = reg_mgmt_rxd | mc_mgmt_rxd | pic_mgmt_rxd;

//Simulator of Memory System
`ifdef DEBUG
reg sim_finish;
initial
begin
    sim_finish <= 0;
    #`MAX_RUN_CYCLES;
    sim_finish <= `DEBUG_FINISH;
end

//sim_memory_generic sim_memory(
sim_memory_dynamic sim_memory(
    .sys_clk        (clk),
    .mem_dump       (sim_finish | sim_stop),
    .mem_request    (mem_request),
    .mem_rwn        (mem_rwn),
    .mem_finish     (mem_finish),
    .mem_partial    (mem_partial),
    .mem_addr       (mem_addr),
    .mem_commit     (mem_commit),
    .mem_write_data (mem_write_data),
    .mem_replace    (mem_replace),
    .mem_replace_set(mem_replace_set),
    .mem_replace_tag(mem_replace_tag),
    .mem_replace_dat(mem_replace_dat)
);
`endif

endmodule
