		.model small
		.stack

		.data
	CR 			equ	0Dh
	LF			equ 0Ah

	file_in		db	'a.in', 0
	file_out	db  'a.out', 0
	handle_in	dw 	0
	handle_out	dw	0
	string 		db	50 dup (0)
	gotten_char db 	0
	index		dw  0
	num_linhas	dw	0

		.code
		.startup
		mov num_linhas, 0

		lea dx, file_in
		call fopen
		lea dx, file_out
		call fcreate

		call read_line
		lea bx, string
		call printf_s

		call read_line
		lea bx, string
		call printf_s

		.exit



; fopen: String (dx) -> File* (handle_in) Boolean (CF)		(Passa o File* para o ax tambem, mas por algum motivo ele move pro bx)
; Obj.: Dado o caminho para um arquivo, devolve o ponteiro desse arquivo e define CF como 0 se o processo deu certo
; Ex.:
; lea dx, fileName		(em que fileName eh "temaDeCasa/feet/feet1.png",0) (Talvez a orientacao das barras varie com o sistema operacional, na duvida coloca tudo dentro de WORK pra poder usar so o nome do arquivo)
; call fopen
; -> bx recebe a imagem e CF (carry flag) nao ativa
; ou -> bx recebe lixo e CF ativa
fopen	proc	near
	mov		al,0
	mov		ah,3dh
	int		21h
	mov		handle_in,ax
	ret
fopen	endp

; fcreate: String (dx) -> File* (bx) Boolean (CF)
; Obj.: Dado o caminho para um arquivo, cria um novo arquivo com dado nome em tal caminho e devolve seu ponteiro, define CF como 0 se o processo deu certo
; Ex.:
; lea dx, fileName		(em que fileName eh "fatos/porQueChicoEhOMelhor.txt",0) (Talvez a orientacao das barras varie com o sistema operacional, na duvida coloca tudo dentro de WORK pra poder usar so o nome do arquivo)
; call fcreate
; -> bx recebe o txt e CF (carry flag) nao ativa
; ou -> bx recebe lixo e CF ativa
fcreate	proc	near
	mov		cx,0
	mov		ah,3ch
	int		21h
	mov		handle_out,ax
	ret
fcreate	endp

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


; getChar: File* (bx) -> Char (dl) Inteiro (AX) Boolean (CF)
; Obj.: Dado um arquivo, devolve um caractere, a posicao do cursor e define CF como 0 se a leitura deu certo (diferente do getchar() do C, mais pra um getc(FILE*))
; Ex.:
; mov bx, filePtr	(em que filePtr eh um ponteiro retornado por fopen/fcreate)
; call getChar
; -> char em dl e cursor em AX se CF == 0
; senao, deu ruim
getChar	proc	near
	mov		ah,3fh
	mov		cx,1
	lea		dx, gotten_char
	int		21h
	mov		dl, gotten_char
	ret
getChar	endp

; Lê linha do arquivo
read_line proc	near
	mov	index, 0
	mov dl, 0

	loop_readline:
		mov bx, handle_in
		call getChar
		
		;; Verifica final de arquivo
		;cmp ax, 0
		;je EOF

		; Verifica final de linha
		cmp dl, CR
		je EOL
		cmp dl, LF
		je EOL

		mov bx, index
		add bx, offset string
		mov [bx], dl
		inc index
		jmp loop_readline

	EOL:
		mov bx, handle_in
		call getChar
		cmp dl, CR
		je EOL2
		cmp dl, LF
		je EOL2

		; Caso tenha lido o próximo caractere e não seja um de quebra de linha,
		; move o ponteiro de arquivo uma posição para trás
		call moveBack
	EOL2:
		inc num_linhas
		mov bx, index
		add bx, offset string
		mov [bx], 0

		; Apenas para impressao
		mov [bx], CR
		inc bx
		mov [bx], LF
		inc bx
		mov [bx], 0

		ret

	;EOF:
	;	mov bx, index
	;	add bx, offset string
	;	mov [bx], 0
	;	ret
read_line endp	

; Retorna o ponteiro de arquivo em um caractere
; File* (bx) -> Null
moveBack proc	near
	mov ah, 42h
	mov al, 1
	mov cx, 0
	mov dx, -1
	int 21h
	ret
moveBack endp

		end