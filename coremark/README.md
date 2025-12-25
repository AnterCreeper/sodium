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
|:------------:|------:|---:|---:|
| Branch |   10.5% | 10.5% | 11.2% |
| ALU |      45.2% | 45.0% | 46.5% |
| Memory   | 20.9% | 21.0% | 20.7% |
| Hazard   |  8.0% |  8.0% |  7.7% |
| D$ stall | 12.2% | 12.3% | 10.6% |
| Others   |  3.2% |  3.2% |  3.3% |
| Tick     | 0xaa6ae | 0xabfc0 | 0xaf2db |

with -sodium-pair-spillrestore:
| Perf Counter | Ofast | O2 | Os |
|:------------:|------:|---:|---:|
| Branch |   10.7% | 10.1% | 11.5% |
| ALU |      45.9% | 43.3% | 47.7% |
| Memory   | 19.3% | 18.3% | 19.1% |
| Hazard   |  8.1% |  7.7% |  7.9% |
| D$ stall | 12.7% | 17.5% | 10.4% |
| Others   |  3.3% |  3.1% |  3.3% |
| Tick     | 0xa7de5 | 0xb2def | 0xaaf53 |