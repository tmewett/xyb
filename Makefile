cflags := $(shell sdl2-config --cflags)
libs := $(shell sdl2-config --libs)

ifeq ($(DEBUG),YES)
	cflags += -g
	cppflags += -DDEBUG
else
	cflags += -O2
endif

%.o: %.c
	$(CC) $(cppflags) $(CPPFLAGS) $(cflags) $(CFLAGS) -c $< -o $@

xyb: main.o fake6502.o
	$(CC) $(cflags) $(CFLAGS) $^ $(libs) $(LDFLAGS) -o $@

chars.gray: codepage.png
	convert $< -depth 1 $@

.PHONY: clean
clean:
	$(RM) *.o xyb
