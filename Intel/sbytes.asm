		.model small
		.stack

		.data

INP_STRING		DB	512 DUP(0)	; String a ser lida pelo prompt
INP_FILE		DB	512 DUP(?)	; Nome do arquivo de entrada

BUFFER_SIZE		EQU 1024
FILE_BUFFER		DB	BUFFER_SIZE	DUP(?)	; Buffer que salva bytes do arquivo de entrada

V_CODE			DB	64 DUP(?)	; String que armazena o código de verificação
G_CODE			DB  64 DUP(?)	; String que guarda o código de verificação calculado

V_CODE_HEX		DQ	0			; (64 bits) Código de verificação lido em -v
G_CODE_HEX		DQ	0			; (64 bits) Código calculado a partir do arquivo
MULTIPLIER		DW	1			; Multiplicador utilizado para converter os chars. em hexa

FILE_FOUND		DB 	0			; Indica se encontrou o flag '-a'
G_FOUND 		DB 	0			; Indica se encontrou o flag '-g'
V_FOUND 		DB 	0			; Indica se encontrou o flag '-v'	

HANDLE			DW	0			; Handle do arquivo de entrada

ERRO_CODIGO_INVALIDO	DB	'ERRO: cogido de flag invalido!', 0
ERRO_PATH_N_INFORMADO	DB	'ERRO: flag de arquivo (-a) nao informada!', 0
ERRO_FLAGS_OPERACAO		DB	'ERRO: nenhuma flag de operacao (-g ou -v) informada!', 0
ERRO_G_V 				DB	'ERRO: ambas as flags de operacao (-g e -v) informadas!', 0
ERRO_DUPLO_A			DB	'ERRO: mais de uma flag -a informada!', 0
ERRO_DUPLO_G			DB	'ERRO: mais de uma flag -g informada!', 0
ERRO_DUPLO_V			DB	'ERRO: mais de uma flag -v informada!', 0
ERRO_VCODE				DB	'ERRO: codigo de verificacao mal-formado!', 0
ERRO_VCODE_N_INFO		DB	'ERRO: codigo de verificacao nao informado!', 0
ERRO_OVERFLOW_VCODE		DB	'ERRO: o codigo de verificacao possui mais de 64 bits!', 0
ERRO_OVERFLOW_GCODE		DB	'ERRO: o codigo do arquivo possui mais de 64 bits!', 0
ERRO_PATH_INVALIDO		DB	'ERRO: path de arquivo invalido!', 0
ERRO_LEITURA_ARQUIVO	DB	'ERRO: erro de leitura!', 0

DIFF_CODE_MESSAGE		DB	'Codigo de verificacao INVALIDO!', 0
EQU_CODE_MESSAGE		DB	'Codigo de verificacao VALIDO!', 0

print					DB	' !', 0Ah, 0Dh, 0
endl					DB	0Ah, 0Dh, 0

		.code
		.startup

		call SetVars

		call ReadInput
		
		;lea bx, INP_STRING
		;call WriteString
		;lea bx, print
		;call WriteString

		lea bx, INP_STRING
		call ReadInpString

		;lea bx, INP_FILE
		;call WriteString
		;lea bx, print
		;call WriteString

	;
	; ----- ABERTURA DO ARQUIVO DE ENTRADA ----- ;

Open_File:
		mov		ah, 3dh
		mov 	al, 0
		lea 	dx, INP_FILE		
		int		21h
		jnc 	_save_handle

		lea		bx, ERRO_PATH_INVALIDO		; ERRO: path de arquivo invalido!
		call 	WriteString
		jmp 	Fim

	_save_handle:
		mov		HANDLE, ax 		; Salva o handle do arquivo

	;
	; ----- LEITURA DO ARQUIVO DE ENTRADA ----- ;

Read_Bytes:
		mov		ah, 3fh
		mov		bx, HANDLE
		mov		cx, BUFFER_SIZE
		lea		dx, FILE_BUFFER
		int 	21h							; BUFFER_SIZE bytes do arquivo são colocados em FILE_BUFFER
											; ax possui o número de bytes lidos com sucesso
		jnc		_check_read_bytes

		lea		bx, ERRO_LEITURA_ARQUIVO	; ERRO: erro de leitura!
		call	WriteString
		jmp		CloseFile
	
	_check_read_bytes:
		cmp		ax, 0		; ax == 0: leitura acabou
		jz		Test_G

		lea		bp, FILE_BUFFER		; bp - base (end. inicial do buffer)
		mov		si, 0				; si - índice do buffer
		lea		bx, G_CODE_HEX		; bx - base de G_CODE_HEX

	; Esgota o buffer lido:
	Calculate_GCode:
		;push	bx
		;lea		bx, print
		;mov		al, [bp+si]
		;mov		byte ptr[bx], al
		;call	WriteString				; print do byte lido
		;pop		bx

		mov		di, 0					; di - byte a ser acessado de G_CODE_HEX

		mov 	cl, [bp+si]				; cl = byte lido do arquivo
		add		byte ptr [bx], cl		; Soma o byte ao número

	_carry_on:
		jc		_verf_overflow
		jmp		_byte_step
	
	_verf_overflow:
		inc		di
		cmp		di, 7						; Se ainda cabe em 8 bytes,
		jle		_add_carry					; continua somando os carrys

		lea		bx,	ERRO_OVERFLOW_GCODE		; ERRO: o codigo do arquivo possui mais de 64 bits!
		call	WriteString
		jmp		CloseFile

	_add_carry:
		add		byte ptr [bx+di], 1			; Soma os carrys a todas as words
		jmp		_carry_on					; que devem ser alteradas

	_byte_step:
		inc		si
		dec		ax
		cmp		ax, 0
		jg		Calculate_GCode
		jmp		Read_Bytes			; Se ax chegou a 0, o buffer foi esgotado

	;
	; ----- AÇÃO PARA O CÓDIGO -g ----- ;

Test_G:
		cmp G_FOUND, 1
		jnz Test_V

		lea si, G_CODE_HEX
		call QuadToString
		lea bx, G_CODE
		call WriteString

	;
	; ----- AÇÃO PARA O CÓDIGO -v ----- ;

Test_V:
		cmp V_FOUND, 1
		jnz CloseFile
		
		;lea	bx, V_CODE
		;inc bx				; retira o '\0' inicial
		;call WriteString
		;lea bx, print
		;call WriteString

		lea		bp, G_CODE_HEX		; bp - base para G_CODE_HEX
		lea		bx, V_CODE_HEX		; bx - base de V_CODE_HEX
		mov		si, 0				; si - índice indicando a word

	Compare_Codes:
		mov		ax, [bp+si]
		sub		ax, [bx+si]
		jnz		_diff_code			; Se alguma das words for diferente, o código é diferente
		add		si, 2
		cmp		si, 8
		jz		_equ_code			; Passou por todas as words e não deu nenhum erro
		jmp		Compare_Codes		

	_diff_code:
		lea		bx, DIFF_CODE_MESSAGE
		call	WriteString				; Codigo de verificacao INVALIDO!
		jmp		CloseFile

	_equ_code:
		lea		bx, EQU_CODE_MESSAGE
		call	WriteString				; Codigo de verificacao VALIDO!

	;
	; ----- FECHA ARQUIVO DE ENTRADA ----- ;

CloseFile:
		mov 	ah, 3eh
		mov		bx, HANDLE
		int		21h

Fim:
		lea bx, endl
		call WriteString
		.exit

;
;--------------------------------------------------------------------
;Função SetVars: Inicializa variáveis
;--------------------------------------------------------------------
SetVars		proc	near

		mov FILE_FOUND, 0
		mov G_FOUND, 0
		mov V_FOUND, 0

		lea bp, V_CODE_HEX
		mov word ptr[bp], 0
		mov word ptr[bp+2], 0
		mov word ptr[bp+4], 0
		mov word ptr[bp+6], 0
		mov MULTIPLIER, 1

		lea bp, G_CODE_HEX
		mov word ptr[bp], 0
		mov word ptr[bp+2], 0
		mov word ptr[bp+4], 0
		mov word ptr[bp+6], 0

		lea bp, G_CODE
		mov byte ptr[bp+16], 0		; Delimitador 

		ret

SetVars		endp

;
;--------------------------------------------------------------------
;Função ReadInput: Lê string de entrada do prompt
;--------------------------------------------------------------------
ReadInput	proc	near

		; OBS: no início do programa:
		; DS - aponta para o segmento de dados
		; ES - aponta para o segmento em que se encontra a string (PSP)

		push 	ds 				; Salva as informações de segmentos
		push 	es

		mov ax, ds
		mov bx, es
		mov ds, bx				; Altera DS (src da string)
		mov es, ax				; Altera ES (dst da string)
		;xchg ds, es

		mov 	si, 80h
		mov 	ch, 0
		mov 	cl, [si] 			; Obtém o tamanho do string e coloca em CX

		mov 	si, 81h		 		; Inicializa o ponteiro de origem,
		lea 	di, INP_STRING 		; Inicializa o ponteiro de destino (altera ES)

		rep 	movsb				; Transfere a string

		pop 	es					; Devolve as informações de segmentos
		pop 	ds

		mov 	byte ptr [di], 0	; Insere o caractere '\0' no fim da string
		
		;lea	bx, INP_STRING
		;call	StrTok				; Elimina caracteres desnecessários

		ret

ReadInput	endp

;
;--------------------------------------------------------------------
; Função ReadInpString: Lê a string salva em memória procurando 
; pelas instruções '-a', '-g' e/ou '-v'
; - Entrada: BX - ponteiro para a string
;
; OBS: É ASSUMIDO QUE, APÓS O NOME DO ARQUIVO OU DO CÓDIGO DE 
; VERIFICAÇÃO, HÁ PELO MENOS UM CHAR <= ' ' QUE O SEPARA DA PRÓXIMA
; FLAG DE INSTRUÇÃO
;
; Ex: sbytes -a file.txt -g
; (Out): [código do arquivo file.txt]  (ok!)
;
; Ex: sbytes -a file-g.txt
; (Out): ERRO: nenhuma flag de operacao (-g ou -v) informada!
; - O nome do path salvo pelo programa, neste caso, seria "file-g.txt"
;
; Ex: sbytes -a file.txt-g
; (Out): ERRO: nenhuma flag de operacao (-g ou -v) informada!
; - O nome do path salvo pelo programa, neste caso, seria "file.txt-g"
;
; OBS: SÓ É LIDA A PRIMEIRA PALAVRA INFORMADA APÓS -a e -v
;
; Ex: sbytes (dummy text) -a   file.txt (dummy text) -v   00001 (dummy text)
; (Out): [Código de verificação (IN)VÁLIDO]
; - path : 'file.txt'
; - vcode: '1' (os '0's à esquerda são ignorados)
;--------------------------------------------------------------------
ReadInpString	proc	near

RIS_rchar:
		mov		dl, [bx]		; Lê caractere
		inc		bx				; Passa para o prox. caractere
		cmp		dl, 0
		jnz		RIS_proc

		; --------------------- ;
		; Verificação de erros: ;
		; --------------------- ;

_RIS_Verifica_Erros:
		cmp 	FILE_FOUND, 0			; ERRO: flag de arquivo (-a) nao informada! 
		jne		_ERRO_FLAGS_OPERACAO
		lea		bx, ERRO_PATH_N_INFORMADO
		call 	WriteString
		jmp 	Fim

_ERRO_FLAGS_OPERACAO:
		mov 	ah, 0
		mov		al, G_FOUND
		or 		al, V_FOUND				; ERRO: nenhuma flag de operacao (-g ou -v) informada!
		cmp		al, 0
		jne		Ret_RIS
		lea		bx, ERRO_FLAGS_OPERACAO
		call 	WriteString
		jmp 	Fim

Ret_RIS:
		ret						; Se for o caractere final, retorna

RIS_proc:
		cmp		dl, '-'			
		jnz		RIS_rchar		; Se não for '-', volta a procurar

		mov		dl, [bx]		; Lê caractere após '-'
		inc		bx

		cmp		dl, 'g'
		jz		SetMode			; -g: Seta o modo para ler o arquivo de bytes
		cmp		dl, 'a'
		jz		ReadInpFile		; -a: Ler arquivo de entrada
		cmp		dl, 'v'
		jz		ReadVCode		; -v: Ler código de verificação

		lea 	bx, ERRO_CODIGO_INVALIDO		; Se não for nenhum dos três códigos,
		call 	WriteString						; avisa que o cógido é inválido e
		jmp 	Fim								; encerra o programa

;
; --------------------------- ;
; --- FLAG ENCONTRADA: -g --- ;
; --------------------------- ;
SetMode:
		cmp		G_FOUND, 0
		jz		_Check_V
		lea 	bx, ERRO_DUPLO_G		; A flag -g foi encontrada mais de uma vez
		call 	WriteString				
		jmp 	Fim						

_Check_V:
		cmp		V_FOUND, 0
		jz		_Write_G
		lea 	bx, ERRO_G_V			; Flags -g e -v encontradas simultaneamente
		call 	WriteString				
		jmp 	Fim		

_Write_G:
		inc 	G_FOUND					; Se G == 0 e V == 0, G = 1

		jmp 	RIS_rchar

;
; --------------------------- ;
; --- FLAG ENCONTRADA: -a --- ;
; --------------------------- ;
ReadInpFile:
		cmp 	FILE_FOUND, 0
		jz		_inc_file_found
		lea		bx, ERRO_DUPLO_A		; A flag -a foi encontrada mais de uma vez
		call	WriteString
		jmp 	Fim

	_inc_file_found:
		inc		FILE_FOUND		; Marca arquivo como encontrado
		lea		di, INP_FILE	; O Reg. di possui o endereço da string do path do arquivo
_skip_spaces_a:
		mov		dl, [bx]		; Pula caracteres irrelevantes
		inc		bx
		cmp		dl, ' '
		jle		_skip_spaces_a
		dec		bx				; O primeiro caractere > ' ' é relevante
_Rep_RIF:
		mov		dl, [bx]					
		cmp		dl, 0				; O path pode delimitar o fim da string de entrada
		jz		_end_RIF			
		cmp		dl, ' '				; O path é dado por uma palavra: acaba com um char <= ' '
		jle		_end_RIF	
		
		mov 	byte ptr [di], dl	; Se não, salva na string do path do arquivo
		inc		di
		inc		bx
		jmp		_Rep_RIF

_end_RIF:
		mov 	byte ptr [di], 0			; Insere o caractere '\0' no fim da string

		;push	bx
		;lea bx, INP_FILE
		;call WriteString
		;lea bx, print
		;call WriteString
		;pop		bx

		jmp 	RIS_rchar					; Volta a ler a string

;
; --------------------------- ;
; --- FLAG ENCONTRADA: -v --- ;			 
; --------------------------- ;			
ReadVCode:
		cmp		V_FOUND, 0
		jz		_Check_G
		lea 	bx, ERRO_DUPLO_V		; A flag -v foi encontrada mais de uma vez
		call 	WriteString				
		jmp 	Fim						

_Check_G:
		cmp		G_FOUND, 0
		jz		_Write_V
		lea 	bx, ERRO_G_V			; Flags -g e -v encontradas simultaneamente
		call 	WriteString				
		jmp 	Fim		

_Write_V:
		inc 	V_FOUND					; Se V == 0 e G == 0, V = 1

_skip_spaces_v:
		mov		dl, [bx]		; Pula caracteres irrelevantes
		inc		bx
		cmp		dl, 0
		jz		_continue_v
		cmp		dl, ' '
		jle		_skip_spaces_v
_continue_v:
		dec		bx				; O primeiro caractere > ' ' é relevante

		mov		al, 0			; al: número de '0's iniciais do código de -v

_skip_zeros:
		inc		al
		mov		dl, [bx]		; Pula zeros à esquerda
		inc		bx				
		cmp		dl, '0'
		jz		_skip_zeros		
		dec 	bx				; Retorna ao primeiro caractere diferente de '0'
		dec		al

		lea		di, V_CODE			; O Reg. di possui o endereço da string do código de verificação
		mov		byte ptr [di], 0	; É colocado um \0 NO INÍCIO da string (pois ela é lida
		inc 	di					; de trás para frente)
_Rep_RVC:
		mov		dl, [bx]					
		cmp		dl, 0				; O código pode delimitar o fim da string de entrada
		jz		_end_RVC			
		cmp		dl, ' '				; O código é dado por uma palavra: é terminado por um char <= ' '
		jle		_end_RVC	
		
		mov 	byte ptr [di], dl	; Se não for '0' nem <= ' ', salva na string do código de verificação
		inc		di
		inc		bx
		jmp		_Rep_RVC

_end_RVC: 
		mov		dl, [di-1]			; Lê o último caractere salvo
		cmp		dl, 0
		jnz		_calculate_vcode	; Se for '\0' (início da string)
		cmp		al, 0
		jg		_calculate_vcode	; e não foi lido nenhum '0' no início,

		lea		bx, ERRO_VCODE_N_INFO	; então o código não foi informado
		call	WriteString
		jmp		Fim

_calculate_vcode:
		mov		byte ptr [di], 0

		;push	bx
		;lea bx, V_CODE
		;inc bx
		;call WriteString
		;lea bx, print
		;call WriteString
		;pop		bx

		call 	CalculateVCode		; Calcula o código presente na string
		jmp 	RIS_rchar			; Continua a ler a string de entrada

ReadInpString	endp

;
;--------------------------------------------------------------------
; Função CalculateVCode: Transforma a string de verificação
; em um número em hexadecimal.
; - Entradas: 
;	* string V_CODE
;	* reg. di com o endereço do char. final
; - Saída: variável V_CODE_HEX
;--------------------------------------------------------------------
CalculateVCode	proc	near

		mov		cl, 4				; cl tem o tamanho do SHL realizado em MULTIPLIER
		lea		si, V_CODE_HEX		; si tem o endereço da variável (representada em little endian)
		mov		bp,	0 				; bp indica a word a ser utilizada de V_CODE_HEX

		mov		MULTIPLIER, 1		; Multiplicador é resetado

Loop_VCode:
		dec		di				; É passado para o próximo char.
		cmp		byte ptr[di], 0
		jz		_Ret_CVC		; Verifica se chegou no final da string

		mov		ah, 0
		mov		al, [di]		; Caractere é salvo em al

	; 	Verificação de caracteres:
	;	0 <= *S <= 9 : al -= '0'
	;	else		 : al += 10 (valor de 0Ah)
	;   A <= *S <= F : al -= 'A'
	;	a <= *S <= f : al -= 'a'
	;	else 		 : ERRO: código de verificação mal-formado!

		cmp 	al, '0'
		jl		_ERRO_VCODE
		cmp		al, '9'
		jg		_A_upper

		sub		al, '0'				; al -= '0'
		jmp		_multiply_A

	_A_upper:
		cmp		al, 'A'
		jl		_ERRO_VCODE
		cmp		al, 'F'
		jg		_a_lower

		add		al, 10				; al += 10
		sub		al, 'A'				; al -= 'A'
		jmp		_multiply_A

	_a_lower: 
		cmp		al, 'a'
		jl		_ERRO_VCODE
		cmp		al, 'f'
		jg		_ERRO_VCODE

		add		al, 10				; al += 10
		sub		al, 'a'				; ax -= 'a'
		jmp		_multiply_A

	_ERRO_VCODE:
		lea 	bx, ERRO_VCODE		; ERRO: código de verificação mal-formado!
		call 	WriteString
		jmp		Fim

	;	OBS: A OPERAÇÃO DE SOMA NÃO TEM COMO GERAR OVERFLOW 
	;   max(word ptr [bp]) = (15)*4096 + (15)*256 + (15)*16 + (15)*1 = 65535 = FFFF
	_multiply_A:
		mul		MULTIPLIER				; 	ax = ax * MULTIPLIER
		add		word ptr [si+bp], ax	; 	V_CODE_HEX[bp] += ax
		shl		MULTIPLIER, cl			;	MULTIPLIER <<= 4
		jc		_change_word			; 	Se deu carry, logo, já foram lidos 4 caracteres
										; 	e a word foi preenchida
		jmp		Loop_VCode				;	Se não, volta a ler mais caracteres

	_change_word:
		mov		MULTIPLIER, 1			; 	Reseta MULTIPLIER
		add		bp, 2					;	Passa para a próxima word
		cmp		bp, 6					
		jg		_ERRO_OVERFLOW_VCODE	;	Se a string passar de 64 bits, mostra erro
		jmp		Loop_VCode				; 	Se não, volta a ler mais caracteres

	_ERRO_OVERFLOW_VCODE:
		dec		di				
		cmp		byte ptr[di], 0
		jz		_Ret_CVC
		lea 	bx, ERRO_OVERFLOW_VCODE		; ERRO: o código de verificação possui mais de 64 bits!
		call 	WriteString
		jmp		Fim

_Ret_CVC:
		ret

CalculateVCode	endp

; _hex_to_string_save: 4 bits -> string, salva em [di+bx]
; É preciso primeiro encontrar o primeiro hexa (4 bits)
; diferente de 0 do número para começar a escrita na string
; - ch: é 1 se o primeiro char. diferente de 0 já foi encontrado
_hex_to_string_save		proc	near
		cmp		ch,	1
		jz		string_al
		cmp		al, 0
		jz		ret_hex		; ch == 0 && al == 0: zero à esquerda que deve ser ignorado
		mov		ch, 1		; ch == 0 && al != 0: primeiro valor diferente de 0 lido
	string_al:
		cmp 	al, 9
		jg		add_A
		add		al, '0'
		jmp		save_hex
	add_A:
		add		al, 'A'
		sub		al, 0Ah
	save_hex:
		mov		[di+bx], al
		inc		bx
	ret_hex:
		ret
_hex_to_string_save		endp

;
;--------------------------------------------------------------------
; Função QuadToString: 64 bits -> string (hexa)
; - Entrada: SI - ponteiro para a var de 64 bits
; - Saída: variável G_CODE
;--------------------------------------------------------------------
QuadToString	proc	near

		lea		di, G_CODE	
		mov		bx, 0		
		mov		bp, 8			; Para recuperar a ordem, começa do mais significativo

	; OBS: cada byte contém 2 caracteres em hexa. São utilizadas
	; máscaras (11110000b e 1111b) e shifts (CL = 4) para retirar
	; as informações de caracter. 

		mov		ch, 0			; ch indica se o primeiro número diferente de 0 foi encontrado
		mov		cl, 4

_For_quad:
		sub		bp, 2

	; Guarda chars. MAIS SIGNIFICATIVOS em dl
		mov		dl, [si+bp+1]			
		mov		al, dl
		and		al, 11110000b				
		shr		al, cl					; al contém o número mais significativo
		call	_hex_to_string_save		; e é transformado em string

		mov		al, dl
		and		al, 00001111b			; al contém o número menos significativo
		call	_hex_to_string_save		; e é transformado em string

	; Guarda chars. MENOS SIGNIFICATIVOS em dl
		mov		dl, [si+bp]	
		mov		al, dl
		and		al, 11110000b				
		shr		al, cl					; al contém o número mais significativo
		call	_hex_to_string_save		; e é transformado em string

		mov		al, dl
		and		al, 00001111b			; al contém o número menos significativo
		call	_hex_to_string_save		; e é transformado em string

	cmp_bp:
		cmp		bp, 0
		jnz		_For_quad			; Repete 4 vezes

		cmp		bx, 0
		jnz		end_str
		mov		byte ptr [di+bx], '0'	; Se todos os caracteres eram 0, então diz que o número é 0
		inc		bx

	end_str:
		mov		byte ptr [di+bx], 0		; Termina a string
		ret

QuadToString	endp

;
;--------------------------------------------------------------------
; Função WriteString: Imprime uma string no prompt
; - Entrada: BX - ponteiro para a string
;--------------------------------------------------------------------
WriteString	proc	near

WS_rchar:
		mov		dl, [bx]		; Lê caractere
		cmp		dl, 0
		jnz		WS_wchar		
		ret						; Se for o caractere final, retorna

WS_wchar:
		mov		ah, 2			; Imprime na tela
		int		21H

		inc		bx				; Passa para o prox. caractere
		jmp		WS_rchar		

WriteString	endp

;--------------------------------------------------------------------
	end
;--------------------------------------------------------------------
	