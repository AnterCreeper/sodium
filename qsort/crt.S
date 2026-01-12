    .section .vector,"ax",@progbits
    .globl	_start
    .weak	_syscall
    .weak	_trap
    .weak	_unimp
    .weak	_irq
    .align	2
_vector_base:
_start:
	b	_init	#software interrupt
	b	_syscall
	b	_trap
	b	_unimp
	ebreak
	ebreak
	ebreak
	ebreak
	ebreak
	ebreak
	ebreak
	ebreak
	ebreak
	ebreak
	ebreak
	ebreak
	ebreak
	ebreak
	ebreak
	ebreak
	ebreak
	ebreak
	ebreak
	ebreak
	ebreak
	ebreak
	ebreak
	ebreak
	ebreak
	ebreak
	ebreak
	ebreak
	b	_irq	#hardware interrupt
	ebreak
	ebreak
	ebreak
	ebreak
	ebreak
	ebreak
	ebreak
	ebreak
	ebreak
	ebreak
	ebreak
	ebreak
	ebreak
	ebreak
	ebreak
	ebreak
	ebreak
	ebreak
	ebreak
	ebreak
	ebreak
	ebreak
	ebreak
	ebreak
	ebreak
	ebreak
	ebreak
	ebreak
	ebreak
	ebreak
	ebreak
_syscall:
_trap:
_unimp:
_irq:
1:
    b     1b

    .section .text.init,"ax",@progbits
    .weak	_init
    .align	2
_init:
    add.i x1, zero, 0
    add.i x2, zero, 0
    add.i x3, zero, 0
    add.i x4, zero, 0
    add.i x5, zero, 0
    add.i x6, zero, 0
    add.i x7, zero, 0
    add.i x8, zero, 0
    add.i x9, zero, 0
    add.i x10, zero, 0
    add.i x11, zero, 0
    add.i x12, zero, 0
    add.i x13, zero, 0
    add.i x14, zero, 0
    add.i x15, zero, 0
    add.i x16, zero, 0
    add.i x17, zero, 0
    add.i x18, zero, 0
    add.i x19, zero, 0
    add.i x20, zero, 0
    add.i x21, zero, 0
    add.i x22, zero, 0
    add.i x23, zero, 0
    add.i x24, zero, 0
    add.i x25, zero, 0
    add.i x26, zero, 0
    add.i x27, zero, 0
    add.i x28, zero, 0
    add.i x29, zero, 0
    add.i x30, zero, 0
    add.i x31, zero, 0	# reset register bank

.Lpcrel_hi0:
    pcadd12i  t0, %pcrel_hi12(_vector_base)
    add.i t0, t0, %pcrel_lo(.Lpcrel_hi0)
    li    t1, 0
    wcsr.d  mvec, t0	# set interrupt vector

						# write memory phy csr
    li    t0,   466     # {10'd7, 4'd4, 2'd2};
    wcsr  mcr0, t0
    li    t0,   3848    # {8'd15, 8'd8};
    wcsr  mcr1, t0
						# enable memory
    li    t0,   1       # {1'b0, 1'b1};
    wcsr  mcr2, t0

    li    sp,   0x1f00  # setup stack pointer

    li    t0,   0xffff
    li    t1,   0xffff
    wcsr.d  0x3, t0     # clear mask
    li    t0,   0x1
    wcsr  msta, t0      # set interrupt enable

    jmp   main			# goto main
