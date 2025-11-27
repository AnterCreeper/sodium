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

wire 		mgmt_req;
wire[31:0] 	mgmt_adr;
wire 		mgmt_ack;
wire        mgmt_rwn;
wire[1:0]   mgmt_wen;
wire[31:0] 	mgmt_txd;
wire 		mgmt_rxe;
wire[31:0] 	mgmt_rxd;

wire        mem_request, mem_rwn;
reg         mem_finish;
wire[15:0]  mem_addr;
reg[127:0]  mem_read_data;
wire[127:0] mem_write_data;

wire        invd_req;
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
wire        mem_full;
wire        mem_through;
wire        mem_replace;
wire[4:0]   mem_replace_set;
wire[6:0]   mem_replace_tag;

wire        mie;
wire        mie_set;
wire        swi;
wire        stall;
wire[31:0]  pc_epc;

wire        exi;
wire[4:0]   exi_code;

//PIC
wire        pic_mgmt_ack;
wire        pic_mgmt_rxe;
wire[31:0]  pic_mgmt_rxd;
mp_irq apic(
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
    .sysclk (clk),
    .ext_rst(rst),
    .aux_rst(aux_rst),

    .mie        (mie),
    .exi        (exi),
    .exi_code   (exi_code),
    .swi        (swi),
    .mie_set    (mie_set),
    .stall      (stall),
    .pc_epc     (pc_epc),

    .m32        (m32),
    .mvec       (mvec),
    .mepc       (mepc),
    .perf       (perf),

    .mem_request    (mem_request),
    .mem_rwn        (mem_rwn),
    .mem_finish     (mem_finish),
    .mem_partial    (mem_partial),
    .mem_addr       (mem_addr),
    .mem_through    (mem_through),
    .mem_write_data (mem_write_data),
    .mem_replace    (mem_replace),
    .mem_replace_set(mem_replace_set),
    .mem_replace_tag(mem_replace_tag),
    .mem_read_data  (mem_read_data),

    .invd_req   (invd_req),
    .invd_adr   (invd_addr),
    .invd_ack   (),

    .mgmt_req(mgmt_req),
    .mgmt_adr(mgmt_adr),
    .mgmt_ack(mgmt_ack),
    .mgmt_rwn(mgmt_rwn),
    .mgmt_wen(mgmt_wen),
    .mgmt_txd(mgmt_txd),
    .mgmt_rxe(mgmt_rxe),
    .mgmt_rxd(mgmt_rxd)
);

wire        reg_mgmt_ack;
wire        reg_mgmt_rxe;
wire[31:0]  reg_mgmt_rxd;
mp_reg reg_ctl(
	.clk(clk),
	.rst(rst),

    .swi(swi),
    .exi(exi),
    .perf(perf),
    .stall(stall),
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

mp_mc mem_ctl(
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

//Simulator of Internal SRAM
assign aux_rst = 0;

`define DELAY 22

reg[7:0] mem[65535:0];

integer m,n;
integer cnt, cnt1;
initial cnt = `DELAY;
initial cnt1 = 0;

wire mem_read_request, mem_write_request;
assign mem_read_request  = mem_request &&  mem_rwn;
assign mem_write_request = mem_request && !mem_rwn;

//for SRAM
assign mem_partial = 0;
assign mem_replace = mem_finish && mem_rwn;
assign mem_replace_set = mem_addr[8:4];
assign mem_replace_tag = mem_addr[15:9];

wire[15:0] mem_addr_line = {mem_addr[15:4], 4'b0};

always @(posedge clk)
begin
    if(!mem_finish)
    begin
        if(mem_read_request || mem_write_request)
        begin
            if(cnt == 0)
            begin
                if(mem_write_request)
                    for(m = 0; m < 16; m = m + 1)
                    mem[mem_addr_line+m] <= mem_write_data[m*8+:8];
                if(mem_read_request)
                    for(n = 0; n < 16; n = n + 1)
                    mem_read_data[n*8+:8] <= mem[mem_addr_line+n];
                mem_finish <= 1;
                cnt1 <= cnt1 + 1;
            end else
            begin
                cnt <= cnt - 1;
            end
        end
    end else
    begin
        mem_finish <= 0;
        cnt <= `DELAY;
    end
end

`ifdef DEBUG
integer fd, j;
initial
begin
    for(j = 0; j < 65536; j = j + 1) mem[j] = 0;
    fd = $fopen("test_instructions.bin","rb");
    $fread(mem, fd);
    //$readmemh("test_data.txt", mem);
    //#500000;
    //$writememh("test_data_out.txt", mem, 0, 1023);
    //$stop;
end
`endif

//Simulator of DRAM Access
assign invd_req = 0;

reg         dram_rwn;
reg[7:0]    dram_txd;
reg[31:0]   dram_addr;

assign host_req = 1;
assign host_rwn = 0;
assign host_txm = 0;
assign host_burst = 1;
assign host_txd = {~dram_txd, dram_txd};
assign host_addr = dram_addr;

always @(posedge clk or posedge rst)
begin
    if(rst)
    begin
        dram_txd <= 0;
    end else
    begin
        if(host_txd_ack) dram_txd <= dram_txd + 1;
    end
end

always @(posedge clk or posedge rst)
begin
    if(rst)
    begin
        dram_addr <= 0;
    end else
    if(host_ack)
    begin
        dram_addr <= dram_addr + 16;
    end
end

endmodule
