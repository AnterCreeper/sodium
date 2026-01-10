`include "defines.v"

module icache_mem(
    input           CLK,
    input           CEN,
    input[29:0]     A,
    output[31:0]    Q
);

reg[31:0]  mem[16383:0];
`ifdef DEBUG
integer fd;
initial
begin
    fd = $fopen(`DEBUG_RAMFILE, "rb");
    $fread(mem, fd);
end
`endif

reg[13:0]  addr;
always @(posedge CLK)
begin
    if(!CEN) addr <= A;
end

wire[31:0] data = mem[addr];
assign Q = {data[7:0], data[15:8], data[23:16], data[31:24]};

endmodule

module mp_icache(
    input        sys_clk,
    input        icache_rst,
    input        icache_req,
    input[31:0]  icache_addr,
    output reg   icache_vld,
    output[31:0] icache_data
);

always @(posedge sys_clk or posedge icache_rst)
begin
    if(icache_rst) icache_vld <= 0;
    else        icache_vld <= icache_vld || icache_req;
end

icache_mem mem(
    .CLK    (sys_clk),
    .CEN    (~icache_req),
    .A      (icache_addr[31:2]),
    .Q      (icache_data)
);

endmodule
