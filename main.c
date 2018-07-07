#include <stdio.h>
#include <stdbool.h>
#include <errno.h>
#include <unistd.h>

#include <SDL.h>
#include <SDL_video.h>
//~ #include <SDL_timer.h>

#include "common.h"
#define INPUTSTART 0x0200
#define ROMSTART 0xE000
#define CHARSSTART 0xD700
#define SCREENSTART 0xCF00
#define SCALE 3
#define CLUMPSIZE 10000 // no. of cpu ticks to do between throttling
#define DRAWTICKS 33333 // minimum no. of cpu ticks before redraw

#define MIN(x, y) ((x)<(y)?(x):(y))
#define MASKBIT(val, bit) ((val)>>(bit)&1)

uint8_t mem[1<<16];
SDL_Window *Win;
SDL_Surface *WinSurf;
SDL_Surface *Screen;
//~ SDL_Surface *Chars;
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
	SDLK_SPACE, SDLK_EXCLAIM, SDLK_QUOTEDBL, SDLK_HASH, SDLK_DOLLAR, SDLK_PERCENT, SDLK_AMPERSAND, SDLK_QUOTE,
	SDLK_LEFTPAREN, SDLK_RIGHTPAREN, SDLK_ASTERISK, SDLK_PLUS, SDLK_COMMA, SDLK_MINUS, SDLK_PERIOD, SDLK_SLASH,
	SDLK_0, SDLK_1, SDLK_2, SDLK_3, SDLK_4, SDLK_5, SDLK_6, SDLK_7,
	SDLK_8, SDLK_9, SDLK_COLON, SDLK_SEMICOLON, SDLK_LESS, SDLK_EQUALS, SDLK_GREATER, SDLK_QUESTION,
	SDLK_AT, SDLK_a, SDLK_b, SDLK_c, SDLK_d, SDLK_e, SDLK_f, SDLK_g,
	SDLK_h, SDLK_i, SDLK_j, SDLK_k, SDLK_l, SDLK_m, SDLK_n, SDLK_o,
	SDLK_p, SDLK_q, SDLK_r, SDLK_s, SDLK_t, SDLK_u, SDLK_v, SDLK_w,
	SDLK_x, SDLK_y, SDLK_z, SDLK_LEFTBRACKET, SDLK_BACKSLASH, SDLK_RIGHTBRACKET, SDLK_CARET, SDLK_UNDERSCORE,
	SDLK_BACKQUOTE, SDLK_BACKSPACE, SDLK_RETURN, SDLK_LSHIFT, SDLK_LCTRL
};
#define KEYGRIDSIZE (9*8-1)
bool keydown[KEYGRIDSIZE];

#define READPERIPH(start, len, function) \
	if (addr >= start && addr <= start+len) {\
		return function(addr-start);\
	}
#define WRITEPERIPH(start, len, function) \
	if (addr >= start && addr <= start+len) {\
		function(addr-start, value);\
		return;\
	}

uint8_t inputread(uint16_t reg) {
	static uint8_t kbrow;
	if (reg==0) {
		return kbrow;
	} else {
		uint8_t res = 0;
		for (int i=0; i<8; i++) {
			res |= keydown[kbrow*8+i] << i;
		}
		return res;
	}
}
void inputwrite(uint16_t reg, uint8_t value) {
	//~ printf("$%X = %X\n", addr, value);
	//~ if (addr >= CHARSSTART && addr <= CHARSSTART+0x800) {
		//~ // horrible remapping, can't even explain it
		//~ addr -= CHARSSTART;
		//~ addr = (addr%16)*8 + (addr%128)/16 + (addr/128)*128;
		//~ addr += CHARSSTART;
	//~ }
	mem[reg] = value;
}

uint8_t read6502(uint16_t addr) {
	READPERIPH(INPUTSTART, 2, inputread)
	//~ if (addr >= INPUTSTART && addr <= INPUTSTART+0x800) {
		//~ return readinput(addr - INPUTSTART);
	//~ }
	return mem[addr];
}
void write6502(uint16_t addr, uint8_t value) {
	//~ printf("$%X = %X\n", addr, value);
	WRITEPERIPH(INPUTSTART, 2, inputwrite)
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

int loadtomem(char *fname, uint16_t addr) {
	FILE *f = fopen(fname, "r");
	if (f==NULL) {
		perror("loadtomem");
		exit(1);
	}
	fread(&mem[addr], 1, 1<<16-1-addr, f);
	fclose(f);
}

int loadchars(char *fname, uint16_t addr) {
	FILE *f = fopen(fname, "r");
	if (f==NULL) {
		perror("loadtomem");
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

int initialise() {
	write16(0xFFFC, 0xE000); // set initial pc

	loadchars("chars.gray", 0xD700);
	loadtomem("a.o65", 0xE000);
	memset(&mem[SCREENSTART+768], 0x60, 768);

	//~ SDL_SetHint(SDL_HINT_FRAMEBUFFER_ACCELERATION, "1");
	SDL_Init(SDL_INIT_VIDEO);
	Win = SDL_CreateWindow("XY Brewer", \
		SDL_WINDOWPOS_UNDEFINED, SDL_WINDOWPOS_UNDEFINED, \
		SCALE*TILEW*(SCREENW+2*BORDERW), SCALE*TILEH*(SCREENH+2*BORDERW), 0);
	WinSurf = SDL_GetWindowSurface(Win);
	Screen = SDL_CreateRGBSurfaceWithFormat(0, TILEW*(SCREENW+2*BORDERW), TILEH*(SCREENH+2*BORDERW), \
		WinSurf->format->BitsPerPixel, WinSurf->format->format);
		//~ WinSurf->format->BitsPerPixel, SDL_PIXELFORMAT_RGBA32);
	//~ SDL_SetSurfaceRLE(Screen, 1);

	//~ Chars = SDL_CreateRGBSurfaceFrom((void*)&mem[CHARSSTART], 128, 128, 1, 16, 1,1,1,0);
	//~ SDL_Color tmp;
	//~ tmp = Chars->format->palette->colors[0];
	//~ Chars->format->palette->colors[0] = Chars->format->palette->colors[1];
	//~ Chars->format->palette->colors[1] = tmp;
}

void drawglyph(uint8_t glyph, int x, int y) {
	uint8_t colbyte = read6502(SCREENSTART+768+y*SCREENW+x);
	int fg = (colbyte >> 4) & 0xF;
	int bg = colbyte & 0xF;
	fg *= 3; bg *= 3;
	uint32_t *pixels = (uint32_t *)Screen->pixels;
	for (int gy=0; gy<8; gy++) {
		uint8_t bits = read6502(0xD700+glyph*8+gy);
		int sy = TILEH*(y+BORDERW) + gy;
		for (int gx=0; gx<8; gx++) {
			int sx = TILEW*(x+BORDERW) + gx;
			int index;
			if (bits & 128>>gx) {
				// foreground
				index = fg;
			} else {
				// background
				index = bg;
			}
			pixels[sy*WINDOWW+sx] = SDL_MapRGB(Screen->format, palette[index], palette[index+1], palette[index+2]);
			//~ sx++;
		}
		//~ sy++;
	}
}

/*void drawglyph(uint8_t glyph, int x, int y) {
	SDL_Rect glyphrect, scrrect;
	int gx, gy;
	gx = glyph % 16;
	gy = glyph / 16;

	glyphrect.x = gx*TILEW;
	glyphrect.y = gy*TILEH;
	glyphrect.w = TILEW;
	glyphrect.h = TILEH;

	scrrect.x = (x+BORDERW)*TILEW;
	scrrect.y = (y+BORDERW)*TILEH;
	scrrect.w = TILEW;
	scrrect.h = TILEH;

	//~ COLORSET(back);
	//~ SDL_RenderFillRect(Ren, &scrrect);
	//~ SDL_SetTextureColorMod(Codepage, fore.r, fore.g, fore.b);
	SDL_BlitSurface(Chars, &glyphrect, Screen, &scrrect);
}*/

void drawscreen() {
	//~ for (int i=0; i<256; i++) {
	for (int i=0; i<SCREENH*SCREENW; i++) {
		drawglyph(mem[SCREENSTART+i], i%SCREENW, i/SCREENW);
		//~ drawglyph(i, i%16, i/16);
	}
	SDL_BlitScaled(Screen, NULL, WinSurf, NULL);
	SDL_UpdateWindowSurface(Win);
}

void handlekeyevent(SDL_KeyboardEvent *e) {
	SDL_Keycode code = e->keysym.sym;
	for (int i=0; i<KEYGRIDSIZE; i++) {
		if (keygrid[i] == code) {
			keydown[i] = e->type == SDL_KEYDOWN;
			break;
		}
	}
}

int main() {

	initialise();
	reset6502();
	uint64_t countfreq = SDL_GetPerformanceFrequency();
	uint64_t clumpcount = countfreq / 1000000 * CLUMPSIZE;


	uint64_t total = SDL_GetPerformanceCounter();
	int frames = 0;

	SDL_Event e;
	//~ int quit = 0;
	uint64_t overcount = 0;
	uint32_t lastdraw = clockticks6502;
	for (;;) {
		uint64_t last = SDL_GetPerformanceCounter();

		SDL_PollEvent(&e);
		if (e.type == SDL_QUIT) {
			break;
		} else if ((e.type == SDL_KEYDOWN || e.type == SDL_KEYUP) && !e.key.repeat) {
			handlekeyevent(&e.key);
		}

		exec6502(CLUMPSIZE);
		if (clockticks6502 > lastdraw + DRAWTICKS) {
			lastdraw += DRAWTICKS;
			drawscreen();
			frames++;
		}
		uint64_t count = SDL_GetPerformanceCounter() - last;

		// can we rewrite this throttle as simply as drawing one above? would be a busy wait...
		if (count <= clumpcount) {
			uint64_t extra = MIN(overcount, clumpcount-count);
			overcount -= extra;
			usleep((1000000-10000)*(clumpcount-(count+extra))/countfreq); // -10000 to account for small overheads
		} else {
			overcount += count - clumpcount;
		}
	}

	total = SDL_GetPerformanceCounter()-total;
	printf("Averaged %f MHz CPU, %f FPS\n", \
		1.0/((float)(total)/clockticks6502/countfreq*1000000), \
		 (float)countfreq*frames/total);
	SDL_Quit();
	return 0;
}
