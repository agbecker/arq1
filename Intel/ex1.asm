		.model small
		.stack

		.data
	filename	db	'teste.txt', 0
	numero		db 	'456', 0

		.code
		.startup

		mov bx, offset numero
		call atoi
		mov bx, offset filename
		call printf_s

		.exit


; atoi: String (bx) -> Inteiro (ax)
; Obj.: recebe uma string e transforma em um inteiro
; Ex:
; lea bx, String1 (Em que String1 é db "2024",0)
; call atoi
; -> devolve o numero 2024 em ax
atoi	proc near

		; A = 0;
		mov		ax,0
		
atoi_2:
		; while (*S!='\0') {
		cmp		byte ptr[bx], 0
		jz		atoi_1

		; 	A = 10 * A
		mov		cx,10
		mul		cx

		; 	A = A + *S
		mov		ch,0
		mov		cl,[bx]
		add		ax,cx

		; 	A = A - '0'
		sub		ax,'0'

		; 	++S
		inc		bx
		
		;}
		jmp		atoi_2

atoi_1:
		; return
		ret

atoi	endp

; printf_s: String (bx) -> void
; Obj.: dado uma String, escreve a string na tela
; Ex.:
; lea bx, String1 (em que String 1 é db "Java melhor linguagem",CR,LF,0)
; call printf_s
; -> Imprime o fato na tela e quebra linha
; (Nao sei o que acontece se colocar so o LF ou so o CR, da uma
; brincada ai pra descobrir)
printf_s	proc	near

;	While (*s!='\0') {
	mov		dl,[bx]
	cmp		dl,0
	je		ps_1

;		putchar(*s)
	push	bx
	mov		ah,2
	int		21H
	pop		bx

;		++s;
	inc		bx
		
;	}
	jmp		printf_s
		
ps_1:
	ret
	
printf_s	endp


		end