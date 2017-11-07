;normalise.asm

section .data
imax:	dq 255.0

section .text
global	minmax
global	normalise
global	makelutn

; void minmax(SDL_Surface *srf, unsigned char *min, unsigned char *max)
minmax: ;RDI, RSI, RDX
	push	ebp
	mov	ebp, esp
	sub	esp, 24 ; 6 local variables ()

	push	ebx
	push	esi
	push	edi

	mov	edi, [ebp+8]		; surface ptr into edi

;	int	3			; debug interruption

	mov	eax, [edi+12]
	mov	[ebp-4], eax		; r8	ebp-4	= rows (Y axis) count

	mov	eax, [edi+8]		; width
	lea	eax, [eax+eax*2]	; r9	ebp-8	= subpixels count in row (X axis)
	mov	[ebp-8], eax

	mov	eax, [edi+16]		; r10	ebp-12	= pitch (X axis)
	mov	[ebp-12], eax

	mov	edi, [edi+20]		; edi		= pixel_ptr

	mov	eax, [ebp-4]		; r13		= height
	mov	esi, [ebp-12]
	imul	eax, esi		; r13	ebp-16	= subpixels count
	mov	[ebp-16], eax		

	sub	esi, [ebp-8]		; esi		= offset = pitch - subpix_count (X axis)

	; prepare before lop0
	mov	bl, 255			; bl	= min val
	mov	bh, 0			; bh	= max val
	xor	ecx, ecx		; ecx	= global subpixel iterator
	xor	edx, edx		; edx	= horizontal iterator (X axis)
lop0:
	mov	al, [edi+ecx]		; al 	= current subpixel

	cmp	al, bh			; check is new max
	jb	sk1
	mov	bh, al
sk1:
	cmp	al, bl			; check is new min
	ja	sk2
	mov	bl, al
sk2:
	add	ecx, 1			; increment global subpix counter
	add	edx, 1			; increment subpix counter in current row
	cmp	edx, [ebp-8]		; check is current subpix an offset
	jne	sk3
	xor	edx, edx		; is offset - zero current row counter
	add	ecx, esi		; skip offset
sk3:
	cmp	ecx, [ebp-16]		; check is end of subpixels
	jb	lop0
;	int	3

	mov	eax, [ebp+12]
	mov	ecx, [ebp+16]

	mov	byte[eax], bl	; store min and max into memory
	mov	byte[ecx], bh	; solved!

	pop	edi
	pop	esi
	pop	ebx

	leave
	ret
;			+8		+12		+16		  +20		+24
; void normalise(SDL_Surface *srf, unsigned char min, unsigned char max, int *hist_in, int *hist_out)
normalise:
	push	ebp
	mov	ebp, esp
	sub	esp, 256		; lut array, 4 bytes per int * 256 colors

	push	ebx
	push	esi
	push	edi

;	int	3			; debug interruption

	movzx	eax, byte[ebp+12]
	movzx	ecx, byte[ebp+16]

	push	ecx
	push	eax

	lea	eax, [ebp-256]		; push 'int *t_lut'
	push	eax

; void makelutn(char *t_lut, unsigned char min, unsigned char max)
	call	makelutn		; let's make LUT
	add	esp, 12			; clean up the stack

	mov	ebx, [ebp+8]		; ebx = srf_ptr, offsets below
	mov	eax, [ebx+12]		; +12	height
	imul	eax, [ebx+16]		; +16	pitch,		eax = height*pitch
	mov	ebx, [ebx+20]		; +20	pixels ptr,	ebx = pixel_ptr

	xor	ecx, ecx		; ecx = 0
	lea	edi, [ebp-256]		; edi = t_lut ptr

lop2:
	push	eax			; store subpixels count to memory

	movzx	edx, byte[ebx+ecx]	; dl = old_subpixel
	mov	esi, [ebp+20]		; esi = hist_in_ptr
	mov	eax, [esi+edx*4]	; eax = current_value_count
	add	eax, 1			; increment count
	mov	[esi+edx*4], eax	; store incremented value

	movzx	edx, byte[edi+edx]	; dl = new_subpixel
	mov	[ebx+ecx], dl		; store new_subpixel into memory
	mov	esi, [ebp+24]		; esi = hist_out_ptr
	mov	eax, [esi+edx*4]	; eax = new_value_count
	add	eax, 1			; increment count
	mov	[esi+edx*4], eax	; store incremented value

	pop	eax			; restore subpixels count
	add	ecx, 1			; inc counter
	cmp	ecx, eax		; repeat eax times (eax = subpixel_count)
	jne	lop2	

	pop	edi
	pop	esi
	pop	ebx

	leave
	ret
;end of contrast()

; void makelutn(char *t_lut, unsigned char min, unsigned char max)
makelutn:
;	int	3			; debug interruption
	push	ebp
	mov	ebp, esp
	sub	esp, 8			; rcx (counter) in memory, min, max (all are int64)

	push	edi

	mov	edi, [ebp+8]

	fild	dword[ebp+12]		; st0 = vmin
	fild	dword[ebp+16]		; st0 = vmax, st1 = vmin
	fsub	st0, st1		; st0 = vmax-vmin, st1 = vmin
	fld	qword[imax]		; st0 = imax, st1 = vmax-vmin, st2 = vmin
	fxch	st1			; exchange st0 with st1
	fdivp	st1, st0		; st0 = imax/(vmax-vmin), st1 = vmin

	xor	ecx, ecx		; rcx = 0
lop1:
	mov	[ebp-4], ecx		; counter into memory
	fild	dword[ebp-4]		; st0 = i, st1 = imax/(vmax-vmin), st2 = vmin
	fsub	st0, st2		; st0 = i-vmin, st1 = imax/(vmax-vmin), st2 = vmin
	fmul	st0, st1		; st0 = (i-vmin)*imax/(vmax-vmin), st1 = ...

	fistp	dword[ebp-4]		; pop st0 temporary to rbp-8
	mov	edx, [ebp-4]		; finally copy st0 into rdx gpr
	mov	byte[edi+ecx], dl	; store lowest byte of curr_vall to array cell

	add	ecx, 1			; inc counter
	cmp	ecx, 256		; repeat 256x
	jne	lop1
;end of lop1

	mov	ecx, 2			; clean up FPU stack
lop3:	fcomip	st0			; (2 registers to pop)
	loop	lop3

	pop	edi

	leave				; destroy stack pointer
	ret
;enf of makelutn()