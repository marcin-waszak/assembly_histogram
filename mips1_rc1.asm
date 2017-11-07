# Nazwa pliku:	lab2_contrast.asm
# Autor:	Marcin Waszak 3I1
# Opis:		Program koryguj¹cy kontrast i rozciagajacy histogram

# SEKCJA DANYCH
	.data
header:	.space	54		# standard header size
arrlut:	.space	256		# 256 colors values

	.align	4
histi:	.space	1024		# 256 x 4 bytes

	.align	4
histo:	.space	1024

input:	.space	64		# bufor nazwy pliku input
output:	.space	64		# bufor nazwy pliku output

lerror:	.asciiz	"Nie mozna zaladowac pliku input!\n"
msg1:	.asciiz "Wybierz (1), aby skorygowac kontrast\nWybierz (2), aby rozciagnac histogram\nTwoj wybor: "
msg2:	.asciiz "\nWprowadz wspolczynnik kontrastu (100 - wartosc neutralna): "
msg3:	.asciiz	"Korekcja kontrastu ...\n"
msg4:	.asciiz	"\nRozciaganie histogramu ...\n"
msgin:	.asciiz "Podaj nazwe pliku wejsciowego: "
msgout:	.asciiz "Podaj nazwe pliku wyjsciowego: "
lbl0:	.asciiz "Zestawienie histogramow wejsciowego i wyjsciowego\n"
lbl1:	.asciiz	"Wartosc"
lbl2:	.asciiz	"We"
lbl3:	.asciiz "Wy"

# SEKCJA KODU
	.text
	.globl main

main:
	la	$a0, input
	la	$a1, output
	jal	scan_choice
	move	$s5, $v0
	move	$s6, $v1

	# otwieramy plik wejsciowy input
	li	$v0, 13
	la	$a0, input
	li	$a1, 0
	li	$a2, 0
	syscall	
	move	$s3, $v0	# zapis deskryptora do $s3
	
	# sprawdzanie poprawnosci odczytu pliku
	beq	$s3, 0xFFFFFFFF, load_error	# idz do obslugi bledu
	
	# wczytywanie nag³owka
	li	$v0, 14		# czytanie z pliku
	move	$a0, $s3	# deskryptor moze od razu $a0 ???
	la	$a1, header	# bufor docelowy
	li	$a2, 54		# ilosc bajtow do wczytania
	syscall
	
	# obliczanie rzeczywistej iloœci subpixeli
	la	$s2, header		# adres naglowka do rejestru
	
	# allokowanie pamieci dla ci¹gu pixeli
	li	$v0, 9			# wo³amy SBRK
	ulw	$a0, 34($s2)		# allokujemy tyle ile rozmiar pod $s2 + 34 (BMP Data Size)
	move	$s2, $a0		# kopiujemy rozmiar tablicy subpixeli, przyda siê póŸniej
	syscall
	move	$s0, $v0		# kopiujemy adres zaalokowanego bufora
	
	# wczytywanie subpixeli
	li	$v0, 14		# czytanie z pliku
	move	$a0, $s3	# deskryptor moze od razu $a0 ???
	move	$a1, $s0	# bufor docelowy
	move	$a2, $s2	# ilosc bajtow do wczytania
	syscall
	
	# zamykanie pliku input
	li	$v0, 16
	move	$a0, $s3
	syscall
	
	beq	$s5, '2', skip3
	
	# tworzenie tablicy LUT	kontrastu
	la	$a0, arrlut
	move	$a1, $s6
	jal	contrast_lut
	j	cnt2

skip3:
	# tworzenie tablicy LUT	dla rozciagania histogramu
	la	$a0, arrlut
	move	$a1, $s0
	la	$a2, header
	jal	normalization_lut

cnt2:
	# podmiania subpixeli wedlug LUT
	# liczenie histogramu wejsciowego i wyjsciowego		
	li	$s4, 0	
start2:
	bge	$s4, $s2, exit2 #zakoncz jesli >= $s2 (rozmiar tablicy subpixeli)	
	
	addu	$t2, $s0, $s4	# $t2 == adres subpixela	
	lbu 	$t1, ($t2)	# $t1 == wartosc subpixela stara
	
	sll	$t3, $t1, 2
	lw	$t5, histi($t3)
	addiu	$t5, $t5, 1
	sw	$t5, histi($t3)
	
	#addu	$t4, $t3, $t1	# $t4 == adres w LUT
	lbu	$t1, arrlut($t1)# $t1 == nowy kolor
	sb	$t1, ($t2)	# zapisz nowy kolor pod adres subpixela
	
	sll	$t1, $t1, 2
	lw	$t5, histo($t1)
	addiu	$t5, $t5, 1
	sw	$t5, histo($t1)
	
	addiu	$s4, $s4, 1
	j	start2
	
exit2:			
	# otwieramy plik wyjsciowy output
	li	$v0, 13
	la	$a0, output
	li	$a1, 1
	li	$a2, 0
	syscall	
	move	$s3, $v0	# zapis deskryptora do $s3

	# zapis do pliku output
	li	$v0, 15
	move	$a0, $s3
	la	$a1, header
	li	$a2, 54
	syscall
	
	# zapis subpixeli do pliku output
	li	$v0, 15
	move	$a0, $s3
	move	$a1, $s0
	move	$a2, $s2
	syscall
	
	# zamykanie pliku output
	li	$v0, 16
	move	$a0, $s3
	syscall
	
	# wyswietlenie zestawienia histogramow
	la	$a0, histi
	la	$a1, histo
	jal	print_histogram

	# zakonczenie programu
	li	$v0, 10
	syscall	
	
load_error:
        # wystapil blad przy odczycie pliku - wyswietlamy komunikat
	li	$v0, 4
	la	$a0, lerror	
	syscall

	# zakonczenie programu
	li	$v0, 10
	syscall
	
scan_choice:
##### FUNKCJA POBIERAJACA DANE OD UZYTKOWNIKA #####
# argumenty:
# a0 - adres bufora input
# a1 - adres bufora output
# wartosci zwracane:
# v0 - 1-kontrast, 2-rozciaganie histogramu
# v1 - wspolczynnik kontrastu

# prolog
 	addi	$sp, $sp, -20
  	sw	$s3, 16($sp)
	sw	$s2, 12($sp)
 	sw	$s1, 8($sp)
	sw	$s0, 4($sp)
	sw	$ra, 0($sp)
#
	
	# kopiujemy adresy buforow input & output
	move	$s2, $a0
	move	$s3, $a1

	# pytanie o nazwe pliku wejsciowego
	li	$v0, 4
	la	$a0, msgin
	syscall
	
	# pobieranie stringa input od usera
	li	$v0, 8
	move	$a0, $s2
	li	$a1, 64
	syscall
	
	# pytanie o nazwe pliku wyjsciowego
	li	$v0, 4
	la	$a0, msgout
	syscall
	
	# pobieranie stringa output od usera
	li	$v0, 8
	move	$a0, $s3
	li	$a1, 64
	syscall

	# erase linefeed character (0xA) from input string
	move	$t0, $s2
looplf1:
	addiu	$t0, $t0, 1
	lbu	$t1, ($t0)
	bne	$t1, 0xA, looplf1
	sb	$zero, ($t0)
	
	# erase linefeed character (0xA) from output string
	move	$t0, $s3
looplf2:
	addiu	$t0, $t0, 1
	lbu	$t1, ($t0)
	bne	$t1, 0xA, looplf2
	sb	$zero, ($t0)	

	# pytanie o kontrast czy rozciaganie hist.
	li	$v0, 4
	la	$a0, msg1
	syscall
	
	# oczekiwanie wyboru
	li	$v0, 12
	syscall	
	
	move	$s0, $v0
	
	beq	$s0, '2', skip2
	#jesli nie '2' - kontrast
	li	$v0, 4
	la	$a0, msg2
	syscall
	
	# oczekiwanie wyboru wsp. kontrastu
	li	$v0, 5
	syscall
	move	$s1, $v0
	
	# print korekcja kontrastu
	li	$v0, 4
	la	$a0, msg3
	syscall
	
	j cnt4

skip2:
	# print rozciaganie hist.
	li	$v0, 4
	la	$a0, msg4
	syscall
cnt4:	
	move	$v0, $s0
	move	$v1, $s1
# epilog
	lw	$s3, 16($sp)
	lw	$s2, 12($sp)
	lw	$s1, 8($sp)
	lw	$s0, 4($sp)
	lw	$ra, 0($sp)
	addi	$sp, $sp, 20

	jr	$ra
#
### scan_choice - koniec ###
	
print_histogram:
##### FUNKCJA WYSWIETLAJACA ZESTAWIENIE HISTOGRAMOW #####
# argumenty:
# a0 - adres tablicy histogramu wejsciowego
# a1 - adres tablicy histogramu wyjsciowego


# prolog
 	addi	$sp, $sp, -12
 	sw	$s1, 8($sp)
	sw	$s0, 4($sp)
	sw	$ra, 0($sp)
#
	move	$s0, $a0
	move	$s1, $a1

	# wyswitlenie zestawienia histogramow
	li	$v0, 4
	la	$a0, lbl0
	syscall
	
	li	$v0, 4
	la	$a0, lbl1
	syscall	
	
	li	$v0, 11
	li	$a0, '\t'
	syscall

	li	$v0, 4
	la	$a0, lbl2
	syscall	
	
	li	$v0, 11
	li	$a0, '\t'
	syscall
	
	li	$v0, 4
	la	$a0, lbl3
	syscall	

	li	$v0, 11
	li	$a0, '\n'
	syscall	

	
	li	$t0, 0
start5:
	bge	$t0, 256, exit5 #zakoncz jesli >= 256
	
	li	$v0, 1
	move	$a0, $t0
	syscall
	
	li	$v0, 11
	li	$a0, '\t'
	syscall
	
	sll	$t1, $t0, 2
	li	$v0, 1
	addu	$t2, $s0, $t1
	lw	$a0, ($t2)
	syscall
	
	li	$v0, 11
	li	$a0, '\t'
	syscall
	
	li	$v0, 1
	addu	$t2, $s1, $t1
	lw	$a0, ($t2)
	syscall
	
	li	$v0, 11
	li	$a0, '\n'
	syscall
	
	addiu	$t0, $t0, 1
	j	start5	
exit5:
	
# epilog
	lw	$s1, 8($sp)
	lw	$s0, 4($sp)
	lw	$ra, 0($sp)
	addi	$sp, $sp, 12

	jr	$ra
#
### print_histogram - koniec ###

	
contrast_lut:
##### FUNKCJA TWORZ¥CA LUT DLA KONTRASTU #####
# argumenty:
# a0 - adres tablicy LUT
# a1 - parametr kontrstu x100

# prolog
 	addi	$sp, $sp, -16
	sw	$s2, 12($sp)
	sw	$s1, 8($sp)
	sw	$s0, 4($sp)
	sw	$ra, 0($sp)
#
	li	$s0, 0		#licznik petli, skacze co 1
start1:
	bge	$s0, 256, exit1
	mul	$t0, $s0, 10	# 10i
	addiu	$s1, $t0, -1275	# 10i - 1275
	mul	$s1, $s1, $a1	# a * (10i - 1275)
	addiu	$s1, $s1, 127500# (a * (i - 1275)) + 127500	
	div	$s1, $s1, 1000	# (a * (10i - 1275)) / 1000
	
	bgt	$s1, 255, lut_max
	blt	$s1, 0, lut_min
	j	cnt
	
lut_max:
	li	$s1, 255
	j	cnt

lut_min:
	li	$s1, 0
cnt:
	addu	$s2, $a0, $s0 ## $t0 <--> $a0
	sb	$s1, ($s2)
	addi	$s0, $s0, 1
	j	start1

exit1:
# epilog
	lw	$s2, 12($sp)
	lw	$s1, 8($sp)
	lw	$s0, 4($sp)
	lw	$ra, 0($sp)
	addi	$sp, $sp, 16

	jr	$ra
#
### contrast_lut - koniec ###

normalization_lut:
##### FUNKCJA TWORZ¥CA LUT DLA ROZCI¥GANIA HISTOGRAMU #####
# argumenty:
# a0 - adres tablicy LUT
# a1 - adres bufora subpixeli
# a2 - adres nag³ówka bitmapy

# prolog
 	addi	$sp, $sp, -28
 	sw	$s5, 24($sp)
 	sw	$s4, 20($sp)
 	sw	$s3, 16($sp)
	sw	$s2, 12($sp)
	sw	$s1, 8($sp)
	sw	$s0, 4($sp)
	sw	$ra, 0($sp)
#
	ulw	$s0, 18($a2) #W
	ulw	$s1, 22($a2) #H
	ulw	$s2, 34($a2) #bitmap size
	
	# obliczenie wyrównania (padding)
	
	#   padding = 0;
	#   y = (width * 3) % 4;
	#   if(y != 0) padding = 4 - y;
	
	li	$s3, 0		# $s3 == padding
	mul	$s4, $s0, 3	# $s4 == liczba subpixeli w rzêdzie
	and	$t0, $s4, 3	# x % 2^n <==> x & (2^n - 1)
	beqz	$t0, cnt3
	li	$t1, 4
	subu	$s3, $t1, $t0
	
#	addiu	$s3, $s4, 3
#	srl	$s3, $s3, 2
#	sll	$s3, $s3, 2
#	subu	$s3, $s3, $s4
	
cnt3:	
	li	$t0, 0		# licznik subpixeli
	li	$t1, 0		# licznik subpixeli w rzêdzie
	li	$t5, 0		# licznik rzêdów
	li	$t3, 255	# min
	li	$t4, 0		# max
start3:
	bgeu	$t0, $s2, exit3 # zakoncz jesli >= $s2 (rozmiar tablicy subpixeli)
	
	bltu 	$t1, $s4, skip1 # jesli subp. >=  l. subp. w rzedzie
	addiu	$t5, $t5, 1
	addu	$t0, $t0, $s3
	li	$t1, 0	
	bgeu	$t5, $s1, exit3
	
skip1:
	addu	$s5, $a1, $t0	# $s5 adres subpixela
	lbu	$t2, ($s5)	# ³aduj subpixel	
	
	bltu	$t2, $t3, mk_min
	bgtu	$t2, $t4, mk_max

	addiu	$t0, $t0, 1
	addiu	$t1, $t1, 1
	j	start3
	
mk_min:	move	$t3, $t2
	j	start3
	
mk_max: move	$t4, $t2
	j	start3	
	
exit3:

	subu	$t2, $t4, $t3	# max-min
	# tworzenie LUT dla rozci¹gania histogramu
	li	$t0, 0		# licznik petli, skacze co 1
start4:
	bge	$t0, 256, exit4
	subu	$t1, $t0, $t3	# i - min
	mul	$t1, $t1, 255
	div	$s5, $t1, $t2
	
	addu	$t4, $a0, $t0
	sb	$s5, ($t4)
	
	addiu	$t0, $t0, 1
	j	start4
		
exit4:
# epilog
	lw	$s5, 24($sp)
	lw	$s4, 20($sp)
	lw	$s3, 16($sp)
	lw	$s2, 12($sp)
	lw	$s1, 8($sp)
	lw	$s0, 4($sp)
	lw	$ra, 0($sp)
	addi	$sp, $sp, 28

	jr	$ra
#
### normalization_lut - koniec ###
