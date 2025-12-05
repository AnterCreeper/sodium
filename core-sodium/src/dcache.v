`include "defines.v"

`define READY           3'b001
`define REPLACE_OUT     3'b010
`define REPLACE_IN      3'b100

module lsu_tags(
    input CLK,
    input           CENA,
    input[4:0]      AA,
    output reg[6:0] QA,
    input           CENB,
    input[4:0]      AB,
    output reg[6:0] QB,
    input           CENC,
    input[4:0]      AC,
    input[6:0]      DC,
    input           CEND,
    input[4:0]      AD,
    input[6:0]      DD
);

reg _CENA, _CENB;   //remove dirty gate
always @(negedge CLK)
begin
    _CENA <= CENA;
    _CENB <= CENB;
end

wire[6:0] _QA;
always @(*)         //latch output data
begin
    if(!_CENA) QA = _QA;
    if(!_CENB) QB = _QA;
end

reg[4:0] _AA;
reg[4:0] _AB;
reg[6:0] _DB;
always @(*)
begin
    case({CENB, CENA})
    2'b10:   _AA = AA;
    2'b01:   _AA = AB;
    default: _AA = 5'bx;
    endcase
    case({CEND, CENC})
    2'b10:   _AB = AC;
    2'b01:   _AB = AD;
    default: _AB = 5'bx;
    endcase
    case({CEND, CENC})
    2'b10:   _DB = DC;
    2'b01:   _DB = DD;
    default: _DB = 7'bx;
    endcase
end

sram_sdp #(5, 7)    //32x7 SRAM, simple dual port
tags_ram (
    .CLK    (CLK),
    .CENA   (CENA&&CENB),
    .AA     (_AA),
    .QA     (_QA),
    .CENB   (CENC&&CEND),
    .AB     (_AB),
    .DB     (_DB)
);

endmodule

module lsu_permute(
    input[127:0] A,
    input[15:0]  M,

    input[1:0]   S,
    input[1:0]   T,
    output reg[31:0] Y
);

wire[127:0] B;
genvar i;
generate
for(i = 0; i < 16; i = i + 1) assign B[i*8+:8] = M[i] ? 8'hff : 8'h0;
endgenerate

wire[127:0] D  = A & B;
wire[31:0]  Di = D[127:96] | D[95:64] | D[63:32] | D[31:0];

always @(*)
begin
    case(T)
    `TAG_LSW:   Y <= Di;
    `TAG_LSH:   Y <= {16'h0, S[1] ? Di[31:16] : Di[15:0]};
    `TAG_LSB:
    case(S[1:0])
    2'b00:      Y <= {{24{Di[7]}},  Di[7:0]};
    2'b01:      Y <= {{24{Di[15]}}, Di[15:8]};
    2'b10:      Y <= {{24{Di[23]}}, Di[23:16]};
    2'b11:      Y <= {{24{Di[31]}}, Di[31:24]};
    endcase
    `TAG_LBU:
    case(S[1:0])
    2'b00:      Y <= {24'b0, Di[7:0]};
    2'b01:      Y <= {24'b0, Di[15:8]};
    2'b10:      Y <= {24'b0, Di[23:16]};
    2'b11:      Y <= {24'b0, Di[31:24]};
    endcase
    endcase
end
endmodule

module mp_dcache (
    input sys_clk,
    input sys_rst,

    output reg  stall,
    input       issue,

    input       sel,
    input[1:0]  tag2,
    input       lsu_rwn,
    input[7:0]  lsu_mask,
    input[31:0] lsu_seek,

    input       lsu_zero,
    input       lsu_invd,
    input       lsu_flush,
    input       lsu_clean,
    
    input[31:0] lsu_data_in,
    input[15:0] lsu_addr_in,
    
    input[1:0]  fwd_en,
    input[31:0] fwd_data,

    output reg   wb,
    output reg   wb32,
    output[31:0] wb_data,

    input       invd_req,
    output      invd_ack,
    input[15:0] invd_adr,

    output reg          mem_request,
    output reg          mem_rwn,
    input               mem_finish,
    input               mem_partial,

    output reg[15:0]    mem_addr,
    output reg[15:0]    mem_commit,     //commit data to Line Filler during writing miss
    output reg[127:0]   mem_write_data,

    input               mem_replace,
    input[4:0]          mem_replace_set,
    input[6:0]          mem_replace_tag,
    input[127:0]        mem_replace_dat
);

//Input Data Latch
reg cache_issue;
always @(posedge sys_clk or posedge sys_rst)
begin
    if(sys_rst)
    begin
        cache_issue <= 0;
    end else
    if(!stall)
    begin
        cache_issue <= issue;
    end else
    begin
        cache_issue <= 0;
    end
end

wire[6:0] lsu_tag = lsu_addr_in[15:9];
wire[4:0] lsu_set = lsu_addr_in[8:4];
wire[3:0] lsu_offset = lsu_addr_in[3:0];

reg       cache_sel;
reg       cache_rwn;
reg[1:0]  cache_mode;
reg[7:0]  cache_mask;
reg       cache_zero;
reg       cache_flush;

reg[3:0]  cache_byte;
reg[4:0]  cache_nset;
reg[6:0]  cache_ntag;
reg[31:0] cache_data;
reg[31:0] cache_seek;   //one hot of cache set

always @(posedge sys_clk)
begin
    if(!stall && issue)
    begin
        cache_sel   <= sel;
        cache_rwn   <= lsu_rwn;
        cache_mode  <= tag2;

        cache_ntag  <= lsu_tag;
        cache_nset  <= lsu_set;
        cache_seek  <= lsu_seek;
        cache_byte  <= lsu_offset;

        cache_mask  <= lsu_mask;
        cache_data  <= lsu_data_in;

        cache_zero  <= lsu_zero;
        cache_flush <= lsu_flush;
    end
end

wire[31:0]  cache_data32 = {fwd_en[1] ? fwd_data[31:16] : cache_data[31:16],
                            fwd_en[0] ? fwd_data[15:0]  : cache_data[15:0]};
wire[15:0]  cache_data16 =  cache_sel ? cache_data32[31:16] : cache_data32[15:0];

wire[127:0] cache_data128 = (cache_mode == `TAG_LSW ? cache_data32 : {16'b0, cache_data16}) << (8 * cache_byte);

//Cache Resources
wire        look_cen;
wire[4:0]   look_adr;
wire[6:0]   look_tag;
assign look_cen = issue;
assign look_adr = lsu_set;

wire[31:0]  valid;
wire[31:0]  dirty;
wire cache_vld  = |(valid & cache_seek);
wire cache_dir  = |(dirty & cache_seek);
wire cache_hit  = !cache_flush && cache_vld && cache_ntag == look_tag;

//Finite State Machine
reg[2:0] fsm;
always @(posedge sys_clk or posedge sys_rst)
begin
    if(sys_rst)                     fsm <= `READY;
    else
    if(cache_issue && !cache_hit)   fsm <= cache_dir ? (cache_zero ? `REPLACE_IN : `REPLACE_OUT) : (cache_zero ? `READY : `REPLACE_IN);
    else
    case(fsm)
    `READY:                         fsm <= `READY;
    `REPLACE_OUT:                   fsm <= mem_finish ? `REPLACE_IN : `REPLACE_OUT;
    `REPLACE_IN:                    fsm <= mem_finish ? `READY      : `REPLACE_IN;
    default:                        fsm <= 3'bx;
    endcase
end
always @(*)
begin
    if(cache_issue) stall <= !cache_hit;
    else
    case(fsm)
    `READY:         stall <= 0;
    `REPLACE_OUT:   stall <= 1;
    `REPLACE_IN:    stall <= 1;
    default:        stall <= 1'bx;
    endcase
end

reg replace_fin;
always @(posedge sys_clk or posedge sys_rst)
begin
    if(sys_rst) replace_fin <= 0;
    else        replace_fin <= fsm == `REPLACE_IN && mem_finish;
end

//Mask Gen
reg[15:0] rf_mask_raw;
always @(*)
begin
    rf_mask_raw <= {cache_mask[7] ? cache_mask[3:0] : 4'b0,
                    cache_mask[6] ? cache_mask[3:0] : 4'b0,
                    cache_mask[5] ? cache_mask[3:0] : 4'b0,
                    cache_mask[4] ? cache_mask[3:0] : 4'b0};
end
wire[15:0] rf_mask = cache_rwn ? 0 : (cache_zero ? 16'hffff : rf_mask_raw);

//Cache Line RAM
reg         line_cen;
reg[15:0]   line_wen;
reg[4:0]    line_adr;
reg[127:0]  line_din;
wire[127:0] line_dout;
sram_sp_mask #(5, 128, 4) //32x128 SRAM, with byte mask
dcache_line(
    .CLK    (!sys_clk),
    .CEN    (~line_cen),
    .WEN    (~line_wen),
    .A      (line_adr),
    .D      (line_din),
    .Q      (line_dout)
);

//Cache Signal
always @(*)
begin
    if(cache_issue)
    begin
        if(cache_hit)
        begin   //cache hit
            line_cen <= 1;
            line_wen <= rf_mask;
            line_adr <= cache_nset;
            line_din <= cache_data128;
        end else
        if(cache_dir)
        begin   //dirty write back
            line_cen <= 1;
            line_wen <= 0;
            line_adr <= cache_nset;
            line_din <= 128'hx;
        end else
        begin   //zero or do nothing
            line_cen <= cache_zero;
            line_wen <= 16'hffff;
            line_adr <= cache_nset;
            line_din <= 0;
        end
    end else
    begin
        if(replace_fin)
        begin   //finish cycle
            line_cen <= 1;
            line_wen <= rf_mask;
            line_adr <= cache_nset;
            line_din <= cache_data128;
        end else
        begin   //cache line replace
            line_cen <= mem_replace;
            line_wen <= 16'hffff;
            line_adr <= mem_replace_set;
            line_din <= mem_replace_dat;
        end
    end
end

//MEMIF Signal
always @(posedge sys_clk or posedge sys_rst)
begin
    if(sys_rst)
    begin
        mem_request <= 0;
    end else
    begin
        if(cache_issue && !cache_hit)
        begin
            if(cache_dir)
            begin
                //$display("write back set %d.", cache_nset);
                mem_request <= 1;
                mem_rwn <= 0;
                mem_addr <= {look_tag, cache_nset, cache_byte};
                mem_commit <= 16'hx;
                mem_write_data <= line_dout;
            end else
            if(cache_zero)
            begin
                //$display("fake allocate set %d.", cache_nset);
                mem_request <= 0;
                mem_rwn <= 1'bx;
                mem_addr <= 16'hx;
                mem_commit <= 16'hx;
                mem_write_data <= 128'hx;
            end else
            begin
                //$display("allocate set %d and load data from mem.", cache_nset);
                mem_request <= 1;
                mem_rwn <= 1;
                mem_addr <= {cache_ntag, cache_nset, cache_byte};
                mem_commit <= rf_mask;
                mem_write_data <= cache_data128;
            end
        end else
        case(fsm)
        `READY:
        begin
                mem_request <= 0;
                mem_rwn <= 1'bx;
                mem_addr <= 16'hx;
                mem_commit <= 16'hx;
                mem_write_data <= 128'hx;
        end
        `REPLACE_OUT:
        if(mem_finish)
        begin
                mem_request <= 1;
                mem_rwn <= 1;
                mem_addr <= {cache_ntag, cache_nset, cache_byte};
                mem_commit <= rf_mask;
                mem_write_data <= cache_data128;
        end
        `REPLACE_IN:
        if(mem_finish)
        begin
                mem_request <= 0;
                mem_rwn <= 1'bx;
                mem_addr <= 16'hx;
                mem_commit <= 16'hx;
                mem_write_data <= 128'hx;
        end
        endcase
    end
end

//Core Writeback
always @(*)
begin
    wb   <= (replace_fin || cache_issue) && cache_rwn && !stall;
    wb32 <= (replace_fin || cache_issue) && cache_mode == `TAG_LSW;
end
lsu_permute dcache_permute(
    .A(line_dout),
    .M(rf_mask_raw),
    .S(cache_byte[1:0]),
    .T(cache_mode),
    .Y(wb_data)
);

//Valid & Dirty
reg         valid_mask;
reg         valid_data;
reg[31:0]   valid_seek;
reg         dirty_mask;
reg         dirty_data;
reg[31:0]   dirty_seek;
always @(*)
begin
    if(cache_issue)
    begin
        valid_mask <= cache_zero;
        dirty_mask <= cache_hit ? !cache_rwn : cache_zero;
        valid_seek <= cache_seek;
        dirty_seek <= cache_seek;
        valid_data <= 1;
        dirty_data <= 1;
    end
    else
    begin
        valid_mask <= mem_replace;
        dirty_mask <= mem_replace;
        valid_seek <= 1 << mem_replace_set;
        dirty_seek <= 1 << mem_replace_set;
        valid_data <= !mem_partial;
        dirty_data <= !mem_partial;
    end
end

wire        invd_true;
reg[31:0]   invd_seek;
dffs_sp_reset #(32)
dcache_valid(
    .CLK    (sys_clk),
    .RST    (~sys_rst),
    .CENA   (~valid_mask),
    .WENA   (~valid_seek),
    .DA     ({32{valid_data}}),
    .CENB   (~invd_true),
    .WENB   (~invd_seek),
    .Q      (valid)
);
dffs_sp_reset #(32)
dcache_dirty(
    .CLK    (sys_clk),
    .RST    (~sys_rst),
    .CENA   (~dirty_mask),
    .WENA   (~dirty_seek),
    .DA     ({32{dirty_data}}),
    .CENB   (~invd_true),
    .WENB   (~invd_seek),
    .Q      (dirty)
);

//Cache Tag RAM
wire        invd_wen;
wire[4:0]   invd_set;
wire[6:0]   invd_tag;
assign invd_wen = invd_req && !issue;
assign invd_set = invd_adr[8:4];
assign invd_ack = invd_wen;
wire        zero_wen;
assign zero_wen = cache_issue && cache_zero;

reg         invd_test;
reg[6:0]    invd_ctag;
always @(posedge sys_clk)
begin
    invd_test <= invd_ack;
    invd_ctag <= invd_adr[15:9];
    invd_seek <= 1 << invd_set;
end
assign invd_true = invd_test && invd_tag == invd_ctag;

lsu_tags dcache_tags(
    .CLK    (sys_clk),
    .CENA   (!look_cen),
    .AA     (look_adr),
    .QA     (look_tag),
    .CENB   (!invd_ack),
    .AB     (invd_set),
    .QB     (invd_tag),
    .CENC   (!mem_replace),
    .AC     (mem_replace_set),
    .DC     (mem_replace_tag),
    .CEND   (!zero_wen),
    .AD     (cache_nset),
    .DD     (cache_ntag)
);

endmodule
