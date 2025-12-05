# CoreMark for Sodium

### Overview
CoreMark Sodium16 baremetal porting  
- software divmod
- ee_printf(), clock(), memcpy() and memset()

A compiled linux-amd64 version(coremark.exe) is included for debug and validate purpose.

### Performance Analysis
- Flag:             -fPIC -O2
- Dataset:          seed1=0, seed2=0, seed3=0x66, size=666
- Iterations:       1
- Total ticks:      0x9e1e5
- D$ miss:          0x12757     (11.7%)
- Hazard stall:     0xbddb      ( 7.5%)
- ALU issue:        0x471ad     (45.0%)
- LSU issue:        0x234de     (22.3%)
- Branch issue:     0x10900     (10.5%)
- Others:                       ( 3.0%)

- Coremark Score/MHz: 
                    1.54        iters*mega/ticks
