		.model small
		.stack

		.data
	CR 			equ	0Dh
	LF			equ 0Ah
	SPACE		equ	20h
	TAB			equ 09h

	; Enums
	AGUARDA_NUMERO	equ	0
	AGUARDA_NOV		equ 1 ; Aguarda numero ou virgula
	AGUARDA_VIRGULA equ 2
	AGUARDA_FIM_LINHA	equ	3

	file_in		db	'in1.txt', 0
	file_out	db  'a.out', 0
	handle_in	dw 	0
	handle_out	dw	0
	string 		db	50 dup (0)
	string_len	dw	0
	gotten_char db 	0
	index		dw  0
	num_linhas	dw	0
	tensao		dw  3 dup (-1)
	temp_char	db  0
	modo_parse	db	0
	volt_index  dw 	0
	arquivo_valido 	db 	1

	; Mensagens
	msg_inv_file	db	'Arquivo com erro', CR, LF, 0

		.code
		.startup
		; Inicializacoes
		mov num_linhas, 0

		lea dx, file_in
		call fopen
		lea dx, file_out
		call fcreate

		; Enquanto nao for EOF
		main_loop:
			; Testa fim do arquivo
			call getChar
			cmp ax, 0
			je EOF
			cmp dl, 'f'
			je EOF
			cmp dl, 'F'
			je EOF
			call moveBack ; Retorna um caractere
			
			; Le linha
			call read_line
			call parse_line

			; Testa impressao
			lea bx, string
			call printf_s
			jmp main_loop

		EOF:
			mov bx, handle_in
			call fclose
			mov bx, handle_out
			call fclose


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

; fclose: File* (bx) -> Boolean (CF)
; Obj.: evitar um memory leak fechando o arquivo
; Ex.:
; mov bx, filePtr	(em que filePtr eh um ponteiro retornado por fopen/fcreate)
; call fclose
; -> Se deu certo, CF == 0
; (Recomendo zerar o filePtr pra voce nao fazer merda)
fclose	proc	near
	mov		ah,3eh
	int		21h
	ret
fclose	endp

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
	mov		bx, handle_in
	mov		ah, 3fh
	mov		cx, 1
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
		call getChar
		
		;; Verifica final de arquivo
		cmp ax, 0
		je EOF_read

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

		mov ax, index
		mov string_len, ax
		ret

	EOF_read:
		mov bx, index
		add bx, offset string
		mov [bx], 0
		ret
read_line endp	

; Retorna o ponteiro de arquivo em um caractere
; File* (bx) -> Null
moveBack proc	near
	mov ah, 42h
	mov al, 1
	mov bx, handle_in
	mov cx, -1
	mov dx, -1
	int 21h
	ret
moveBack endp

; Interpreta a linha salva na variavel string para validacao
parse_line proc	near
	mov index, 0
	mov modo_parse, AGUARDA_NUMERO

	loop_parse:
		mov bx, index
		add bx, offset string
		cmp modo_parse, AGUARDA_NUMERO
		jne parse1
		call verif_numero
		jmp next_parse
		
		parse1:
		cmp modo_parse, AGUARDA_NOV
		jne parse2
		call compoe_numero
		jmp next_parse
		
		parse2:
		cmp modo_parse, AGUARDA_VIRGULA
		jne parse3
		call espera_virgula
		jmp next_parse
		
		parse3:
		call espera_endl

		next_parse:
		inc index
		mov ax, index
		cmp ax, string_len
		je end_parse
		jmp loop_parse

	end_parse:
	ret
parse_line endp

; Ignora espaços em branco até achar dígito numérico.
; Se achar outro caractere, a linha tem erro
verif_numero proc near
	mov ax, [bx]
	cmp al, SPACE
	jne verif1
	ret

	verif1:
	cmp al, TAB
	jne verif2
	ret

	verif2:
	cmp al, '0'
	jb verif_invalido
	cmp al, '9'
	ja verif_invalido
	; Se for um digito numerico
	mov volt_index, 0
	mov tensao, ax
	sub tensao, '0'
	mov modo_parse, AGUARDA_NOV
	ret

	verif_invalido:
	mov arquivo_valido, 0

	lea bx, msg_inv_file
	call printf_s
	ret

verif_numero endp

; Computa valor da tensao a partir dos numeros informados na linha
compoe_numero proc near
	mov ax, [bx]
	; Caso seja espaco branco, o proximo deve ser virgula
	cmp al, TAB
	je compoe_space
	cmp al, SPACE
	je compoe_space

	; Caso seja virgula, encerra o numero
	cmp al, ','
	je compoe_virgula

	; Caso não seja número, é inválido
	cmp al, '0'
	jb compoe_invalido
	cmp al, '9'
	ja compoe_invalido

	; Caso seja numero, adiciona à tensão atual
	mov temp_char, al
	sub temp_char, '0'
	mov bx, volt_index
	add bx, offset tensao
	mov ax, [bx]
	mov cx, 10
	mul cx
	add al, temp_char
	mov [bx], ax
	ret

	compoe_space:
	mov modo_parse, AGUARDA_VIRGULA
	ret

	compoe_virgula:
	; Se já tiver dado valor às três tensões
	cmp volt_index, 4
	je compoe_virgula2
	; Senão
	add volt_index, 2
	mov modo_parse, AGUARDA_NUMERO
	ret

	compoe_virgula2:
	mov modo_parse, AGUARDA_FIM_LINHA
	ret

	compoe_invalido:
	mov arquivo_valido, 0

	lea bx, msg_inv_file
	call printf_s
	ret
	

compoe_numero endp

; Aguarda até achar uma vírgula
espera_virgula proc near
	mov ax, [bx]
	; Caso seja espaco branco apenas prossegue
	cmp al, TAB
	je virgula_space
	cmp al, SPACE
	je virgula_space

	; Se nao for virgula, é invalido
	cmp al, ','
	jne virgula_invalido

	; Se já tiver dado valor às três tensões
	cmp volt_index, 4
	je espera_virgula2
	; Senão
	add volt_index, 2
	mov modo_parse, AGUARDA_NUMERO
	ret

	espera_virgula2:
	mov modo_parse, AGUARDA_FIM_LINHA
	ret

	virgula_space:
	ret

	virgula_invalido:
	mov arquivo_valido, 0

	lea bx, msg_inv_file
	call printf_s
	ret

espera_virgula endp

; Espera fim da linha. Qualquer coisa além de espaço em branco é inválida
espera_endl proc near
	mov ax, [bx]
	cmp al, SPACE
	je endl_space
	cmp al, TAB
	je endl_space

	mov arquivo_valido, 0

	lea bx, msg_inv_file
	call printf_s
	ret

	endl_space:
	ret

espera_endl endp

		end