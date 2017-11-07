;contrast.asm

section .data
imax:	dq 255.0
imax2:	dq 127.5
imin:	dq 0.0

section .text
global	contrast
global	makelutc

; void contrast(SDL_Surface *srf, double a, int *hist_in, int *hist_out)
contrast: ;RDI, RSI, RDX
	push	rbp
	mov	rbp, rsp
	sub	rsp, 256		; lut array, 4 bytes per int * 256 colors

	push	r12
	push	r13
	push	r14

;	int	3			; debug interruption

	mov	r12, rdi		; r12 = srf_ptr
	mov	r13, rsi		; r13 = hist_in ptr
	mov	r14, rdx		; r14 = hist_out ptr

	lea	rdi, [rbp-256]		; 'char *t_lut' ptr to rdi, 'double a' is already in xmm0
	call	makelutc		; let's make LUT

	xor	rax, rax		; ensure rax is zero
	mov	eax, [r12+20]		; +20	height (int)
	imul	eax, [r12+24]		; +24	pitch (int),	eax = height*pitch
	mov	r12, [r12+32]		; +32	pixels ptr,	r12 = pixel_ptr

	lea	rdi, [rbp-256]		; rdi = lut_array ptr
	xor	r11, r11		; r11 = 0, lop2 counter, BUG WAS HERE !!!!!!!!!
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
;end of contrast()

; void makelutc(char *t_lut, double a)
makelutc:
;	int	3			; debug interruption

	push	rbp
	mov	rbp, rsp
	sub	rsp, 8			; rcx (counter) in memory, local variable

	xor	rcx, rcx		; rcx = 0
	mov	rax, rdi		; rax = t_lut
	fld	qword[imin]		; st0 = imin
	fld	qword[imax2]		; st0 = imax2, st1 = imin
	fld	qword[imax]		; st0 = imax, st1 = imax2, st2 = imin
	sub	rsp, 8
	movq	qword[rsp], xmm0
	fld	qword[rsp]		; st0 = a, st1 = imax, st2 = imax2, st3 = imin
	add	rsp, 8

lop1:
	mov	[rbp-8], rcx		; rcx (counter) to memory
	fild	qword[rbp-8]		; st0 = curr_val, st1 = a, st2 = imax, st3 = imax2, st4 = imin
	fsub	st3			; i - imax2
	fmul	st1			; a*(i - imax2)
	fadd	st3			; a*(i - imax2) + imax2

	fcomi	st0, st2		; if curr_val > 255 then 255
	fcmovnb st0, st2
	fcomi	st0, st4		; if curr_val < 0 then 0
	fcmovb	st0, st4

	fistp	qword[rbp-8]		; pop curr_val to [rbp-4]
	mov	rdx, [rbp-8]		; edx as temp
	mov	byte[rax+rcx], dl	; store lowest byte of curr_vall to array cell

	add	rcx, 1			; inc counter
	cmp	rcx, 256		; repeat 256x
	jne	lop1
;end of lop1

	mov	rcx, 4			; clean up FPU stack
lop3:	fcomip	st0			; (4 registers to pop)
	loop	lop3

	leave				; destroy stack pointer
	ret
;enf of makelutc()