# CoreMark for Sodium

### Overview
CoreMark Sodium16 baremetal porting
- software divmod
- ee_printf(), clock(), memcpy() and memset()

A compiled linux-amd64 version(coremark.exe) is included for debug and validate purpose.

### Result
- Flag:             -fPIC -Ofast
- Dataset:          seed1=0, seed2=0, seed3=0x66, size=666
- Iterations:       1
- Clock freq:       200     MHz
- Total ticks:      0x9c664 Cycle
- Coremark Score/MHz:
                    1.56    iters*mega/ticks

### Perf Counter
without -sodium-pair-spillrestore:
| Perf Counter | Ofast | O2 | Os |
|:============:|======:|===:|===:|
| Branch |   0x11e35 | 0x1214a | 0x139c5 |
| ALU |      0x4d094 | 0x4d678 | 0x51853 |
| Memory   | 0x23966 | 0x2417f | 0x24362 |
| Hazard   |  0xda22 |  0xdb70 |  0xd8ed |
| D$ stall | 0x14c94 | 0x1526a | 0x12926 |
| Total    | 0xaa6ae | 0xabfc0 | 0xaf2db |

with -sodium-pair-spillrestore:
| Perf Counter | Ofast | O2 | Os |
|:============:|======:|===:|===:|
| Branch |   0x11e35 | 0x1214c | 0x139c3 |
| ALU |      0x4d094 | 0x4d6a1 | 0x5182a |
| Memory   | 0x20758 | 0x20c01 | 0x20bca |
| Hazard   |  0xda22 |  0xdb71 |  0xd8ec |
| D$ stall | 0x155d9 | 0x1f5eb | 0x11d62 |
| Total    | 0xa7de5 | 0xb2def | 0xaaf53 |