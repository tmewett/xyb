# we have to have the main object file assembled at the top of the final rom
MAIN := main_test.asm
ASMS := $(MAIN) $(shell find -iname '*.asm' ! -iname 'main*')
OBJS := $(addsuffix .o,$(basename $(ASMS)))

all: rom1

rom1: $(OBJS)
	ld65 -t none --start-addr 0xE000 -o $@ $^

%.o: %.asm common.inc
	ca65 -t none --auto-import -o $@ $<
