;contrast.asm

section .data
imax:	dq 255.0
imax2:	dq 127.5
imin:	dq 0.0

section .text
global	contrast
global	makelutc

; void contrast(SDL_Surface *srf, double a, int *hist_in, int *hist_out)
contrast:
	push	ebp
	mov	ebp, esp
	sub	esp, 256		; lut array, 4 bytes per int * 256 colors

	push	ebx
	push	esi
	push	edi

;	int	3			; debug interruption

	sub	esp, 8			; push 'double a'
	mov	eax, [ebp+12]
	mov	[esp], eax

	mov	eax, [ebp+16]
	lea	ecx, [esp+4]
	mov	[ecx], eax

	lea	eax, [ebp-256]		; push 'int *t_lut'
	push	eax

	call	makelutc		; let's make LUT
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

; void makelutc(unsigned char *t_lut, double a)
makelutc:
;	int	3			; debug interruption

	push	ebp
	mov	ebp, esp
	sub	esp, 4			; ecx (counter) in memory, local variable

	xor	ecx, ecx		; ecx = 0
	mov	eax, [ebp+8]		; eax = t_lut
	fld	qword[imin]		; st0 = imin
	fld	qword[imax2]		; st0 = imax2, st1 = imin
	fld	qword[imax]		; st0 = imax, st1 = imax2, st2 = imin
	fld	qword[ebp+12]		; st0 = a, st1 = imax, st2 = imax2, st3 = imin

lop1:
	mov	[ebp-4], ecx		; ecx (counter) to memory
	fild	dword[ebp-4]		; st0 = curr_val, st1 = a, st2 = imax, st3 = imax2, st4 = imin
	fsub	st3			; i - imax2
	fmul	st1			; a*(i - imax2)
	fadd	st3			; a*(i - imax2) + imax2

	fcomi	st0, st2		; if curr_val > 255 then 255
	fcmovnb st0, st2
	fcomi	st0, st4		; if curr_val < 0 then 0
	fcmovb	st0, st4

	fistp	dword[ebp-4]		; pop curr_val to [ebp-4]
	mov	edx, [ebp-4]		; edx as temp
	mov	byte[eax+ecx], dl	; store lowest byte of curr_vall to array cell

	add	ecx, 1			; inc counter
	cmp	ecx, 256		; repeat 256x
	jne	lop1
;end of lop1

	mov	ecx, 4			; clean up FPU stack
lop3:	fcomip	st0			; (4 registers to pop)
	loop	lop3

	leave				; destroy stack pointer
	ret
;enf of makelutc()