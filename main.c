#include <stdlib.h>
#include <stdio.h>
#include <stdbool.h>
#include <string.h>
#include <time.h>
#include <errno.h>

#include <SDL.h>
#include <SDL_video.h>
#include <SDL_timer.h>
#include <SDL_mouse.h>

#include "common.h"

#define TILEW 8
#define TILEH 8
#define SCREENW 32
#define SCREENH 24
#define BORDERW 3
#define WINDOWW (TILEW*(SCREENW+2*BORDERW))
#define WINDOWH (TILEH*(SCREENH+2*BORDERW))
#define SCALE 3

#define PERIPHSTART 0x0200
#define INPUTLEN 6
#define GFXLEN 3
#define TIMERLEN 6

#define ROMSTART 0xE000
#define CHARSSTART 0xD800 // 0x800=2048 before ROM
#define SCREENSTART 0xD000 // 0x800 before chars

#define MIN(x, y) ((x)<(y)?(x):(y))
#define MAX(x, y) ((x)>(y)?(x):(y))
#define CLAMP(x, xmin, xmax) MIN((xmax), MAX((x), (xmin)))
#define MASKBIT(val, bit) ((val)>>(bit)&1)

#ifdef DEBUG
extern uint16_t pc, status;
#define DBGPRINTF(s, ...) printf((s), __VA_ARGS__)
#define FLAGSTR(mask, s) (status & (mask) ? (s) : "-")
#else
#define DBGPRINTF(...)
#endif

uint8_t mem[1<<16];
SDL_Window *Win;
SDL_Surface *WinSurf;
SDL_Surface *Screen;
uint8_t palette[] = { // pico-8's colours
	0x00, 0x00, 0x00, // R,G,B
	0x5f, 0x57, 0x50,
	0x82, 0x75, 0x9a,
	0xc0, 0xc1, 0xc5,
	0xff, 0xf0, 0xe7,
	0x7d, 0x29, 0x53,
	0xff, 0x07, 0x4e,
	0xff, 0x76, 0xa6,
	0xa9, 0x52, 0x38,
	0xff, 0xa1, 0x08,
	0xfe, 0xeb, 0x2c,
	0xff, 0xca, 0xa8,
	0x00, 0x85, 0x51,
	0x00, 0xe3, 0x39,
	0x22, 0x2e, 0x53,
	0x2c, 0xab, 0xfe
};

SDL_Keycode keygrid[] = {
	SDLK_QUOTE, SDLK_COMMA, SDLK_MINUS, SDLK_PERIOD, SDLK_SLASH,
	SDLK_SEMICOLON, SDLK_EQUALS, SDLK_LEFTBRACKET, SDLK_RIGHTBRACKET,
	SDLK_BACKSLASH, SDLK_BACKQUOTE,
	SDLK_0, SDLK_1, SDLK_2, SDLK_3, SDLK_4, SDLK_5, SDLK_6, SDLK_7,
	SDLK_8, SDLK_9,
	SDLK_a, SDLK_b, SDLK_c, SDLK_d, SDLK_e, SDLK_f, SDLK_g,
	SDLK_h, SDLK_i, SDLK_j, SDLK_k, SDLK_l, SDLK_m, SDLK_n, SDLK_o,
	SDLK_p, SDLK_q, SDLK_r, SDLK_s, SDLK_t, SDLK_u, SDLK_v, SDLK_w,
	SDLK_x, SDLK_y, SDLK_z,
	SDLK_BACKSPACE, SDLK_RETURN, SDLK_LSHIFT, SDLK_LCTRL, SDLK_SPACE
};
#define KEYGRIDSIZE (sizeof(keygrid)/sizeof(SDL_Keycode))

bool keydown[KEYGRIDSIZE];

uint64_t countfreq;
uint32_t asleep = 0;
int frames = 0;


// mousereg - XYLMRCxx
uint8_t kbrow, inputreg, gotchar;

uint8_t inputread(uint16_t reg) {
	if (reg==0) {
		return kbrow;
	} else if (reg==1) {
		uint8_t res = 0;
		for (int i=0; i<8; i++) {
			res |= keydown[kbrow*8+i] << i;
		}
		return res;
	} else if (reg==2) {
		uint32_t state = SDL_GetMouseState(NULL, NULL);
		int buttons = 0;
		if (state & SDL_BUTTON(SDL_BUTTON_LEFT)) buttons |= 1<<5;
		if (state & SDL_BUTTON(SDL_BUTTON_MIDDLE)) buttons |= 1<<4;
		if (state & SDL_BUTTON(SDL_BUTTON_RIGHT)) buttons |= 1<<3;
		return inputreg | buttons;
	} else if (reg==3) {
		signed int x;
		uint32_t state = SDL_GetMouseState(&x, NULL);
		x /= SCALE;
		x = CLAMP(x - TILEW*BORDERW, 0, SCREENW*TILEW-1);
		if (inputreg & 1<<7) x /= TILEW;
		return x;
	} else if (reg==4) {
		signed int y;
		uint32_t state = SDL_GetMouseState(NULL, &y);
		y /= SCALE;
		y = CLAMP(y - TILEH*BORDERW, 0, SCREENH*TILEH-1);
		if (inputreg & 1<<6) y /= TILEH;
		return y;
	} else if (reg==5) {
		uint8_t c = gotchar;
		gotchar = 0;
		return c;
	}
}

void inputwrite(uint16_t reg, uint8_t value) {
	if (reg==0) {
		kbrow = value;
	} else if (reg==2) {
		inputreg = value & ~0x38;
	}
}


/* Cxxxxxx
	C - draw cursor */
uint8_t gfxreg[3];


// ERIFxxxx
uint8_t timerreg[2];
uint16_t timerval[2];
uint16_t timerinit[2];

uint8_t timerread(uint16_t reg) {
	int n = reg/3;
	reg %= 3;
	if (reg==0) {
		return timerreg[n];
	} else {
		return (timerval[n] >> 8*(reg-1)) & 0xFF;
	}
}

void timerwrite(uint16_t reg, uint8_t value) {
	int n = reg/3;
	reg %= 3;
	if (reg==0) {
		// is enable going 0 -> 1 ?
		timerreg[n] = value;
	} else {
		// unset enable
		timerreg[n] &= ~0x8F;
		// set appropriate byte (hacky)
		timerinit[n] &= 0xFF00 >> 8*(reg-1);
		timerinit[n] |= (uint16_t)value << 8*(reg-1);
		timerval[n] = timerinit[n];
	}
}

bool updatetimer(int n) {
	bool irq = false;
	if (!(timerreg[n] & 0x80)) return false; // skip if disabled
	if (timerval[n] == 0) { // enabled and zero?
		timerreg[n] |= 0x10; // set finished flag
		if (timerreg[n] & 0x20) irq = true;
		if (timerreg[n] & 0x40) timerval[n] = timerinit[n]; // refill if set
		else timerreg[n] &= ~0x8F; // disable otherwise
	} else
		timerval[n] -= 1;
	return irq;
}


uint8_t read8(uint16_t addr) {
#ifdef DEBUG
	if (addr == 0xBEEF) {
		return rand() % 256;
	}
#endif
	int i = PERIPHSTART;
	if (addr >= i && addr < i + INPUTLEN) {
		return inputread(addr - i);
	}
	i += INPUTLEN;
	if (addr >= i && addr < i + GFXLEN) {
		return gfxreg[addr-i];
	}
	i += GFXLEN;
	if (addr >= i && addr < i + TIMERLEN) {
		return timerread(addr - i);
	}
	return mem[addr];
}

void write8(uint16_t addr, uint8_t value) {
#ifdef DEBUG
	if (addr == 0xBEEF) {
		printf("($%04X)  $%02X = %d  (%s)\n", pc, value, value,
			FLAGSTR(0x01, "C"));
	}
#endif
	uint16_t i = PERIPHSTART;
	if (addr >= i && addr < i + INPUTLEN) {
		return inputwrite(addr - i, value);
	}
	i += INPUTLEN;
	if (addr >= i && addr < i + GFXLEN) {
		gfxreg[addr-i] = value;
		return;
	}
	i += GFXLEN;
	if (addr >= i && addr < i + TIMERLEN) {
		return timerwrite(addr - i, value);
	}
	mem[addr] = value;
}

void write16(uint16_t address, uint16_t value) {
	// little endian
    write6502(address+1, (value >> 8) & 0xFF);
    write6502(address, value & 0xFF);
}

uint16_t read16(uint16_t address) {
	// little endian
    return (uint16_t)read6502(address+1) << 8 | read6502(address);
}


void loadtomem(char *fname, uint16_t addr) {
	FILE *f = fopen(fname, "rb");
	if (f==NULL) {
		perror("loadtomem");
		exit(1);
	}
	fread(&mem[addr], 1, 0x10000-addr, f);
	fclose(f);
}

void loadchars(char *fname, uint16_t addr) {
	FILE *f = fopen(fname, "rb");
	if (f==NULL) {
		perror("loadchars");
		exit(1);
	}
	for (int i=0;;i++) {
		int c = getc(f);
		if (c==EOF) break;
		// i is the left-to-right index of c in the file
		// j is the desired transformed index in memory
		int j = (i%16)*8 + (i%128)/16 + (i/128)*128;
		mem[addr+j] = c;
	}
	fclose(f);
}

void reset() {
	srand(time(NULL));

	memset(mem, 0, 0x10000);
	memset(&mem[SCREENSTART+768], 0x40, 768);

	loadchars("chars.gray", CHARSSTART);
	loadtomem("rom/rom1", ROMSTART);
	loadtomem("rom/rom2", ROMSTART+0x1000);

	write16(0xFFFC, ROMSTART); // set initial pc
	write16(0xFFFE, ROMSTART); // for now, restart on IRQ

	reset6502();
}

void drawglyph(uint8_t glyph, int x, int y) {
	// upper 4 bits are index of foreground colour, lower 4 are background
	uint8_t colour = mem[SCREENSTART+768+y*SCREENW+x];
	int fg = (colour >> 4) & 0xF;
	int bg = colour & 0xF;
	fg *= 3; bg *= 3;

	bool invert = (gfxreg[0] & 0xF0) && x == gfxreg[1] && y == gfxreg[2];

	for (int gy=0; gy<8; gy++) {
		uint8_t bits = mem[CHARSSTART+glyph*8+gy];
		int sy = TILEH*(y+BORDERW) + gy;

		for (int gx=0; gx<8; gx++) {
			int sx = TILEW*(x+BORDERW) + gx;

			int usefg = bits & 128>>gx;
			if (invert) usefg = !usefg;
			int index = usefg ? fg : bg;

			((uint32_t *)Screen->pixels)[sy*WINDOWW+sx] = \
				SDL_MapRGB(Screen->format, palette[index], palette[index+1], palette[index+2]);
		}
	}
}

void drawscreen() {
	//~ for (int i=0; i<256; i++) {
	for (int i=0; i<SCREENH*SCREENW; i++) {
		drawglyph(mem[SCREENSTART+i], i%SCREENW, i/SCREENW);
		//~ drawglyph(i, i%16, i/16);
	}
	SDL_BlitScaled(Screen, NULL, WinSurf, NULL);
	SDL_UpdateWindowSurface(Win);
	frames++;
}

void handlekeyevent(SDL_KeyboardEvent *e) {
	SDL_Keycode code = e->keysym.sym;

	// don't distinguish either ctrl or shift keys
	if (code == SDLK_RCTRL) code = SDLK_LCTRL;
	else if (code == SDLK_RSHIFT) code = SDLK_LSHIFT;

	// send characters for backspace and line feed
	if (e->type == SDL_KEYDOWN && (inputreg & 0x04)) {
		if (code == SDLK_RETURN) gotchar = 8;
		else if (code == SDLK_BACKSPACE) gotchar = 10;
	}

	for (int i=0; i < KEYGRIDSIZE; i++) {
		if (keygrid[i] == code) {
			if (e->type == SDL_KEYUP && keydown[i] || e->type == SDL_KEYDOWN)
				DBGPRINTF("%s %s\n", SDL_GetKeyName(keygrid[i]), e->type == SDL_KEYDOWN ? "down" : "up");
			keydown[i] = e->type == SDL_KEYDOWN;
			break;
		}
	}
}

void handletextevent(SDL_TextInputEvent *e) {
	char *s = e->text;
	if (inputreg & 0x04 && s[1] == '\0') {
		gotchar = s[0];
	}
}

int handleevents() {
	SDL_Event e;
	SDL_PollEvent(&e);
	if (e.type == SDL_QUIT) {
		return 1;
	} else if (e.type == SDL_KEYDOWN || e.type == SDL_KEYUP) {
		handlekeyevent(&e.key);
	} else if (e.type == SDL_TEXTINPUT) {
		handletextevent(&e.text);
	}

	return 0;
}

void stretchysleep(uint64_t delta) {
	static int64_t overcount = 0;

	uint64_t clumpcount = countfreq / CPUFREQ * CLUMPSIZE;
	int64_t gap = clumpcount - delta;

	if (gap > 0) {
		// We finished too early, so sleep. But adjust our sleep time down to
		// account for any "debt" from previous late finishes
		uint64_t sleep;
		uint32_t sleepms;

		sleep = gap - MIN(overcount, gap);
		sleepms = 1000*sleep/countfreq;

		// ~ printf("SS: %d to fill, with debt %d, so sleeping %d (%d ms)\n", gap, overcount, sleep, sleepms);
		sleep = SDL_GetPerformanceCounter();
		SDL_Delay(sleepms);

		// Decrease overcount by the amount of time we didn't sleep
		overcount -= gap - (SDL_GetPerformanceCounter() - sleep);

		asleep += sleepms;
	} else {
		// We finished too late, so record how much by (gap is -ve)
		overcount -= gap;
	}
}

void sdlfatal() {
	printf("Fatal SDL error: %s\n", SDL_GetError());
	exit(1);
}

int main(int argc, char **argv) {

	if (SDL_Init(SDL_INIT_VIDEO) < 0) sdlfatal();

	Win = SDL_CreateWindow("XY Brewer", SDL_WINDOWPOS_UNDEFINED, SDL_WINDOWPOS_UNDEFINED, \
		SCALE*WINDOWW, SCALE*WINDOWH, 0);
	if (Win == NULL) sdlfatal();

	WinSurf = SDL_GetWindowSurface(Win);
	if (WinSurf == NULL) sdlfatal();

	Screen = SDL_CreateRGBSurfaceWithFormat(0, WINDOWW, WINDOWH, 32, SDL_PIXELFORMAT_RGBA32);
	if (Screen == NULL) sdlfatal();

	countfreq = SDL_GetPerformanceFrequency();

	DBGPRINTF("keygridsize = %d\n", KEYGRIDSIZE);
	reset();

	uint64_t lastcount;
	uint32_t lastdraw, lastevents, total = SDL_GetTicks();
	lastdraw = lastevents = clockticks6502;

	while (1) {
		lastcount = SDL_GetPerformanceCounter();

		if (clockticks6502 > lastevents + EVENTTICKS) {
			if (handleevents()) break;
			lastevents += EVENTTICKS;
		}

		bool irq = false;
		if (updatetimer(0)) irq = true;
		if (updatetimer(1)) irq = true;
		if (irq) irq6502();

		exec6502(CLUMPSIZE);

		if (clockticks6502 > lastdraw + DRAWTICKS) {
			drawscreen();
			lastdraw += DRAWTICKS;
		}

		stretchysleep(SDL_GetPerformanceCounter() - lastcount);
	}

	total = SDL_GetTicks() - total;
	printf("Averaged %.3f MHz CPU, %.3f FPS\n",
		(float)clockticks6502 / CPUFREQ * 1000 / total,
		(float)frames * 1000 / total);
	printf("Spent %.3f%% of running time asleep\n", (float)asleep / total * 100);

	SDL_Quit();
	return 0;
}
