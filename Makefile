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
	make -C machines/ clean 4x4_hammerblade/simv-debug | tee build.log

include ../bsg_cadenv/cadenv.mk

binary:
	make -C machines/4x4_hammerblade/black-parrot/bp_common/test bp_tests_manual
	cp machines/4x4_hammerblade/black-parrot/bp_common/test/mem/bp_tests/manycore_poke.riscv .
	machines/4x4_hammerblade/black-parrot/external/bin/riscv64-unknown-elf-dramfs-objcopy -O verilog manycore_poke.riscv manycore_poke.mem
	machines/4x4_hammerblade/black-parrot/external/bin/riscv64-unknown-elf-dramfs-objdump -d manycore_poke.riscv > manycore_poke.dump
	cp machines/4x4_hammerblade/black-parrot/bp_common/test/mem/bp_tests/manycore_poke_fifo.riscv .
	machines/4x4_hammerblade/black-parrot/external/bin/riscv64-unknown-elf-dramfs-objcopy -O verilog manycore_poke_fifo.riscv manycore_poke_fifo.mem
	machines/4x4_hammerblade/black-parrot/external/bin/riscv64-unknown-elf-dramfs-objdump -d manycore_poke_fifo.riscv > manycore_poke_fifo.dump

sim:
	cp manycore_poke_fifo.mem prog.mem
	./machines/4x4_hammerblade/simv-debug | tee sim.log

wave:
	dve -full64 -vpd vcdplus.vpd &
