TARGET ?= xyb
SRC_DIRS ?= .

SRCS := $(shell find $(SRC_DIRS) -name \*.cpp -or -name \*.c -or -name \*.s)
OBJS := $(addsuffix .o,$(basename $(SRCS)))
DEPS := $(OBJS:.o=.d)

INC_DIRS := .
INC_FLAGS := $(addprefix -I,$(INC_DIRS))

CFLAGS := $(shell sdl2-config --cflags) -g -DDEBUG
CPPFLAGS ?= $(INC_FLAGS) -MMD -MP
LDLIBS := $(shell sdl2-config --libs)

$(TARGET): $(OBJS)
	$(CC) $(LDFLAGS) $(OBJS) -o $@ $(LOADLIBES) $(LDLIBS)

%.o65: %.asm
	xa -bt 57344 $< -o $@

chars.gray: codepage.png
	convert $< -depth 1 $@

.PHONY: clean
clean:
	$(RM) $(TARGET) $(OBJS) $(DEPS)

-include $(DEPS)
