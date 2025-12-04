`include "defines.v"

module calc_booth(
    input[2:0] a,
    input[15:0] b,
    output x,
    output[31:0] y //partial product
);

wire s;
assign s = a[2]; //sign
wire[1:0] ai;
assign ai = s ? ~a : a;

wire[2:0] z;
assign z[0] = ~(ai[0]|ai[1]);   //zero
assign z[1] = ai[0]^ai[1];      //one
assign z[2] = ai[0]&ai[1];      //two

reg[31:0] res;
always @(*)
begin
    case(z)
    3'b001:
        res = 32'b0;
    3'b010:
        res = {{16{b[15]}},b};      //sign extend
    3'b100:
        res = {{15{b[15]}},b,1'b0}; //and left shift 1
    default: res = 32'bx;
    endcase
end

assign x = s;
assign y = s ? ~res : res;

endmodule

module calc_addtree(
    input[31:0] a,
    input[31:0] b,
    input[31:0] c,
    output[31:0] x,
    output[31:0] y
);

genvar i;
generate
for(i = 0; i < 32; i = i + 1)
assign {x[i],y[i]} = a[i]+b[i]+c[i];
endgenerate

endmodule

module calc_mul(
    input[15:0]  a,
    input[15:0]  b,
    input[2:0]   m,
    input        EN,
    output[31:0] y
);

wire[16:0] ai;
assign ai = {a,1'b0};

wire[31:0] p[7:0];
wire[31:0] cin;

genvar i;
generate
for(i = 0; i < 8; i = i + 1)
begin
calc_booth enc(
    .a(ai[i*2+2:i*2]),
    .b(b),
    .x(cin[i*2]),
    .y(p[i])
);
assign cin[i*2+1] = 0;
end
endgenerate
assign cin[31:16] = (a[15] && m[1] ? b : 0) + (b[15] && m[0] ? a : 0);

wire[31:0] c[5:0];
wire[31:0] s[5:0];
wire[31:0] u, v;

calc_addtree csa_0(.a(p[0]),    .b(p[1]<<2), .c(p[2]<<4), .x(c[0]),.y(s[0]));
calc_addtree csa_1(.a(p[3]<<6), .b(p[4]<<8), .c(p[5]<<10),.x(c[1]),.y(s[1]));
calc_addtree csa_2(.a(p[6]<<12),.b(p[7]<<14),.c(cin),     .x(c[2]),.y(s[2]));
calc_addtree csa_3(.a(s[0]),    .b(s[1]),    .c(c[2]<<1), .x(c[3]),.y(s[3]));
calc_addtree csa_4(.a(c[0]<<1), .b(c[1]<<1), .c(s[2]),    .x(c[4]),.y(s[4]));
calc_addtree csa_5(.a(s[3]),    .b(s[4]),    .c(c[4]<<1), .x(c[5]),.y(s[5]));
calc_addtree csa_6(.a(s[5]),    .b(c[3]<<1), .c(c[5]<<1), .x(u),   .y(v));

wire[31:0] yi = EN ? (u << 1) + v : 0;
assign y = m[2] ? {16'h0, yi[31:16]} : yi;

endmodule

module calc_clz(
    input[15:0]  a,
    output[15:0] y
);

wire[3:0] ai;
wire[7:0] z;
genvar i;
generate
for (i = 0; i < 4; i = i + 1)
begin
    assign ai[i    ] = ~|a[i*4+3:i*4];
    assign  z[i*2+1] = ~(a[i*4+3]|a[i*4+2]);
    assign  z[i*2  ] = ~((~a[i*4+2]&a[i*4+1])|a[i*4+3]);
end
endgenerate

assign y =  ai[3] ? (
            ai[2] ? (
            ai[1] ? (
            ai[0] ? 16'h0010
                 : {14'h0003, z[1:0]})
                 : {14'h0002, z[3:2]})
                 : {14'h0001, z[5:4]})
                 : {14'h0000, z[7:6]};

endmodule

module calc_revbit(
    input[15:0]  a,
    output[15:0] y
);

genvar i;
generate
for (i = 0; i < 16; i = i + 1)
begin
    assign y[i] = a[15-i];
end
endgenerate

endmodule

module calc_bitfield(
    input[15:0]  a,
    input[15:0]  b,
    input        c, //c ? BFX : BFI
    output[15:0] y
);

wire[3:0] shift = b[3:0];
wire[3:0] range = b[11:8]; //range+1 bits mask

wire[15:0] s = 1 << ((c ? shift : 0) + range); //e.g. 0010 0000

wire[15:0] mask = (-s) ^ s;                    //e.g. 1100 0000
wire[15:0] sext = {16{|(s & a) & b[12]}};      //e.g. 1111 1111

wire[15:0] ai = (a & ~mask) | (mask & sext);

assign y = c ? $signed(ai) >> shift : $signed(ai) << shift;

endmodule

module calc_minmax(
    input[15:0]  a,
    input[15:0]  b,
    input[1:0]   c,
    output reg[15:0] y
);

always @(*)
begin
    case(c)
    `FLAG_MIN:  y <= $signed(a) < $signed(b) ? a : b;
    `FLAG_MAX:  y <= $signed(a) < $signed(b) ? b : a;
    `FLAG_MINU: y <= a < b ? a : b;
    `FLAG_MAXU: y <= a < b ? b : a;
    endcase
end

endmodule

module calc_pack(
    input[15:0]  a,
    input[15:0]  b,
    input[3:0]   c,
    output[15:0] y
);

wire[15:0] mask; //c bits mask
genvar i;
generate
for (i = 0; i < 16; i = i + 1)
begin
    assign mask[i] = c > i;
end
endgenerate

assign y = (a << c) | (b & mask);

endmodule

module calc_arith(
    input[15:0] A,
    input[15:0] B,

    input[3:0] S,
    input      CTL,
    input[2:0] MODE,

    input EN,
    output reg[31:0] C
);

reg[15:0] Ai;
wire[3:0] Si = CTL && !MODE[0] ? B[3:0] : S;
always @(*)
begin
    case(MODE[2:1])
    `TAG_SLL: Ai <= A << Si;
    `TAG_SRL: Ai <= A >> Si;
    `TAG_SRA: Ai <= $signed($signed(A) >>> Si);
    `TAG_SRR: Ai <= {A, A} >> Si;
    default:  Ai <= A;
    endcase
end

wire[15:0] Bi = CTL && !MODE[0] ? 0 : B;
always @(*)
begin
    if(!EN)    begin C[31:16] <= 0;      C[15:0] <= 0;                          end
    else
    case(CTL ? 0 : MODE)
    `TAG_ADD:  begin C[31:16] <= 16'hx;  C[15:0] <= Ai + Bi;                    end
    `TAG_SUB:  begin C[31:16] <= 16'hx;  C[15:0] <= Ai - Bi;                    end
    `TAG_SLT:  begin C[31:16] <= 16'hx;  C[15:0] <= $signed(Ai) < $signed(Bi) ? 1 : 0; end
    `TAG_SLTU: begin C[31:16] <= 16'hx;  C[15:0] <= Ai < Bi ? 1 : 0;            end
    `TAG_MOVZ: begin C[31:16] <= 16'hx;  C[15:0] <= Bi;                         end
    `TAG_MOVN: begin C[31:16] <= 16'hx;  C[15:0] <= Bi;                         end
    default:   begin C[31:16] <= 32'hx; end
    //TODO
    //`TAG_ADD32:  begin C[31:17] <= 15'b0;  C[16:0] <= {1'b0, Ai} + {1'b0, Bi};  end
    //`TAG_SUB32:  begin C[31:17] <= 15'b0;  C[16:0] <= {1'b1, Ai} - {1'b0, Bi};  end
    endcase
end
endmodule

module calc_logic(
    input[15:0] A,
    input[15:0] B,

    input[2:0] MODE,

    input EN,
    output reg[31:0] C
);

always @(*)
begin
    C[31:16] <= 16'h0;
    if(!EN)    begin C[15:0] <= 0;          end
    else
    case(MODE)
    `TAG_OR:   begin C[15:0] <= A | B;      end
    `TAG_AND:  begin C[15:0] <= A & B;      end
    `TAG_XOR:  begin C[15:0] <= A ^ B;      end
    `TAG_ORN:  begin C[15:0] <= A | ~B;     end
    `TAG_ANDN: begin C[15:0] <= A & ~B;     end
    `TAG_XNOR: begin C[15:0] <= A ^ ~B;     end
    default:   begin C[15:0] <= 16'hx;      end
    endcase
end
endmodule

module calc_bitman(
    input[15:0] A,
    input[15:0] B,

    input[6:0] S,
    input[2:0] MODE,

    input EN,
    output reg[31:0] C
);

wire[15:0] Y1, Y2, Y3, Y4, Y5;
calc_revbit sfu1(
    .a(A),
    .y(Y1)
);
calc_clz sfu2(
    .a(A),
    .y(Y2)
);
calc_bitfield sfu3(
    .a(A),
    .b(B),
    .c(MODE[1]),
    .y(Y3)
);
calc_minmax sfu4(
    .a(A),
    .b(B),
    .c(S[1:0]),
    .y(Y4)
);
calc_pack sfu5(
    .a(A),
    .b(B),
    .c(S[3:0]),
    .y(Y5)
);

always @(*)
begin
    C[31:16] <= 16'h0;
    if(!EN)    begin C[15:0] <= 0;      end
    else
    case(MODE)
    `TAG_REV:  begin C[15:0] <= Y1;     end
    `TAG_CLZ:  begin C[15:0] <= Y2;     end
    `TAG_BFI:  begin C[15:0] <= Y3;     end
    `TAG_BFX:  begin C[15:0] <= Y3;     end
    `TAG_CMP:  begin C[15:0] <= Y4;     end
    `TAG_PACK: begin C[15:0] <= Y5;     end
    `TAG_TBE:  begin C[15:0] <= {A[15:8] == B[15:8] ? 8'h0 : 8'hff, A[7:0] == B[7:0] ? 8'h0 : 8'hff}; end
    default:   begin C[15:0] <= 16'hx;  end
    endcase
end
endmodule
