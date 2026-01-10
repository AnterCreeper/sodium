`include "defines.v"

`define N       5

`define WIDTHX  (2*`N+1)
`define WIDTHY  `N

module pic_sort_cas
#(
    parameter A = 0,
    parameter B = 0
)(
    input       clk,
    input       rst_n,
    //input       vld_in,
    //output reg  vld_out,
    input[(2**`N)*`WIDTHX-1:0]       a,
    input[(2**`N)*`WIDTHY-1:0]       b,
    output reg[(2**`N)*`WIDTHX-1:0]  x,
    output reg[(2**`N)*`WIDTHY-1:0]  y
);

/*
always @(posedge clk or negedge rst_n)
begin
    if(!rst_n) vld_out <= 0;
    else vld_out <= vld_in;
end
*/

localparam INC = 2**B;
localparam SEG = 2**(`N-A-1);
localparam CNT = 2**(A-B);
localparam LEN = 2**(A+1);

genvar i, j, k;
generate
for(i = 0; i < SEG; i = i + 1)
for(j = 0; j < CNT; j = j + 1)
for(k = 0; k < INC; k = k + 1)
begin
    localparam m = i*LEN+2*j*INC+k;
    localparam n = i*LEN+2*j*INC+k+INC;
    wire[`WIDTHX-1:0] u = a[m*`WIDTHX+`WIDTHX-1:m*`WIDTHX];
    wire[`WIDTHX-1:0] v = a[n*`WIDTHX+`WIDTHX-1:n*`WIDTHX];
    wire[`WIDTHY-1:0] s = b[m*`WIDTHY+`WIDTHY-1:m*`WIDTHY];
    wire[`WIDTHY-1:0] t = b[n*`WIDTHY+`WIDTHY-1:n*`WIDTHY];
    if(i%2)
    always @(posedge clk)
    begin
        x[m*`WIDTHX+`WIDTHX-1:m*`WIDTHX] <= u > v ? u : v;
        x[n*`WIDTHX+`WIDTHX-1:n*`WIDTHX] <= u > v ? v : u;
        y[m*`WIDTHY+`WIDTHY-1:m*`WIDTHY] <= u > v ? s : t;
        y[n*`WIDTHY+`WIDTHY-1:n*`WIDTHY] <= u > v ? t : s;
    end else
    always @(posedge clk)
    begin
        x[m*`WIDTHX+`WIDTHX-1:m*`WIDTHX] <= u > v ? v : u;
        x[n*`WIDTHX+`WIDTHX-1:n*`WIDTHX] <= u > v ? u : v;
        y[m*`WIDTHY+`WIDTHY-1:m*`WIDTHY] <= u > v ? t : s;
        y[n*`WIDTHY+`WIDTHY-1:n*`WIDTHY] <= u > v ? s : t;
    end
end
endgenerate
endmodule

module pic_sort(
    input   clk,
    input   rst_n,
    //input   vld_in,
    //output  vld_out,
    input[(2**`N)*`WIDTHX-1:0]  a,
    input[(2**`N)*`WIDTHY-1:0]  b,
    output[(2**`N)*`WIDTHX-1:0] x,
    output[(2**`N)*`WIDTHY-1:0] y
);

parameter STAGE = `N*(`N+1)/2;

//wire vld[STAGE:0];
//assign vld_out = vld[STAGE];

wire[(2**`N)*`WIDTHX-1:0] xi[STAGE:0];
wire[(2**`N)*`WIDTHY-1:0] yi[STAGE:0];

assign x = xi[STAGE];
assign y = yi[STAGE];

genvar i, j;
generate
for(i = 0; i < `N; i = i + 1)
begin
    for(j = i; j >= 0; j = j - 1)
    begin
    localparam k = i*(i+1)/2+i-j;
    pic_sort_cas #(i, j) cas(
        .clk    (clk),
        .rst_n  (rst_n),
        //.vld_in (k == 0 ? vld_in : vld[k]),
        .a      (k == 0 ? a : xi[k]),
        .b      (k == 0 ? b : yi[k]),
        //.vld_out(vld[k+1]),
        .x      (xi[k+1]),
        .y      (yi[k+1])
    );
    end
end
endgenerate
endmodule

module pic_core(
    input            clk,
    input            rst,

    input[31:0]      irq,
    output           exi,
    output[4:0]      exi_code,

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

reg rwn;
reg wen;

reg[31:0]   cfg_cmd;
reg[31:0]   cfg_din;
wire[31:0]  cfg_dout;

always @(posedge clk)
begin
    rwn     <= mgmt_rwn;
    wen     <= mgmt_wen[0];
    cfg_cmd <= mgmt_adr;
    cfg_din <= mgmt_txd;
end

wire vld = issue && ((cfg_cmd & `MASK_IRQ) == `ADDR_IRQ);

always @(posedge clk or posedge rst)
begin
    if(rst)
    begin
        mgmt_fin <= 0;
        mgmt_ack <= 0;
    end else
    begin
        mgmt_fin <= issue;
        mgmt_ack <= vld;
    end
end

always @(posedge clk or posedge rst)
begin
    if(rst)
    begin
        mgmt_rxe <= 0;
    end else
    begin
        mgmt_rxe <= vld && rwn;
        mgmt_rxd <= vld ? cfg_dout : 0;
    end
end

reg          mvld[(2**`N)-1:0];
reg[`N-1:0]  mcnt[(2**`N)-1:0];
wire[`N-1:0] mpri[(2**`N)-1:0];

genvar i;
generate
for(i = 0; i < 2**`N; i = i + 1)
always @(posedge clk)
begin
    mvld[i] <= !irq[i];
    mcnt[i] <= mcnt[i] + (mvld[i] && irq[i] ? 1 : 0);
end
endgenerate

//bitonic sorting, result's LSB is the minimum number
wire[(2**`N)*`WIDTHX-1:0] prio;
wire[(2**`N)*`WIDTHY-1:0] line;
genvar j;
generate
for(j = 0; j < 2**`N; j = j + 1)
begin
assign prio[j*`WIDTHX+:`WIDTHX] = {mvld[j], mpri[j], mcnt[j]};
assign line[j*`WIDTHY+:`WIDTHY] = j;
end
endgenerate

wire[(2**`N)*`WIDTHX-1:0] exi_prior;
wire[(2**`N)*`WIDTHY-1:0] exi_lines;
pic_sort sort(
    .clk    (clk),
    .rst_n  (!rst),
    .a      (prio),
    .b      (line),
    .x      (exi_prior),
    .y      (exi_lines)
);

//Regmap DFF File
wire[`N*(2**`N)-1:0] _mpri;
`UNPK_ARRAY(`N, (2**`N), mpri, _mpri)
dffs_sp #(`N, `N) //(2**N)xN DFFs with mask
priority(
    .CLK(clk),
    .CEN(~vld),
    .WEN(~wen),
    .A(cfg_cmd[`N-1:0]),
    .D(cfg_din[`N-1:0]),
    .Q(cfg_dout[`N-1:0]),
    .DFF(_mpri)
);
assign cfg_dout[31:`N] = 0;

//external interrupt output
assign exi      = !exi_prior[`WIDTHX-1];
assign exi_code = exi_lines[`WIDTHY-1:0];

endmodule
