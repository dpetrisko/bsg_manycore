BENCHMARKS = 000.plain
BENCHMARKS+= 000.test
#BENCHMARKS+= 164.gzip
BENCHMARKS+= 175.vpr
#BENCHMARKS+=186.crafty
BENCHMARKS+= 181.mcf

RUNS = $(patsubst %,%.run,$(BENCHMARKS))

all: $(RUNS)

%.run:
	make -f Makefile.$*
	make -f Makefile.$* clean

clean:
	for benchmark in $(BENCHMARKS) ; do \
	make -f Makefile.$$benchmark clean; \
	done;
