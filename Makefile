.DEFAULT_GOAL = nothing

nothing:

all: checkout_submodules machines tools

checkout_submodules:
	git submodule update --init --recursive

machines:
	make -C machines/

tools:
	make -C software/riscv-tools checkout-all
	make -C software/riscv-tools build-all

build:
	make -C machines/ clean 4x4_hammerblade/simv-debug

include ../bsg_cadenv/cadenv.mk

binary:
	make -C ~/scratch/pre-alpha-release/bp_common/test bp_tests_manual
	cp ~/scratch/pre-alpha-release/bp_common/test/mem/bp_tests/manycore_poke.riscv .
	~/scratch/pre-alpha-release/external/bin/riscv64-unknown-elf-dramfs-objcopy -O verilog manycore_poke.riscv manycore_poke.mem
	~/scratch/pre-alpha-release/external/bin/riscv64-unknown-elf-dramfs-objdump -d manycore_poke.riscv > manycore_poke.dump


sim:
	./machines/4x4_hammerblade/simv-debug

wave:
	dve -full64 -vpd vcdplus.vpd &
