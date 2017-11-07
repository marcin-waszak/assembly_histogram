#include <SDL2/SDL.h>
#include <stdio.h>

extern void contrast(SDL_Surface *srf, double a, int *hist_in, int *hist_out);
extern void normalise(SDL_Surface *srf, unsigned char min, unsigned char max, int *hist_in, int *hist_out);
extern void minmax(SDL_Surface *srf, unsigned char *min, unsigned char *max);

#define	M_DEFAULT		0
#define M_NORMALISATION	1
#define M_CONTRAST		2

int main(int argc, char *argv[])
{
//	variables necessary for SDL Window
	SDL_Window *win = NULL;
	SDL_Renderer *renderer = NULL;
	SDL_Texture *bitmapTex = NULL;
	SDL_Surface *bitmapSurface = NULL;
	int posX = 100;
	int posY = 100;
	char title_buffer[128];

	SDL_Init(SDL_INIT_VIDEO);

//	load our image into memory
	bitmapSurface = SDL_LoadBMP("trafo.bmp");

//	helper variables
	int bitmap_size = bitmapSurface->h * bitmapSurface->pitch;
	int width = bitmapSurface->w;
	int height = bitmapSurface->h;

//	make a copy of original bitmap
	char *bitmap_copy = malloc(bitmap_size);
	memcpy(bitmap_copy, bitmapSurface->pixels, bitmap_size); // copy of original bitmap

//	render window
	win = SDL_CreateWindow("Marcin Waszak ARKO x86-64", posX, posY, width, height, 0);
	renderer = SDL_CreateRenderer(win, -1, SDL_RENDERER_ACCELERATED);

//	variables necessary for contrast & normalisation functions
	int input_histogram[256];
	int output_histogram[256];
	double ratio = 1.0;
	unsigned char lut_normalisation[256];
	unsigned char lut_contrast[256];
	unsigned char min;
	unsigned char max;

	minmax(bitmapSurface, &min, &max);

//	default mode is normalisation
	int mode = M_DEFAULT;

	while (1) 
	{
		SDL_Event e;
		if (SDL_PollEvent(&e)) 
		{
			if (e.type == SDL_QUIT)
				break;

			if (e.type == SDL_KEYDOWN && e.key.keysym.sym == SDLK_ESCAPE)
    			break;

			if(mode == M_CONTRAST)
			{
				if (e.type == SDL_KEYDOWN && e.key.keysym.sym == SDLK_LEFT)
					ratio /= 1.1;
				
				if (e.type == SDL_KEYDOWN && e.key.keysym.sym == SDLK_RIGHT)
					ratio *= 1.1;

				if (e.type == SDL_KEYDOWN && e.key.keysym.sym == SDLK_r)
					ratio *= -1.0;
			}

			if(mode != M_DEFAULT)
			{
				if (e.type == SDL_KEYDOWN && e.key.keysym.sym == SDLK_i)
				{
					printf("\nValue\tIn\tOut\n");
					for(int i = 0; i < 256; i++)
						printf("%d.\t%d\t%d\n", i, input_histogram[i], output_histogram[i]);	
				}
			}

			if (e.type == SDL_KEYDOWN && e.key.keysym.sym == SDLK_d)
				mode = M_DEFAULT;

			if (e.type == SDL_KEYDOWN && e.key.keysym.sym == SDLK_n)
				mode = M_NORMALISATION;

			if (e.type == SDL_KEYDOWN && e.key.keysym.sym == SDLK_c)
				mode = M_CONTRAST;
		}

		memset(input_histogram, 0, 256*4); //256 * int(4)
		memset(output_histogram, 0, 256*4);


		switch(mode)
		{
			case M_NORMALISATION:
				normalise(bitmapSurface, min, max, input_histogram, output_histogram);
				sprintf(title_buffer, "Mode: normalisation");
				SDL_SetWindowTitle(win, title_buffer);
				break;

			case M_CONTRAST:
				contrast(bitmapSurface, ratio, input_histogram, output_histogram);
				sprintf(title_buffer, "Mode: contrast [%lf]", ratio);
				SDL_SetWindowTitle(win, title_buffer);
				break;

			default:
				sprintf(title_buffer, "Mode: default");
				SDL_SetWindowTitle(win, title_buffer);
		}



		bitmapTex = SDL_CreateTextureFromSurface(renderer, bitmapSurface);
		memcpy(bitmapSurface->pixels, bitmap_copy, bitmap_size); // revert unmodified image

		SDL_RenderClear(renderer);
		SDL_RenderCopy(renderer, bitmapTex, NULL, NULL);
		SDL_RenderPresent(renderer);
		SDL_DestroyTexture(bitmapTex);
	}

	SDL_FreeSurface(bitmapSurface);
	
	SDL_DestroyRenderer(renderer);
	SDL_DestroyWindow(win);

	SDL_Quit();
	return 0;
}