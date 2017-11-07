CC=gcc
CFLAGS=-m32 -std=c99 -lSDL2

ASM=nasm
AFLAGS=-f elf32

all: main

main.o:  main.c
		$(CC) $(CFLAGS) -c main.c
normalise.o: normalise.asm
		$(ASM) $(AFLAGS) normalise.asm
contrast.o: contrast.asm
		$(ASM) $(AFLAGS) contrast.asm
		
main:	main.o normalise.o contrast.o
		$(CC) main.o normalise.o contrast.o $(CFLAGS) -o main
clean:
		rm *.o
		rm main
