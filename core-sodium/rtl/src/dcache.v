`include "defines.v"

`define READY           3'b001
`define REPLACE_OUT     3'b010
`define REPLACE_IN      3'b100

module dcache_line(
    input         CLK,
    input         CEN,
    input [4:0]   A,
    input [15:0]  WEN,
    input [127:0] D,
    output[127:0] Q
);

reg[4:0]    addr;
reg[127:0]  data[31:0];

assign Q =  data[addr];

integer i;
always @(posedge CLK)
begin
    if(!CEN)
    begin
        addr <= A;
        for(i = 0; i < 16; i = i + 1) data[A][i*8+:8] <= WEN[i] ? data[A][i*8+:8] : D[i*8+:8];
    end
end
endmodule

module dcache_tags(
    input        CLKA,
    input        CENA,
    input[4:0]   AA,
    output[6:0]  QA,
    input        CLKB,
    input        CENB,
    input[4:0]   AB,
    input[6:0]   DB
);

reg[4:0]    addr;
reg[8:0]    data[31:0];

assign QA = data[addr];

always @(posedge CLKA)
begin
    if(!CENA) addr <= AA;
end
always @(posedge CLKB)
begin
    if(!CENB) data[AB] <= DB;
end
endmodule

module dcache_permute(
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

    output reg wb,
    output reg wb32,
    output[31:0] wb_data,

    input       invd_req,
    output reg  invd_ack,
    input[15:0] invd_adr,

    output reg          mem_request,
    output reg          mem_rwn,
    input               mem_finish,

    output reg[15:0]    mem_addr,
    output reg          mem_through,    //write through for cache line flush
    output reg[15:0]    mem_commit,     //commit data to Line Filler during writing miss
    output reg[127:0]   mem_write_data,

    input               mem_partial,    //read partial, if the line not all filled.
    input               mem_replace,
    input[4:0]          mem_replace_set,
    input[6:0]          mem_replace_tag,
    input[127:0]        mem_read_data
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

wire[3:0] lsu_addr_ofs = lsu_addr_in[3:0];
wire[4:0] lsu_addr_set = lsu_addr_in[8:4];
wire[6:0] lsu_addr_tag = lsu_addr_in[15:9];

reg       cache_sel;
reg       cache_rwn;
reg[1:0]  cache_mode;
reg[7:0]  cache_mask;
reg       cache_zero;
reg       cache_flsh;

reg[3:0]  cache_ofs;
reg[4:0]  cache_set;
reg[6:0]  cache_tag;
reg[31:0] cache_data;
reg[31:0] cache_seek;

always @(posedge sys_clk)
begin
    if(!stall && issue)
    begin
        cache_sel  <= sel;
        cache_rwn  <= lsu_rwn;
        cache_mode <= tag2;
        cache_zero <= lsu_zero;
        cache_seek <= lsu_seek;
        cache_mask <= lsu_mask;
        cache_flsh <= lsu_flush;
        cache_ofs  <= lsu_addr_ofs;
        cache_set  <= lsu_addr_set;
        cache_tag  <= lsu_addr_tag;
        cache_data <= lsu_data_in;
    end
end

wire[31:0]  cache_data32 = {fwd_en[1] ? fwd_data[31:16] : cache_data[31:16],
                            fwd_en[0] ? fwd_data[15:0]  : cache_data[15:0]};
wire[15:0]  cache_data16 =  cache_sel ? cache_data32[31:16] : cache_data32[15:0];

wire[127:0] cache_data128 = (cache_mode == `TAG_LSW ? cache_data32 : {16'b0, cache_data16}) << (8 * cache_ofs);

//Cache Resources
reg[31:0] valid;
reg[31:0] dirty;

wire[6:0] tag;
wire      update;
wire[4:0] newset;
wire[6:0] newtag;
dcache_tags tags(
    .CLKA(sys_clk),
    .CENA(!issue),
    .AA(lsu_addr_set),
    .QA(tag),
    .CLKB(sys_clk),
    .CENB(!update),
    .AB(newset),
    .DB(newtag)
);

wire cache_vld = |(valid & cache_seek);
wire cache_dir = |(dirty & cache_seek);
wire cache_hit = !cache_flsh && cache_vld && cache_tag == tag;

//Finite State Machine
reg[2:0] fsm;
always @(posedge sys_clk or posedge sys_rst)
begin
    if(sys_rst)                     fsm <= `READY;
    else
    case(fsm)
    `READY:
    if(cache_issue && !cache_hit)   fsm <= cache_dir ? (cache_zero ? `REPLACE_IN : `REPLACE_OUT) : (cache_zero ? `READY : `REPLACE_IN);
    else                            fsm <= `READY;
    `REPLACE_OUT:                   fsm <= mem_finish ? `REPLACE_IN : `REPLACE_OUT;
    `REPLACE_IN:                    fsm <= mem_finish ? `READY      : `REPLACE_IN;
    endcase
end
always @(*)
begin
    case(fsm)
    `READY:       stall <= cache_issue ? (cache_hit ? 0 : !cache_zero) : 0;
    `REPLACE_OUT: stall <= 1;
    `REPLACE_IN:  stall <= 1;
    default:      stall <= 1'bx;
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

dcache_line cache_lines(
    .CLK    (!sys_clk),
    .CEN    (~line_cen),
    .WEN    (~line_wen),
    .A      (line_adr),
    .D      (line_din),
    .Q      (line_dout)
);

always @(*)
begin
    if(cache_issue)
    begin
        if(cache_hit)
        begin   //cache hit
            line_cen <= 1;
            line_wen <= rf_mask;
            line_adr <= cache_set;
            line_din <= cache_data128;
        end else
        if(cache_dir)
        begin   //dirty write back
            line_cen <= 1;
            line_wen <= 0;
            line_adr <= cache_set;
            line_din <= 128'hx;
        end else
        begin   //zero or do nothing
            line_cen <= cache_zero;
            line_wen <= 16'hffff;
            line_adr <= cache_set;
            line_din <= 0;
        end
    end else
    begin
        if(replace_fin)
        begin   //finish cycle
            line_cen <= 1;
            line_wen <= rf_mask;
            line_adr <= cache_set;
            line_din <= cache_data128;
        end else
        begin   //cache line replace
            line_cen <= mem_replace;
            line_wen <= 16'hffff;
            line_adr <= mem_replace_set;
            line_din <= mem_read_data;
        end
    end
end

//Write Back
always @(*)
begin
    wb   <= stall ? 0 : (replace_fin || cache_issue) && cache_rwn;
    wb32 <= (replace_fin || cache_issue) ? cache_mode == `TAG_LSW : 0;
end
dcache_permute permute(
    .A(line_dout),
    .M(rf_mask_raw),
    .S(cache_ofs[1:0]),
    .T(cache_mode),
    .Y(wb_data)
);









assign update = mem_replace || (fsm == `READY && cache_issue && !cache_hit && !cache_dir && cache_zero); //TODO: Too long path
assign newtag = mem_replace ? mem_replace_tag : cache_tag;
assign newset = mem_replace ? mem_replace_set : cache_set;

always @(posedge sys_clk or posedge sys_rst)
begin
    if(sys_rst)
    begin
        mem_request <= 0;
    end else
    begin
        case(fsm)
        `READY:
        if(cache_issue && !cache_hit)
        begin
            if(cache_dir)
            begin
                //$display("write back set %d.", cache_set);
                mem_request <= 1;
                mem_rwn <= 0;
                mem_addr <= {tag, cache_set, cache_ofs};
                mem_write_data <= line_dout;
            end else
            if(!cache_zero)
            begin
                //$display("allocate set %d and load data from mem.", cache_set);
                mem_request <= 1;
                mem_rwn <= 1;
                mem_addr <= {cache_tag, cache_set, cache_ofs};
                mem_write_data <= 0;
            end else
            begin
                //$display("fake allocate set %d.", cache_set);
                mem_request <= 0;
                mem_rwn <= 1'bx;
                mem_addr <= 16'hx;
                mem_write_data <= 128'hx;
            end
        end else
        begin
                mem_request <= 0;
                mem_rwn <= 1'bx;
                mem_addr <= 16'hx;
                mem_write_data <= 128'hx;
        end
        `REPLACE_OUT:
        if(mem_finish)
        begin
                mem_request <= 1;
                mem_rwn <= 1;
                mem_addr <= {cache_tag, cache_set, cache_ofs};
                mem_write_data <= 0;
        end
        `REPLACE_IN:
        if(mem_finish)
        begin
                mem_request <= 0;
                mem_rwn <= 1'bx;
                mem_addr <= 16'hx;
                mem_write_data <= 128'hx;
        end
        endcase
    end
end

always @(posedge sys_clk or posedge sys_rst)
begin
    if(sys_rst)
    begin
        valid <= 0;
        dirty <= 0;
    end else
    begin
        case(fsm)
        `READY:
        begin
            if(cache_issue)
            begin
                if(cache_hit && !cache_rwn) dirty[cache_set] <= 1;
                if(!cache_hit)
                begin
                    if(!cache_dir && cache_zero)
                    begin
                        valid[cache_set] <= 1;
                        dirty[cache_set] <= 1;
                    end
                end
            end
        end
        `REPLACE_IN:
        begin
            if(mem_finish) //mem_replace
            begin
                valid[cache_set] <= 1;
                dirty[cache_set] <= !cache_rwn;
            end
        end
        endcase
    end
end

endmodule
