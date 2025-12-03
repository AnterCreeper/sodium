`include "defines.v"

module mp_branch(
    input sys_clk,
    input sys_setn,

    input       stall,
    output reg  stall_wfi,

    input       issue_jmp,
    input       issue_wfi,
    input       issue_swi,

    input       type, //1: jump; 0: branch
    input[2:0]  tag3,
    input[4:0]  tag5,
    input[2:0]  func3,
    input[31:0] imm32,

    input       m32,
    input[15:0] rb_data16,
    input[31:0] rb_data32,

    //Program Counter and Instruction Fetcher
    output reg[31:0] pc,
    output[31:0]     pc_epc,
    output[31:0]     fetch_addr,

    //Interrupt
    input       mie,    //external interrupt enable
    input       exi,    //external interrupt
    input[4:0]  exi_code,

    //Config Register
    input[31:0] mvec,   //interrupt vector entry
    input[31:0] mepc,

    //Branch Unit Writeback
    output reg          wb,
    output wire[4:0]    wb_rd,
    output reg[31:0]    wb_data
);

wire sign, zero;
assign sign = rb_data16[15];
assign zero = rb_data16 == 16'h0;

reg flag;
always @(*)
begin
    if(type)
                  flag <= 1;
    else
    case(func3)
    `FUNC_BCEZ  : flag <= zero;
    `FUNC_BCNZ  : flag <= !zero;
    `FUNC_BCGE  : flag <= !sign;
    `FUNC_BCLT  : flag <= sign;
    `FUNC_BCGT  : flag <= !sign && !zero;
    `FUNC_BCLE  : flag <= sign || zero;
    default:      flag <= 0;
    endcase
end

wire irq  = issue_swi || (mie ? exi : 0);
wire link = issue_jmp && type && (func3 == `FUNC_BL || func3 == `FUNC_BLR);

wire[5:0] code = issue_swi ? {1'b0, tag5} : {1'b1, exi_code};

wire[31:0] pc_plus4     = pc + 4;
wire[31:0] pc_plusimm   = pc + imm32;
wire[31:0] rb_plusimm   = {m32 ? rb_data32[31:16] : pc[31:16], rb_data16[15:1], 1'b0} + imm32;

wire[31:0] pc_int       = {mvec[31:9], code, 2'b0};
wire[31:0] pc_jmp       = !type || func3 == `FUNC_B || func3 == `FUNC_BL ? pc_plusimm : (func3 == `FUNC_MRET ? mepc : rb_plusimm);
wire[31:0] pc_nxt       = irq ? pc_int : (issue_jmp && flag ? pc_jmp : pc_plus4);

assign pc_epc = pc_plus4;

always @(posedge sys_clk or posedge sys_setn)
begin
    if(sys_setn)
    begin
        pc <= 0;
        stall_wfi <= 0;
    end else
    begin
        pc <= !stall ? pc_nxt : pc;
        stall_wfi <= issue_wfi || stall_wfi ? !exi : 0;
    end
end

assign wb_rd = `REG_RA;
assign fetch_addr = stall ? pc[31:0] : pc_nxt[31:0];

always @(posedge sys_clk or posedge sys_setn)
begin
    if(sys_setn) wb <= 0;
    else
    if(!stall)
    begin
        wb      <= link;
        wb_data <= pc_plus4;
    end
end
endmodule

module mp_bypass(
    input sys_clk,
    input sys_setn,

    input issue,

    input m32,
    input[31:0] data,

    //Writeback
    output reg       wb,
    output reg       wb32,
    output reg[31:0] wb_data
);

always @(posedge sys_clk or posedge sys_setn)
begin
    wb   <= sys_setn ? 0 : issue;
    wb32 <= sys_setn ? 0 : issue && m32;
end

always @(posedge sys_clk)
begin
    wb_data <= data;
end

endmodule

module mp_alu(
    input sys_clk,
    input sys_setn,

    input issue,

    input[2:0] tag3,
    input[2:0] func3,
    input[6:0] flag7,

    input[3:0] shift,
    input[15:0] data_in1,
    input[15:0] data_in2,

    input fwd_en1,
    input fwd_en2,
    input[15:0] fwd_data1,
    input[15:0] fwd_data2,

    output wb,
    output wb32,
    output[31:0] wb_data
);

reg         alu_issue;

reg[2:0]    alu_tag3;
reg[2:0]    alu_func3;
reg[6:0]    alu_flag7;

reg[3:0]    alu_cmd;
reg[15:0]   alu_data_in1;
reg[15:0]   alu_data_in2;

always @(posedge sys_clk or posedge sys_setn)
begin
    if(sys_setn) alu_issue <= 0;
    else alu_issue <= issue;
end

always @(posedge sys_clk)
begin
    alu_tag3     <= tag3;
    alu_func3    <= func3;
    alu_flag7    <= flag7;

    alu_cmd      <= !issue ? alu_cmd : shift;
    alu_data_in1 <= !issue ? alu_data_in1 : data_in1;
    alu_data_in2 <= !issue ? alu_data_in2 : data_in2;
end

wire[15:0] A = fwd_en1 ? fwd_data1 : alu_data_in1;
wire[15:0] B = fwd_en2 ? fwd_data2 : alu_data_in2;

wire alu_arith = alu_func3 == `FUNC_AU;
wire alu_shift = alu_func3 == `FUNC_SU;
wire alu_logic = alu_func3 == `FUNC_LU;
wire alu_btman = alu_func3 == `FUNC_BM;
wire alu_multi = alu_func3 == `FUNC_MU;

//Arith and Shift
wire[31:0] result_arith;
calc_arith arith(
    .A(A),
    .B(B),
    .S(alu_cmd),
    .MODE(alu_tag3),

    .EN(alu_arith || alu_shift),
    .CTL(alu_shift),
    .C(result_arith)
);

wire[31:0] result_logic;
calc_logic logic(
    .A(A),
    .B(B),
    .MODE(alu_tag3),

    .EN(alu_logic),
    .C(result_logic)
);

wire[31:0] result_btman;
calc_bitman btman(
    .A(A),
    .B(B),
    .S(alu_flag7),
    .MODE(alu_tag3),

    .EN(alu_btman),
    .C(result_btman)
);

wire[31:0] result_multi;
calc_mul multi(
    .a(A),
    .b(B),
    .m(alu_tag3),

    .EN(alu_multi),
    .y(result_multi)
);

wire alu_zero = A == 0;

wire alu_wb   = alu_func3 != `FUNC_AU || (
                alu_tag3 == `TAG_MOVZ ?  alu_zero : (
                alu_tag3 == `TAG_MOVN ? !alu_zero :
                1'b1));

wire alu_wb32 = alu_func3 == `FUNC_AU ? !alu_tag3[2] & (alu_tag3[1] ^ alu_tag3[0]) : (
                alu_func3 == `FUNC_MU ? !alu_tag3[2] & (alu_tag3[1] | alu_tag3[0]) : 0);

//Writeback
assign wb   = alu_issue && alu_wb;
assign wb32 = alu_issue && alu_wb32;
assign wb_data = result_arith | result_btman | result_logic | result_multi;

endmodule

module mp_sysbus(
    input sys_clk,
    input sys_setn,

    output reg  stall,
    input       issue,

    input       sel,
    input[1:0]  tag2,
    input[4:0]  pos5,
    input[2:0]  func3,

    input[31:0] evb_data_in,
    input[12:0] evb_addr_in,

    input[1:0]  fwd_en,
    input[31:0] fwd_data,

    output wb,
    output wb32,
    output reg[31:0] wb_data,

    output 			 mgmt_req,
	output[31:0] 	 mgmt_adr,
	input 			 mgmt_ack,
	output           mgmt_rwn,  //read enable
	output[1:0]      mgmt_wen,  //write enable
	output reg[31:0] mgmt_txd,
	input 			 mgmt_rxe,
	input[31:0] 	 mgmt_rxd
);

reg[1:0]  mie;
reg       evb_sel;
reg[31:0] evb_dat;
always @(*)
begin
    if(func3 == `FUNC_DW)
              mie <= `EVB_MASK_DUMMY;
    else
    case(tag2)
    `TAG_W:   mie <= `EVB_MASK_W;
    `TAG_H:   mie <= `EVB_MASK_H;
    `TAG_L:   mie <= `EVB_MASK_L;
    default:
              mie <= 2'bx;
    endcase
end

wire[31:0] evb_data32 = {fwd_en[1] ? fwd_data[31:16]   : evb_dat[31:16],
                         fwd_en[0] ? fwd_data[15:0]    : evb_dat[15:0]};
wire[15:0] evb_data16 =  evb_sel   ? evb_data32[31:16] : evb_data32[15:0];

reg         evb_en;
reg         evb_wb;
reg         evb_req;
reg         evb_fin;

reg[12:0]   evb_cmd;
reg         evb_rwn;
reg[1:0]    evb_wen;

reg[1:0]    evb_tag2;
reg[2:0]    evb_func3;

wire mgmt_fin = mgmt_rwn ? mgmt_rxe : mgmt_ack;

always @(posedge sys_clk or posedge sys_setn)
begin
    if(sys_setn)
    begin
        stall  <= 0;
        evb_en <= 0;
        evb_wb <= 0;
    end else
    begin
        stall  <= stall ? !evb_fin : issue;
        evb_en <= stall ? !mgmt_fin && evb_en : issue;
        evb_wb <= stall ? evb_wb : issue && func3 != `FUNC_DR;
    end
end
always @(posedge sys_clk or posedge sys_setn)
begin
    if(sys_setn)
    begin
        evb_req <= 0;
        evb_fin <= 0;
    end else
    begin
        evb_req <= stall ? !mgmt_ack && evb_req : issue;
        evb_fin <= evb_en && mgmt_fin;
    end
end

always @(posedge sys_clk)
begin
    if(issue)
    begin
        evb_sel     <= sel;
        evb_rwn     <= func3 != `FUNC_DR;
        evb_wen     <= mie;
        evb_tag2    <= tag2;
        evb_cmd     <= evb_addr_in;
        evb_dat     <= evb_data_in;
    end
end

assign wb   = evb_fin ? evb_wb : 0;
assign wb32 = evb_en ? evb_tag2 == `TAG_W : 0;

assign mgmt_req = evb_req;
assign mgmt_adr = {19'b0, evb_cmd};
assign mgmt_rwn = evb_rwn;
assign mgmt_wen = evb_wen;

always @(*)
begin
    case(evb_tag2)
    `TAG_W: mgmt_txd <= evb_data32;
    `TAG_H: mgmt_txd <= {evb_data16, 16'hx};
    `TAG_L: mgmt_txd <= {16'hx, evb_data16};
    endcase
end

always @(posedge sys_clk)
begin
    case(evb_tag2)
    `TAG_W: wb_data <= mgmt_rxd;
    `TAG_H: wb_data <= {mgmt_rxd[31:16], mgmt_rxd[31:16]};
    `TAG_L: wb_data <= mgmt_rxd;
    endcase
end
endmodule
