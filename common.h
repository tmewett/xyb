#include <stdint.h>

#define TILEW 8
#define TILEH 8
#define SCREENW 32
#define SCREENH 24
#define BORDERW 3
#define WINDOWW TILEW*(SCREENW+2*BORDERW)
#define WINDOWH TILEH*(SCREENH+2*BORDERW)

//~ #define read6502(addr) mem[addr]
//~ #define write6502(addr, val) mem[addr] = (val)
uint8_t read6502(uint16_t address);
void write6502(uint16_t address, uint8_t value);
void reset6502();
void step6502();
void exec6502(uint32_t);
extern uint32_t clockticks6502;

extern uint8_t mem[];

//~ void reset6502();
