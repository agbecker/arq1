		.model small
		.stack

		.data
	; Chars especiais
	CR 			equ	0Dh
	LF			equ 0Ah
	SPACE		equ	20h
	TAB			equ 09h

	; Enums
	AGUARDA_NUMERO	equ	0
	AGUARDA_NOV		equ 1 ; Aguarda numero ou virgula
	AGUARDA_VIRGULA equ 2
	AGUARDA_FIM_LINHA	equ	3

	AGUARDA_HIFEN	equ	0
	AGUARDA_PARAM	equ 1
	LENDO_PARAM		equ 2

	; Constantes
	v_valida_min	equ	0
	v_valida_max	equ	499
	delta_v			equ 10
	ref_baixa		equ 10

	; Variáveis
	file_in		db	'a.in', 17 dup (0)
	file_out	db  'a.out', 16 dup (0)
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
	linha_valida 	db 	1
	cmd_valido	db	1
	aux_str		db	15 dup (0)
	tempo		db	9 dup (0)
	horas		dw	0
	minutos		dw  0
	segundos	dw	0
	param_flag	db	0

	vmin		dw	0
	vmax 		dw 	0
	v_ref		dw  127

	num_regular	dw	0
	num_baixa	dw 	0

	sw_n	dw	0 							; Usada dentro da funcao sprintf_w
	sw_f	db	0							; Usada dentro da funcao sprintf_w
	sw_m	dw	0							; Usada dentro da funcao sprintf_w
	FileBuffer	db 	0

	cmdline		db	40 dup (0)
	cmd_len		dw	0
	

	; Mensagens
	msg_linha_1		db	'Linha ', 0
	msg_linha_2		db	' invalida: ', 0
	line_break		db 	CR, LF, 0
	msg_tempo_total	db	'Tempo total de medicoes: ', 0
	msg_tempo_regular	db	'Tempo de tensao adequada: ', 0
	msg_tempo_baixo	db	'Tempo sem tensao: ', 0
	msg_falta_i		db	'Opcao [-i] sem parametro', 0
	msg_falta_o		db	'Opcao [-o] sem parametro', 0
	msg_falta_v		db	'Opcao [-v] sem parametro', 0
	msg_v_invalido	db	'Parametro da opcao [-v] deve ser 127 ou 220', 0

		.code
		.startup
		; Le CMD
		push ds ; Salva as informações de segmentos
		push es
		mov ax,ds ; Troca DS com ES para poder usa o REP MOVSB
		mov bx,es
		mov ds,bx
		mov es,ax
		mov si,80h ; Obtém o tamanho do string da linha de comando e coloca em CX
		mov ch,0
		mov cl,[si]
		mov cmd_len,cx ; Salva o tamanho do string em cmd_len, para uso futuro

		mov si,81h ; Inicializa o ponteiro de origem
		lea di,CMDLINE ; Inicializa o ponteiro de destino
		rep movsb
		pop es ; retorna as informações dos registradores de segmentos
		pop ds

		call parse_cmd
		cmp cmd_valido, 0
		je end_main

		; Inicializacoes
		mov num_linhas, 0
		mov v_ref, 127

		mov bx, v_ref
		mov vmin, bx
		sub vmin, delta_v
		mov vmax, bx
		add vmax, delta_v

		lea dx, file_in
		call fopen

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
			inc num_linhas
			call read_line
			mov linha_valida, 1
			call parse_line
			call valida_tensoes

			; Verifica validade da linha
			cmp linha_valida, 1
			je imprime
			call informa_linha_errada
			jmp main_loop

			imprime:
			jmp main_loop

		EOF:
			mov bx, handle_in
			call fclose
			
			cmp arquivo_valido, 1
			jne end_main
			call escreve_relatorio

		end_main:

		.exit



; fopen: String (dx) -> File* (handle_in) Boolean (CF)		(Passa o File* para o ax tambem, mas por algum motivo ele move pro bx)
; Obj.: Dado o caminho para um arquivo, devolve o ponteiro desse arquivo e define CF como 0 se o processo deu certo
fopen	proc	near
	mov		al,0
	mov		ah,3dh
	int		21h
	mov		handle_in,ax
	ret
fopen	endp

; fcreate: String (dx) -> File* (bx) Boolean (CF)
; Obj.: Dado o caminho para um arquivo, cria um novo arquivo com dado nome em tal caminho e devolve seu ponteiro, define CF como 0 se o processo deu certo
fcreate	proc	near
	mov		cx,0
	mov		ah,3ch
	int		21h
	mov		handle_out,ax
	ret
fcreate	endp

; fclose: File* (bx) -> Boolean (CF)
; Obj.: evitar um memory leak fechando o arquivo
fclose	proc	near
	mov		ah,3eh
	int		21h
	ret
fclose	endp

; printf_s: String (bx) -> void
; Obj.: dado uma String, escreve a string na tela
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
		jmp read_line_end

	EOF_read:
		mov bx, index
		add bx, offset string
		mov [bx], 0
		jmp read_line_end

	read_line_end:
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
	mov volt_index, 0

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
	mov ah, 0
	mov bx, volt_index
	add bx, offset tensao
	mov [bx], ax
	sub [bx], '0'
	mov modo_parse, AGUARDA_NOV
	ret

	verif_invalido:
	mov arquivo_valido, 0
	mov linha_valida, 0

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
	;mov ah, 0
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
	mov linha_valida, 0

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
	mov linha_valida, 0

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
	mov linha_valida, 0

	endl_space:
	ret

espera_endl endp


; Verifica que as três tensões medidas são válidas,
; e se são adequadas ou baixas
valida_tensoes proc near
	mov ax, 0 ; DX será usado para anotar se as tensões estão na faixa
	mov volt_index, -2

	loop_valida_tensoes:
		add volt_index, 2
		cmp volt_index, 6
		je end_valida_tensoes



		shl ax, 1
		mov bx, volt_index
		add bx, offset tensao
		; Se for invalida
		cmp [bx], v_valida_min
		jl tensao_invalida
		cmp [bx], v_valida_max
		jg tensao_invalida

		; Se for baixa
		cmp [bx], ref_baixa
		ja loop_vt1
		inc al
		jmp loop_valida_tensoes

		; Se for regular
		loop_vt1:
		mov cx, vmin
		cmp [bx], cx
		jb loop_valida_tensoes
		mov cx, vmax
		cmp [bx], cx
		ja loop_valida_tensoes
		inc ah
		jmp loop_valida_tensoes

		tensao_invalida:
		mov arquivo_valido, 0
		mov linha_valida, 0

		
		ret

	end_valida_tensoes:
		cmp ah, 7
		jne end_vt1
		inc num_regular

		end_vt1:
		cmp al, 7
		jne end_vt2
		inc num_baixa

		end_vt2:
		ret

valida_tensoes endp

; Imprime que há erro na última linhda lida
informa_linha_errada proc near
	lea bx, msg_linha_1
	call printf_s

	mov ax, num_linhas
	lea bx, aux_str
	call sprintf_w
	lea bx, aux_str
	call printf_s

	lea bx, msg_linha_2
	call printf_s
	lea bx, string
	call printf_s

	ret
informa_linha_errada endp

; sprintf_w: Inteiro (ax) String (bx) -> void
; Obj.: dado um numero e uma string, transforma o numero em ascii e salva na string dada, quase um itoa()
sprintf_w	proc	near

;void sprintf_w(char *string, WORD n) {
	mov		sw_n,ax

;	k=5;
	mov		cx,5
	
;	m=10000;
	mov		sw_m,10000
	
;	f=0;
	mov		sw_f,0
	
;	do {
sw_do:

;		quociente = n / m : resto = n % m;	// Usar instru��o DIV
	mov		dx,0
	mov		ax,sw_n
	div		sw_m
	
;		if (quociente || f) {
;			*string++ = quociente+'0'
;			f = 1;
;		}
	cmp		al,0
	jne		sw_store
	cmp		sw_f,0
	je		sw_continue
sw_store:
	add		al,'0'
	mov		[bx],al
	inc		bx
	
	mov		sw_f,1
sw_continue:
	
;		n = resto;
	mov		sw_n,dx
	
;		m = m/10;
	mov		dx,0
	mov		ax,sw_m
	mov		bp,10
	div		bp
	mov		sw_m,ax
	
;		--k;
	dec		cx
	
;	} while(k);
	cmp		cx,0
	jnz		sw_do

;	if (!f)
;		*string++ = '0';
	cmp		sw_f,0
	jnz		sw_continua2
	mov		[bx],'0'
	inc		bx
sw_continua2:


;	*string = '\0';
	mov		byte ptr[bx],0
		
;}
	ret
		
sprintf_w	endp


; Recebe segundos decorridos em AX
; Retorna string com o tempo a ser escrito em 'tempo'
calcula_tempo	proc 	near
	; Calcula horas, minutos e segundos
	mov bx, ax ; copia ax para bx

	; Ax e Bx têm o número total de segundos
	mov dx, 0
	mov cx, 3600

	div cx ; Divide Dx:Ax por 3600
	mov horas, ax ; Ax tem o numero de horas
	mov bx, dx ; Dx tem o resto da divisão

	mov ax, bx
	; Ax e Bx têm o número restante de segundos
	mov dx, 0
	mov cx, 60
	div cx
	mov minutos, ax
	mov segundos, dx

	; Escreve a string
	mov index, 0
	cmp horas, 0
	je escreve_minuto
	mov ax, horas
	mov bx, index
	add bx, offset tempo
	; Coloca 0 no começo, se necessario
	cmp horas, 10
	jnb escreve_hora1
	mov [bx], '0'
	inc bx
	escreve_hora1:
	call sprintf_w
	add index, 2
	mov bx, index
	add bx, offset tempo
	mov [bx], ':'
	inc index

	escreve_minuto:
	cmp horas, 0
	jne escreve_min0
	cmp minutos, 0
	je escreve_segundo

	escreve_min0:
	mov ax, minutos
	mov bx, index
	add bx, offset tempo
	; Coloca 0 no começo, se necessario
	cmp minutos, 10
	jnb escreve_min1
	mov [bx], '0'
	inc bx
	escreve_min1:
	call sprintf_w
	add index, 2
	mov bx, index
	add bx, offset tempo
	mov [bx], ':'
	inc index

	escreve_segundo:
	mov ax, segundos

	mov bx, index
	add bx, offset tempo
	; Coloca 0 no começo, se necessario
	cmp segundos, 10
	jnb escreve_seg1
	mov [bx], '0'
	inc bx
	escreve_seg1:
	call sprintf_w

	ret	

calcula_tempo	endp
	
; setChar: Char (dl) -> Inteiro (ax) Boolean (CF)
; Obj.: Dado um arquivo e um caractere, escreve esse caractere no arquivo e devolve a posicao do cursor e define CF como 0 se a leitura deu certo
setChar	proc	near
	mov 	bx, handle_out
	mov		ah,40h
	mov		cx,1
	mov		FileBuffer,dl
	lea		dx,FileBuffer
	int		21h
	ret
setChar	endp	

; Escreve string no arquivo de saída
; Recebe string em Bx
write_to_file proc near
	
	loop_write:
	mov index, bx
	mov cx, [bx]
	cmp cl, 0
	je end_write
	mov dl, cl
	call setChar
	mov bx, index
	inc bx
	jmp loop_write

	end_write:
	ret
write_to_file endp

; Cria arquivo de saída e escreve relatório nele
; Também escreve informações relevantes na tela
escreve_relatorio	proc	near

	; Cria arquivo
	lea dx, file_out
	call fcreate

	; Imprime na tela
	mov ax, num_linhas
	call calcula_tempo
	lea bx, msg_tempo_total
	call printf_s
	lea bx, tempo
	call printf_s
	lea bx, line_break
	call printf_s
	
	; Escreve no arquivo
	mov ax, num_linhas
	call calcula_tempo
	lea bx, msg_tempo_total
	call write_to_file
	lea bx, tempo
	call write_to_file
	lea bx, line_break
	call write_to_file

	mov ax, num_regular
	call calcula_tempo
	lea bx, msg_tempo_regular
	call write_to_file
	lea bx, tempo
	call write_to_file
	lea bx, line_break
	call write_to_file

	mov ax, num_baixa
	call calcula_tempo
	lea bx, msg_tempo_baixo
	call write_to_file
	lea bx, tempo
	call write_to_file
	lea bx, line_break
	call write_to_file

	mov bx, handle_out
	call fclose

	ret
escreve_relatorio 	endp

; Interpreta instrucoes da linha de comando
parse_cmd proc near
	mov modo_parse, AGUARDA_HIFEN
	lea bx, CMDLINE

	loop_parse_cmd:
		cmp cmd_valido, 1
		je executa_parse_cmd
		ret

		executa_parse_cmd:
		mov ax, [bx]

		cmp al, 0
		je end_parse_cmd

		cmp al, SPACE
		je next_parse_cmd

		cmp modo_parse, AGUARDA_HIFEN
		jne cmd1

		call pega_identificador
		jmp next_parse_cmd

		cmd1:
		call le_parametro

		next_parse_cmd:
		inc bx
		jmp loop_parse_cmd

		end_parse_cmd:
		cmp modo_parse, AGUARDA_HIFEN
		je end_pc1
		call le_parametro

		end_pc1:

	ret
parse_cmd endp

; Lê identificador -i, -o ou -v e passa param_flag
pega_identificador proc near
	inc bx
	mov ax, [bx]
	mov param_flag, al
	mov modo_parse, AGUARDA_PARAM
	ret
pega_identificador endp

; Le valor que segue -i, -o ou -v
le_parametro proc near

	cmp modo_parse, AGUARDA_PARAM
	je modo_aguarda_param

	modo_le_param:
	cmp al, '-'
	je encerra_param
	cmp al, 0
	je encerra_param
	mov cx, bx
	lea bx, string
	add bx, index
	mov [bx], al
	inc index
	mov bx, cx
	ret

	modo_aguarda_param:
	cmp al, SPACE
	jne aguarda_par1
	ret

	aguarda_par1:

	mov modo_parse, LENDO_PARAM

	cmp al, '-' 
	je erro_param
	cmp al, 0
	je erro_param
	mov index, 1
	mov string, al
	ret

	erro_param:
	mov cmd_valido, 0
	call informa_parametro_invalido
	ret

	encerra_param:
	mov modo_parse, AGUARDA_HIFEN
	dec bx
	
	cmp param_flag, 'i'
	jne encerra1
	call set_input
	jmp end_encerra

	encerra1:
	cmp param_flag, 'o'
	jne encerra2
	call set_output
	jmp end_encerra

	encerra2:
	call set_voltage

	end_encerra:
	ret

le_parametro endp

informa_parametro_invalido proc near

	cmp param_flag, 'i'
	jne informa_pi1
	lea bx, msg_falta_i
	call printf_s
	ret

	informa_pi1:
	cmp param_flag, 'o'
	jne informa_pi2
	lea bx, msg_falta_o
	call printf_s
	ret

	informa_pi2:
	lea bx, msg_falta_v
	call printf_s
	ret

informa_parametro_invalido endp

set_input proc near
	mov cx, bx
	lea bx, string
	add bx, index
	mov [bx], 0

	mov index, 0

	loop_set_input:
	lea bx, string
	add bx, index
	mov ax, [bx]
	cmp ax, 0
	je end_set_input

	lea bx, file_in
	add bx, index
	mov [bx], ax
	inc index
	jmp loop_set_input

	end_set_input:
	mov [bx], 0

	ret

set_input endp


set_output proc near
	mov cx, bx
	lea bx, string
	add bx, index
	mov [bx], 0

	mov index, 0

	loop_set_output:
	lea bx, string
	add bx, index
	mov ax, [bx]
	cmp ax, 0
	je end_set_output

	lea bx, file_out
	add bx, index
	mov [bx], ax
	inc index
	jmp loop_set_output

	end_set_output:
	mov [bx], 0
	
	ret
set_output endp

set_voltage proc near
	mov cx, bx
	lea bx, string
	add bx, index
	mov [bx], 0
	mov index, 0
	mov ax, 0

	loop_set_volt:
	lea bx, string
	add bx, index
	cmp [bx], 0
	je break_set_volt
	mov dx, 10
	mul dl
	mov ah, 0
	mov dx, [bx]
	sub dl, '0'
	add al, dl
	inc index
	jmp loop_set_volt
	
	break_set_volt:
	mov v_ref, ax



	cmp v_ref, 127
	je end_set_volt
	cmp v_ref, 220
	je end_set_volt
	
	mov cmd_valido, 0
	lea bx, msg_v_invalido
	call printf_s

	end_set_volt:
	mov bx, cx
	ret
set_voltage endp
		end