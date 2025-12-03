`include "defines.v"

`define SIM_MEM_DELAY   23

module sim_memory_generic(
    input           sys_clk,
    input           mem_dump,
    input           mem_request,
    output reg      mem_finish,
    output          mem_partial,
    input           mem_rwn,
    input[15:0]     mem_addr,
    input[15:0]     mem_commit,
    input[127:0]    mem_write_data,
    output          mem_replace,
    output[4:0]     mem_replace_set,
    output[6:0]     mem_replace_tag,
    output[127:0]   mem_replace_dat
);

reg[7:0] mem[65535:0];

integer fd, i;
initial
begin
    for(i = 0; i < 65536; i = i + 1) mem[i] = 0;
`ifdef DEBUG_SEPERATE_DATA
    $readmemh(`DEBUG_DATA_TXT, mem);
`else
    fd = $fopen(`DEBUG_RAMFILE, "rb");
    $fread(mem, fd);
    $fclose(fd);
`endif
end

always @(posedge mem_dump)
begin
`ifdef DEBUG_DUMP
    fd = $fopen(`DEBUG_RESULT, "wb");
    for(i = `DEBUG_DUMP_LO; i < `DEBUG_DUMP_HI; i = i + 1) $fwrite(fd, "%c", mem[i]);
    $fclose(fd);
`endif
    $stop;
end

integer cnt;
initial cnt = `SIM_MEM_DELAY;

wire mem_read_request, mem_write_request;
assign mem_read_request  = mem_request &&  mem_rwn;
assign mem_write_request = mem_request && !mem_rwn;

assign mem_partial = 0;
assign mem_replace = mem_finish && mem_rwn;
assign mem_replace_set = mem_addr[8:4];
assign mem_replace_tag = mem_addr[15:9];

initial mem_finish = 0;

wire[15:0] mem_addr_line = {mem_addr[15:4], 4'b0};
reg[127:0] mem_read_data;
assign mem_replace_dat = mem_read_data;

integer m, n;
always @(posedge sys_clk)
begin
    if(mem_finish)
    begin
        mem_finish <= 0;
        cnt <= `SIM_MEM_DELAY;
    end else
    if(mem_request)
    begin
        if(cnt != 0) cnt <= cnt - 1;
        else
        begin
            if(mem_write_request)
                for(m = 0; m < 16; m = m + 1)
                mem[mem_addr_line+m] <= mem_write_data[m*8+:8];
            if(mem_read_request)
                for(n = 0; n < 16; n = n + 1)
                mem_read_data[n*8+:8] <= mem[mem_addr_line+n];
            mem_finish <= 1;
        end
    end
end

endmodule
