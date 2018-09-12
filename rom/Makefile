# we have to have the main object file assembled at the top of the final rom
MAIN := main_test.asm
ASMS := $(MAIN) $(shell find -iname '*.asm' ! -iname 'main*')
OBJS := $(addsuffix .o,$(basename $(ASMS)))

rom: $(OBJS)
	cl65 -t none --start-addr 0xE000 -o rom $^

%.o: %.asm
	ca65 -t none --auto-import -o $@ $<
