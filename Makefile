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

sim:
	./machines/4x4_hammerblade/simv-debug

wave:
	dve -full64 -vpd vcdplus.vpd &
