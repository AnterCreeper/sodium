`define MIN(a, b) ((a)<(b)?(a):(b))

`define PACK_ARRAY(PK_WIDTH, PK_LEN, PK_DEST, PK_SRC) \
genvar pk_idx; \
generate \
for(pk_idx = 0; pk_idx < (PK_LEN); pk_idx = pk_idx + 1) \
begin \
    assign PK_DEST[pk_idx*(PK_WIDTH)+:(PK_WIDTH)] = PK_SRC[pk_idx][((PK_WIDTH)-1):0]; \
end \
endgenerate

`define UNPK_ARRAY(PK_WIDTH, PK_LEN, PK_DEST, PK_SRC) \
genvar unpk_idx; \
generate \
for(unpk_idx = 0; unpk_idx < (PK_LEN); unpk_idx = unpk_idx + 1) \
begin \
    assign PK_DEST[unpk_idx][(PK_WIDTH)-1:0] = PK_SRC[unpk_idx*(PK_WIDTH)+:(PK_WIDTH)]; \
end \
endgenerate
