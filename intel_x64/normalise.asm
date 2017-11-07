;normalise.asm

section .data
imax:	dq 255.0

section .text
global	minmax
global	normalise
global	makelutn

; void minmax(SDL_Surface *srf, unsigned char *min, unsigned char *max)
minmax: ;RDI, RSI, RDX
	push	rbp
	mov	rbp, rsp

	push	rbx
	push	r13

;	int	3			; debug interruption 
	mov	r8d, [rdi+20]		; r8	= rows (Y axis) count
	mov	r9d, [rdi+16]
	lea	r9, [r9+r9*2]		; r9	= subpixels count in row (X axis)
	mov	r10d, [rdi+24]		; r10	= pitch (X axis)
	mov	rdi, [rdi+32]		; rdi	= pixel_ptr
	mov	r13, r8			; r13	= height
	imul	r13, r10		; r13	= subpixels count
	sub	r10, r9			; r10	= offset = pitch - subpix_count (X axis)
	; prepare before lop0
	mov	bl, 255			; bl	= min val
	mov	bh, 0			; bh	= max val
	xor	rcx, rcx		; rcx	= global subpixel iterator
	xor	r11, r11		; r11	= horizontal iterator (X axis)

lop0:
	mov	al, [rdi+rcx]		; al 	= current subpixel

	cmp	al, bh			; check is new max
	jb	sk1
	mov	bh, al
sk1:
	cmp	al, bl			; check is new min
	ja	sk2
	mov	bl, al
sk2:
	add	rcx, 1			; increment global subpix counter
	add	r11, 1			; increment subpix counter in current row
	cmp	r11, r9			; check is current subpix an offset
	jne	sk3
	xor	r11, r11		; is offset - zero current row counter
	add	rcx, r10		; skip offset
sk3:
	cmp	rcx, r13		; check is end of subpixels
	jb	lop0

	mov	byte[rsi], bl		; store min and minmax into memory
	mov	byte[rdx], bh

	pop	r13
	pop	rbx

	leave
	ret

; void normalise(SDL_Surface *srf, unsigned char min, unsigned char max, int *hist_in, int *hist_out)
normalise: ;RDI, RSI, RDX, RCX, R8, R9
	push	rbp
	mov	rbp, rsp
	sub	rsp, 256		; lut array, 4 bytes per int * 256 colors

	push	r12
	push	r13
	push	r14

;	int	3			; debug interruption
	mov	r12, rdi		; r12 = srf_ptr
	mov	r13, rcx		; r13 = hist_in ptr
	mov	r14, r8			; r14 = hist_out ptr

	lea	rdi, [rbp-256]		; 'char *t_lut' ptr to rdi, min, max are already in rsi, rdx
	call	makelutn		; let's make LUT for normalisation

	xor	rax, rax		; ensure rax is zero
	mov	eax, [r12+20]		; +20	height (int)
	imul	eax, [r12+24]		; +24	pitch (int),	eax = height*pitch
	mov	r12, [r12+32]		; +32	pixels ptr,	r12 = pixel_ptr

	lea	rdi, [rbp-256]		; rdi = lut_array ptr
	xor	r11, r11		; r11 = 0, lop2 counter
	xor	rcx, rcx		; rcx = subpixels per value
lop2:
	movzx	rdx, byte[r12+r11]	; dl = old_subpixel, dl is lowest byte of rdx
	mov	ecx, [r13+rdx*4]	; get current subpixel count per value
	add	ecx, 1			; incerment the value
	mov	[r13+rdx*4], ecx	; store incremented value

	mov	dl, [rdi+rdx]		; dl = new_subpixel
	mov	[r12+r11], dl		; store new_subpixel into memory
	mov	ecx, [r14+rdx*4]	; get new subpixel count per value
	add	ecx, 1			; incerment the value
	mov	[r14+rdx*4], ecx	; store incremented value

	add	r11, 1			; increment lop2 counter
	cmp	r11, rax		; repeat rax times (rax = subpixel_count)
	jne	lop2

	pop	r14
	pop	r13
	pop	r12

	leave
	ret
;end of normalise()

; void makelutn(char *t_lut, usigned char min, unsigned char max)
makelutn:
;	int	3			; debug interruption
	push	rbp
	mov	rbp, rsp
	sub	rsp, 24			; rcx (counter) in memory, min, max (all are int64)

	mov	[rbp-16], rsi		; min to memory
	mov	[rbp-24], rdx		; max to memory
	fild	qword[rbp-16]		; st0 = vmin
	fild	qword[rbp-24]		; st0 = vmax, st1 = vmin
	fsub	st0, st1		; st0 = vmax-vmin, st1 = vmin
	fld	qword[imax]		; st0 = imax, st1 = vmax-vmin, st2 = vmin
	fxch	st1			; exchange st0 with st1
	fdivp	st1, st0		; st0 = imax/(vmax-vmin), st1 = vmin

	xor	rcx, rcx		; rcx = 0
lop1:
	mov	[rbp-8], rcx		; counter into memory
	fild	qword[rbp-8]		; st0 = i, st1 = imax/(vmax-vmin), st2 = vmin
	fsub	st0, st2		; st0 = i-vmin, st1 = imax/(vmax-vmin), st2 = vmin
	fmul	st0, st1		; st0 = (i-vmin)*imax/(vmax-vmin), st1 = ...

	fistp	qword[rbp-8]		; pop st0 temporary to rbp-8
	mov	rdx, [rbp-8]		; finally copy st0 into rdx gpr
	mov	byte[rdi+rcx], dl	; store lowest byte of curr_vall to array cell

	add	rcx, 1			; inc counter
	cmp	rcx, 256		; repeat 256x
	jne	lop1
;end of lop1

	mov	rcx, 2			; clean up FPU stack
lop3:	fcomip	st0			; (2 registers to pop)
	loop	lop3

	leave				; destroy stack pointer
	ret
;enf of makelutn()