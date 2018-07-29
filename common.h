#define TILEW 8
#define TILEH 8
#define SCREENW 32
#define SCREENH 24
#define BORDERW 3
#define WINDOWW TILEW*(SCREENW+2*BORDERW)
#define WINDOWH TILEH*(SCREENH+2*BORDERW)

#define CPUFREQ 1000000
#define CLUMPSIZE (CPUFREQ/100) // no. of cpu ticks to do between throttling
#define DRAWTICKS (CPUFREQ/30) // minimum no. of cpu ticks before redraw

uint8_t read6502(uint16_t address);
void write6502(uint16_t address, uint8_t value);
void reset6502();
void run6502();
extern uint32_t clockticks6502;

int handleevents();
void drawscreen();
