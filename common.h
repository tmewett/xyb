#define CPUFREQ 1000000
#define CLUMPSIZE (CPUFREQ/100) // no. of cpu ticks to do between processing
#define DRAWTICKS (CPUFREQ/30) // minimum no. of cpu ticks before redraw
#define EVENTTICKS (CPUFREQ/60) // minimum no. of cpu ticks before redraw

#define read6502(addr) read8((addr))
#define write6502(addr, val) write8((addr), (val))
uint8_t read8(uint16_t address);
void write8(uint16_t address, uint8_t value);
void reset6502();
void exec6502();
extern uint32_t clockticks6502;
extern uint32_t lasttimer[2];

int handleevents();
void drawscreen();
int updatetimer(int n);
