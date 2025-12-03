`include "defines.v"

`define SIM_MEM_DELAY   15

module sim_memory_dynamic(
    input           sys_clk,
    input           mem_dump,
    input           mem_request,
    output reg      mem_finish,
    output reg      mem_partial,
    input           mem_rwn,
    input[15:0]     mem_addr,
    input[15:0]     mem_commit,
    input[127:0]    mem_write_data,
    output reg      mem_replace,
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

reg        worker_valid;
reg[127:0] worker_data;
reg[3:0]   worker_burst;
reg[11:0]  worker_address;
reg[15:0]  worker_finish;

/* LFB address(old replace in) is ready, implicit that new request is not hit */
wire worker_oldready = mem_read_request && worker_valid && worker_address != mem_addr[15:4] && worker_finish == 16'hffff;

/* LFB address(old replace in) collision with new replace in address(both located at same set) */
wire worker_collision = worker_oldready && worker_address[4:0] == mem_addr[8:4];

initial mem_finish   = 0;
initial mem_partial  = 0;
initial mem_replace  = 0;
initial worker_valid = 0;

integer m, n;
always @(posedge sys_clk)   /*mem_finish, mem_partial, mem_replace, worker_valid, worker_address*/
begin
    if(mem_finish)
    begin
        mem_finish  <= 0;
        mem_partial <= 0;
        mem_replace <= 0;
    end else
    begin
        if(mem_write_request)                                       //Replace out, directly write to memory
        begin
            for(m = 0; m < 16; m = m + 1)
                mem[{mem_addr[15:4],4'b0}+m] <= mem_write_data[m*8+:8];

            mem_finish  <= 1;
            mem_partial <= 0;
            mem_replace <= 0;
        end
        if(mem_read_request)                                        //Replace in
        begin
            if(worker_collision)                                    //Writeback data if collision
            for(m = 0; m < 16; m = m + 1)
                mem[{worker_address,4'b0}+m] <= worker_data[m*8+:8];

            if(!worker_valid)                                       //Empty LFB, run job instantly
            begin
                mem_finish  <= 0;
                mem_partial <= 0;
                mem_replace <= 0;
                worker_valid <= 1;                                      //issue new fill task
                worker_address <= mem_addr[15:4];
            end else
            if(worker_oldready)                                          //LFB filled with old data
            begin
                mem_finish  <= 0;
                mem_partial <= 0;
                mem_replace <= !worker_collision;                       //if collision, LFB data will kicked into victim cache and won't be replaced in
                worker_valid <= 1;                                      //issue new fill task
                worker_address <= mem_addr[15:4];
            end else
            if(worker_valid && worker_address == mem_addr[15:4])    //Request address hit LFB
            begin
                mem_finish  <= worker_finish[mem_addr[3:0]];            //wait for request address reached
                mem_partial <= worker_finish[mem_addr[3:0]] && worker_finish != 16'hffff;
                                                                        //if line is full
                mem_replace <= worker_finish[mem_addr[3:0]];
                worker_valid <= worker_finish != 16'hffff;              //reset valid flag, as data will be replaced in L1$
            end else                                                //Request address is not equal to LFB address, and LFB is busy. Wait for LFB finish.
            begin
                mem_finish  <= 0;
                mem_partial <= 0;
                mem_replace <= 0;
            end
        end
    end
end

reg[127:0]  _mem_replace_dat;
reg[4:0]    _mem_replace_set;
reg[6:0]    _mem_replace_tag;
assign mem_replace_dat = _mem_replace_dat;
assign mem_replace_set = _mem_replace_set;
assign mem_replace_tag = _mem_replace_tag;
always @(posedge sys_clk)
begin
    _mem_replace_dat <= worker_data;
    _mem_replace_set <= worker_address[4:0];
    _mem_replace_tag <= worker_address[11:5];
end

initial worker_finish = 0;

always @(posedge sys_clk)   /*worker_data, worker_finish, worker_burst*/
begin
    if((worker_oldready || !worker_valid) && mem_read_request)      //Reset workset state
    begin
        cnt <= `SIM_MEM_DELAY;
        worker_burst <= mem_addr[3:0];
        worker_finish = mem_commit;
        for(n = 0; n < 16; n = n + 1)
            worker_data[n*8+:8] <= mem_commit[n] ? mem_write_data[n*8+:8] : mem[{mem_addr[15:4],4'b0}+n];
    end else
    if(worker_valid)                                                //Running Delay Model
    begin
        if(worker_address == mem_addr[15:4])                            //first
        begin
            worker_finish = worker_finish | mem_commit;
            for(n = 0; n < 16; n = n + 1)
                worker_data[n*8+:8] <= mem_commit[n] ? mem_write_data[n*8+:8] : worker_data[n*8+:8];
        end
        if(worker_finish != 16'hffff)                                   //second
        begin
            if(cnt != 0) cnt = cnt - 1;
            else
            begin
                worker_burst <= worker_burst + 1;                       //DDR, 2 bytes per cycle
                worker_finish[worker_burst]   = 1;
                //worker_finish[worker_burst+1] = 1;
            end
        end
    end
end

endmodule
