`include "defines.v"

module system(
	input       ref_clk,
	input       ext_rst,

	output      uart_tx,

	/*
	output 		dram_cs,
	output 		dram_clk,
	inout[7:0] 	dram_adq,
	inout 		dram_rwds,

	output      rgmii_mdc,
	output      rgmii_mdio,

	inout       usb_dp,
	inout       usb_dn,
	output      usb_pu,
	*/

    output[7:0] trace
);

//Unused Pin
wire        dram_cs;
wire        dram_clk;
wire[7:0] 	dram_adq;
wire        dram_rwds;
wire        rgmii_mdc;
wire        rgmii_mdio;

//System
wire        aux_rst;
wire        sys_clk;
wire        sys_rst;    //50MHz
//wire      usb_clk;    //60MHz
`ifdef DEBUG
assign sys_clk = ref_clk;
assign sys_rst = ext_rst;
`else
sys_clkgen sys_clkgen(
    .ref_clk(ref_clk),
    .ext_rst(ext_rst),
    .sys_clk(sys_clk),
    .sys_rst(sys_rst)
);
`endif

wire 		mgmt_req;
wire[31:0] 	mgmt_adr;
wire        mgmt_rwn;
wire[1:0]   mgmt_wen;
wire[31:0] 	mgmt_txd;

wire		mgmt_ack;
reg 		mgmt_rxe;
reg[31:0] 	mgmt_rxd;

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
wire[15:0]  cr0, cr1, cr2;
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

wire        sys_init;

wire        insn_reset;
wire        insn_request;
wire[15:0]  insn_addr;
wire        insn_valid;
wire[31:0]  insn_data;

//Core
mp_core core(
    .sys_clk    (sys_clk),
    .sys_rst    (sys_rst),
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
    .trace      (trace),

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

    .insn_reset     (insn_reset),
    .insn_request   (insn_request),
    .insn_addr      (insn_addr),
    .insn_valid     (insn_valid),
    .insn_data      (insn_data),

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

//TODO N.C. over Dcache Invalid Path
assign invd_req  = 0;
assign invd_addr = 16'hx;

//PIC
wire        pic_mgmt_ack;
wire        pic_mgmt_rxe;
wire[31:0]  pic_mgmt_rxd;

wire[31:0]  sys_irq;

pic_core pic(
	.clk(sys_clk),
	.rst(sys_rst),

    .irq(sys_irq & ~mask),

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

wire        reg_mgmt_ack;
wire        reg_mgmt_rxe;
wire[31:0]  reg_mgmt_rxd;

sysreg_core sysreg(
	.clk(sys_clk),
	.rst(sys_rst),
	.init(sys_init),

    .swi(swi),
    .exi(exi),
    .perf(perf),
    .pc_epc(pc_epc),
    .mie_set(mie_set),

    .cr0(cr0),
    .cr1(cr1),
    .cr2(cr2),
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

`ifdef DEBUG
wire        sim_stop;
`endif

wire        dbg_mgmt_ack;
wire        dbg_mgmt_rxe;
wire[31:0]  dbg_mgmt_rxd;

wire        fifo_tx_rdy;
wire        fifo_tx_vld;
wire[7:0]   fifo_tx_dat;
wire        fifo_rx_rdy;
wire        fifo_rx_vld;
wire[7:0]   fifo_rx_dat;

debug_core debug(
	.clk(sys_clk),
	.rst(sys_rst),

    .mgmt_req(mgmt_req),
    .mgmt_adr(mgmt_adr),
    .mgmt_ack(dbg_mgmt_ack),
    .mgmt_rwn(mgmt_rwn),
    .mgmt_wen(mgmt_wen),
    .mgmt_txd(mgmt_txd),
    .mgmt_rxe(dbg_mgmt_rxe),
    .mgmt_rxd(dbg_mgmt_rxd),

`ifdef DEBUG
    .sim_stop(sim_stop),
`endif
    .fifo_tx_rdy(fifo_tx_rdy),
    .fifo_tx_vld(fifo_tx_vld),
    .fifo_tx_dat(fifo_tx_dat)
);

`ifdef DEBUG
assign fifo_tx_rdy = 1'b1;
`else
uart_tx #(
    .CLK_FREQ   (`SYSCLK_FREQ*1000000),     // clk frequency, Unit : Hz
    .BAUD_RATE  (115200),                   // Unit : Hz
    .PARITY     ("NONE"),                   // "NONE", "ODD", or "EVEN"
    .STOP_BITS  (1),                        // can be 1, 2, 3, 4, ...
    .BYTE_WIDTH (1),                        // AXI stream data width, can be 1, 2, 3, 4, ...
    .FIFO_EA    (0),                        // 0:no fifo; 1,2:depth=4; 3:depth=8; 4:depth=16; ...; 10:depth=1024; 11:depth=2048; ...;
    // do you want to send extra byte after each AXI-stream transfer or packet?
    .EXTRA_BYTE_AFTER_TRANSFER (""),        // specify a extra byte to send after each AXI-stream transfer. when ="", do not send this extra byte
    .EXTRA_BYTE_AFTER_PACKET   ("")         // specify a extra byte to send after each AXI-stream packet  . when ="", do not send this extra byte
)
debug_uart (
    .clk(sys_clk),
    .rstn(!sys_rst),

    .i_tready(fifo_tx_rdy),
    .i_tvalid(fifo_tx_vld),
    .i_tdata(fifo_tx_dat),
    .i_tkeep(fifo_tx_vld),  //byte-enable of tvalid
    .i_tlast(1'b0),         //invalid for no send extra byte

    .o_uart_tx(uart_tx)
);
/*
wire usb_dp_rx;
wire usb_dn_rx;
wire usb_dp_pu;
wire usb_tx_en;
wire usb_dp_tx;
wire usb_dn_tx;

usb_cdc #(
    .CHANNELS               ('d1),
    .USE_APP_CLK            ('d1),
    .APP_CLK_FREQ           (`SYSCLK_FREQ),
    .VENDORID               (`USB_VENDORID),
    .PRODUCTID              (`USB_PRODUCTID),
    .IN_BULK_MAXPACKETSIZE  (`USB_BULK_SIZE),
    .OUT_BULK_MAXPACKETSIZE (`USB_BULK_SIZE),
    .BIT_SAMPLES            (`USB_BIT_SAMPLES)
)
debug_usbcdc (
//SYS
    .app_clk_i(sys_clk),
    //TX
    .in_ready_o (fifo_tx_rdy),
    .in_valid_i (fifo_tx_vld),
    .in_data_i  (fifo_tx_dat),
    //RX
    .out_ready_i(fifo_rx_rdy),
    .out_valid_o(fifo_rx_vld),
    .out_data_o (fifo_rx_dat),

//USB
    .clk_i  (usb_clk),
    .rstn_i (!sys_rst),
    //IO
    .dp_rx_i(usb_dp_rx),
    .dn_rx_i(usb_dn_rx),
    .dp_pu_o(usb_dp_pu),
    .tx_en_o(usb_tx_en),
    .dp_tx_o(usb_dp_tx),
    .dn_tx_o(usb_dn_tx),

//Internal
    .frame_o(),
    .configured_o()
);

//USB Tri-state IO
assign usb_dp = usb_tx_en ? usb_dp_tx : 1'bz;
assign usb_dn = usb_tx_en ? usb_dn_tx : 1'bz;
assign usb_pu = usb_dp_pu;
assign usb_dp_rx = usb_dp;
assign usb_dn_rx = usb_dn;
*/
`endif

//TODO N.C. over Debug Receive Path
assign fifo_rx_rdy = 1'b1;

wire        mc_mgmt_ack;
wire        mc_mgmt_rxe;
wire[31:0]  mc_mgmt_rxd;

wire        ram_adq_oe;
wire[7:0]	ram_adq_out;
wire		ram_rwds_oe;
wire		ram_rwds_out;

ram_core memory(
	.clk(sys_clk),
	.rst(sys_rst),

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

	.ram_cs        (dram_cs),
	.ram_clk       (dram_clk),
	.ram_adq_oe    (ram_adq_oe),
	.ram_adq_in    (dram_adq),
	.ram_adq_out   (ram_adq_out),
	.ram_rwds_oe   (ram_rwds_oe),
	.ram_rwds_in   (dram_rwds),
	.ram_rwds_out  (ram_rwds_out)
);

//Memory Tri-state IO
assign dram_adq  = ram_adq_oe  ? ram_adq_out  : 8'bz;
assign dram_rwds = ram_rwds_oe ? ram_rwds_out : 1'bz;

wire        net_mgmt_ack;
wire        net_mgmt_rxe;
wire[31:0]  net_mgmt_rxd;

wire        mdio_txe, mdio_txd;

mdio_core net(
	.clk(sys_clk),
	.rst(sys_rst),

    .mgmt_req(mgmt_req),
    .mgmt_adr(mgmt_adr),
    .mgmt_ack(net_mgmt_ack),
    .mgmt_rwn(mgmt_rwn),
    .mgmt_wen(mgmt_wen),
    .mgmt_txd(mgmt_txd),
    .mgmt_rxe(net_mgmt_rxe),
    .mgmt_rxd(net_mgmt_rxd),

    .mdio_clk(rgmii_mdc),
    .mdio_txe(mdio_txe),
    .mdio_txd(mdio_txd),
    .mdio_rxd(rgmii_mdio)
);

//Network Tri-state IO
assign rgmii_mdio = mdio_txe ? mdio_txd : 1'bz;

//System IRQ
assign sys_irq = 0;

//TODO MGMT BUS Hub
always @(posedge sys_clk)
begin
    case({reg_mgmt_rxe, mc_mgmt_rxe, pic_mgmt_rxe, net_mgmt_rxe, dbg_mgmt_rxe})
    5'b10000: begin mgmt_rxe <= 1'b1; mgmt_rxd <= reg_mgmt_rxd; end
    5'b01000: begin mgmt_rxe <= 1'b1; mgmt_rxd <= mc_mgmt_rxd;  end
    5'b00100: begin mgmt_rxe <= 1'b1; mgmt_rxd <= pic_mgmt_rxd; end
    5'b00010: begin mgmt_rxe <= 1'b1; mgmt_rxd <= net_mgmt_rxd; end
    5'b00001: begin mgmt_rxe <= 1'b1; mgmt_rxd <= dbg_mgmt_rxd; end
    5'b00000: begin mgmt_rxe <= 1'b0; mgmt_rxd <= 32'bx;        end
    default:  begin mgmt_rxe <= 1'bx; mgmt_rxd <= 32'bx;        end
    endcase
end

assign mgmt_ack = reg_mgmt_ack | mc_mgmt_ack | pic_mgmt_ack | net_mgmt_ack | dbg_mgmt_ack;

//TODO N.C. over DRAM Memory Path
assign host_req = 0;

//TODO N.C. over AUX Sync Reset Path
assign aux_rst = 0;

//Simulator of Memory System
`ifdef DEBUG
reg sim_finish;
initial
begin
    sim_finish <= 0;
    #`MAX_RUN_CYCLES;
    sim_finish <= `DEBUG_FINISH;
end
sim_memory_generic sim_memory(
//sim_memory_dynamic sim_memory(
    .sys_clk        (sys_clk),
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
`else
sys_ocm ocm(
    .sys_clk        (sys_clk),
    .sys_rst        (sys_rst),
//Data Path
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
    .mem_replace_dat(mem_replace_dat),
//Insn Path
    .insn_reset     (insn_reset),
    .insn_request   (insn_request),
    .insn_addr      (insn_addr),
    .insn_valid     (insn_valid),
    .insn_data      (insn_data)
);
`endif

endmodule
