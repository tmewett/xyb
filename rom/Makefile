# we have to have the main object file assembled at the top of the final rom
MAIN := main_test.asm
ASMS := jumptable.asm $(MAIN) io.asm core.asm
OBJS := $(ASMS:.asm=.o)

all: rom1 rom2

rom1: $(OBJS)
	ld65 -t none --start-addr 0xE000 -o $@ $^

rom2: forth.fth assembler.fth tests.fth words.fth
	gforth $<

%.o: %.asm common.inc
	ca65 -t none --auto-import -o $@ $<
