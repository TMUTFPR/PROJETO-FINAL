        PUBLIC  __iar_program_start
        EXTERN  __vector_table

        SECTION .text:CODE:REORDER(2)
        
        ;; Keep vector table even if it's not referenced
        REQUIRE __vector_table
        
        THUMB

; System Control definitions
SYSCTL_BASE             EQU     0x400FE000
SYSCTL_RCGCGPIO         EQU     0x0608
SYSCTL_PRGPIO		EQU     0x0A08
SYSCTL_RCGCUART         EQU     0x0618
SYSCTL_PRUART           EQU     0x0A18
; System Control bit definitions
PORTA_BIT               EQU     000000000000001b ; bit  0 = Port A
PORTF_BIT               EQU     000000000100000b ; bit  5 = Port F
PORTJ_BIT               EQU     000000100000000b ; bit  8 = Port J
PORTN_BIT               EQU     001000000000000b ; bit 12 = Port N
UART0_BIT               EQU     00000001b        ; bit  0 = UART 0

; NVIC definitions
NVIC_BASE               EQU     0xE000E000
NVIC_EN1                EQU     0x0104
VIC_DIS1                EQU     0x0184
NVIC_PEND1              EQU     0x0204
NVIC_UNPEND1            EQU     0x0284
NVIC_ACTIVE1            EQU     0x0304
NVIC_PRI12              EQU     0x0430

; GPIO Port definitions
GPIO_PORTA_BASE         EQU     0x40058000
GPIO_PORTF_BASE    	EQU     0x4005D000
GPIO_PORTJ_BASE    	EQU     0x40060000
GPIO_PORTN_BASE    	EQU     0x40064000
GPIO_DIR                EQU     0x0400
GPIO_IS                 EQU     0x0404
GPIO_IBE                EQU     0x0408
GPIO_IEV                EQU     0x040C
GPIO_IM                 EQU     0x0410
GPIO_RIS                EQU     0x0414
GPIO_MIS                EQU     0x0418
GPIO_ICR                EQU     0x041C
GPIO_AFSEL              EQU     0x0420
GPIO_PUR                EQU     0x0510
GPIO_DEN                EQU     0x051C
GPIO_PCTL               EQU     0x052C

; UART definitions
UART_PORT0_BASE         EQU     0x4000C000
UART_FR                 EQU     0x0018
UART_IBRD               EQU     0x0024
UART_FBRD               EQU     0x0028
UART_LCRH               EQU     0x002C
UART_CTL                EQU     0x0030
UART_CC                 EQU     0x0FC8
;UART bit definitions
TXFE_BIT                EQU     10000000b ; TX FIFO full
RXFF_BIT                EQU     01000000b ; RX FIFO empty
BUSY_BIT                EQU     00001000b ; Busy

; PROGRAMA PRINCIPAL

__iar_program_start
        
main:   MOV R2, #(UART0_BIT)
	BL UART_enable ; habilita clock ao port 0 de UART

        MOV R2, #(PORTA_BIT)
	BL GPIO_enable ; habilita clock ao port A de GPIO
        
	LDR R0, =GPIO_PORTA_BASE
        MOV R1, #00000011b ; bits 0 e 1 como especiais
        BL GPIO_special

	MOV R1, #0xFF ; máscara das funções especiais no port A (bits 1 e 0)
        MOV R2, #0x11  ; funções especiais RX e TX no port A (UART)
        BL GPIO_select

	LDR R0, =UART_PORT0_BASE
        BL UART_config ; configura periférico UART0
        
        ; recepção e envio de dados pela UART utilizando sondagem (polling)
        ; resulta em um "eco": dados recebidos são retransmitidos pela UART
        MOV R5, #0      //auxiliar para contar numero de digitos
        MOV R6, #0
        
wrx:    LDR R11, [R0, #UART_FR] ; status da UART
        TST R11, #RXFF_BIT ; receptor cheio?
        BEQ wrx
        LDR R1, [R0] ; lê do registrador de dados da UART0 (recebe)

        BL valida
        //comparacao para voltar à leitura caso nao seja valido
        CMP R3, #0      //se for 0, nào é valido e volta para a leitura
        BEQ wrx
        
        MOV R7, #0
        
        CMP R3, #1b
        IT EQ
        BLEQ colocar_numero
        
        CMP R7, #1b
        BEQ wrx
        
        BL escreve
        
        CMP R3, #10b
        IT EQ
        BLEQ guardar_operacao
        
        CMP R3, #100b
        IT EQ
        BLEQ calcular_resultado
        

        ; caso contrário, volta pro loop
        B wrx
        
calcular_resultado:
        PUSH {LR}
        //R10 contém o primeiro valor. R6 contém o segundo valor ainda não adaptado
        CMP R5, #1
        ITT EQ
        MOVEQ R7, #100
        UDIVEQ R6, R7
        
        CMP R5, #2
        ITT EQ
        MOVEQ R7, #10
        UDIVEQ R6, R7
        //neste ponto, R10 contém o valor 1 e R6 contém o valor 2
        
        CMP R4, #'+'
        IT EQ
        ADDEQ R1, R6, R9
        
        CMP R4, #'-'
        IT EQ
        SUBEQ R1, R6, R9
        
        CMP R4, #'*'
        IT EQ
        MULEQ R1, R6, R9
        
        CMP R4, #'/'
        IT EQ
        UDIVEQ R1, R6, R9
        
        //faz divisões sucessivas por 100000, 10000, 1000, 100 e 10 para exibir na tela o valor em ASCii
        MOV R2, R1
        MOV R3, #34464
        MOVT R3, #1
        BL mostra_resultado
        
        MOV R2, R1
        MOV R3, #10000
        BL mostra_resultado

        MOV R2, R1
        MOV R3, #1000
        BL mostra_resultado

        MOV R2, R1
        MOV R3, #100
        BL mostra_resultado

        MOV R2, R1
        MOV R3, #10
        BL mostra_resultado
        
        BL escreve
        
wait1:  LDR R2, [R0, #UART_FR]
        TST R2, #TXFE_BIT
        BEQ wait1
        
        MOV R1, #'\r'
        STR R1, [R0]
        
wait2:  LDR R2, [R0, #UART_FR]
        TST R2, #TXFE_BIT
        BEQ wait2
        
        MOV R1, #'\n'
        STR R1, [R0]
        
        MOV R5, #0
        MOV R6, #0
        
        POP {PC}

mostra_resultado:
        PUSH {LR}
        UDIV R1, R2, R3
        BL escreve
        MUL R1, R1, R3
        SUB R1, R2, R1
        
        POP {PC}

colocar_numero:
        //precisa verificar de R5 < 3 (0, 1 ou 2) e colocar em um registrador auxiliar caso seja
        CMP R5, #3
        ITT EQ
        MOVEQ R7, #1b //se for 3 (ou mais) ele "liga um bit" que indica que 3 números já foram digitados E o usuário entrou outro número
        BXEQ LR
        
        PUSH {R7}
        
        CMP R5, #0
        ITT EQ
        MOVEQ R7, #100
        MULEQ R8, R1, R7
        
        CMP R5, #1
        ITT EQ
        MOVEQ R7, #10
        MULEQ R8, R1, R7
        
        CMP R5, #2
        ITT EQ
        MOVEQ R7, #0
        MOVEQ R8, R1
        
        ADD R6, R8     //armazena temporariamente o valor digitado acumulado pelo usuário
        ADD R5, #1      //soma em R5

        POP {R7}
        
        BX LR

guardar_operacao:
        ADD R1, #0x30
        MOV R4, R1      //guarda em R4 a operacao
        SUB R1, #0x30
        
        PUSH {R7}
        
        CMP R5, #1
        ITT EQ
        MOVEQ R7, #100
        UDIVEQ R6, R7
        
        CMP R5, #2
        ITT EQ
        MOVEQ R7, #10
        UDIVEQ R6, R7
        
        MOV R9, R6      //R9 é o primeiro número digitado pelo usuário
        MOV R6, #0
        
        POP {R7}
        
        MOV R5, #0      //permite entrada de novos numeros
        BX LR

escreve:
        LDR R11, [R0, #UART_FR]
        TST R11, #TXFE_BIT
        BEQ escreve
        
        ADD R1, #0x30
        STR R1, [R0]
        SUB R1, #0x30
        
        BX LR

valida:
        MOV R3, #0
        SUB R1, #0x30
        
        CMP R1, #0
        IT GE
        MOVGE R3, #1b
        
        CMP R1, #9
        IT GT
        MOVGT R3, #0
        
        ADD R1, #0x30
        CMP R1, #'+'
        IT EQ
        MOVEQ R3, #10b
        
        CMP R1, #'-'
        IT EQ
        MOVEQ R3, #10b
        
        CMP R1, #'*'
        IT EQ
        MOVEQ R3, #10b
        
        CMP R1, #'/'
        IT EQ
        MOVEQ R3, #10b
        
        CMP R1, #'='
        IT EQ
        MOVEQ R3, #100b
        SUB R1, #0x30
        
        BX LR
        
        


; SUB-ROTINAS

;----------
; UART_enable: habilita clock para as UARTs selecionadas em R2
; R2 = padrão de bits de habilitação das UARTs
; Destrói: R0 e R1

UART_enable:
        LDR R0, =SYSCTL_BASE
	LDR R1, [R0, #SYSCTL_RCGCUART]
	ORR R1, R2 ; habilita UARTs selecionados
	STR R1, [R0, #SYSCTL_RCGCUART]

waitu	LDR R1, [R0, #SYSCTL_PRUART]
	TEQ R1, R2 ; clock das UARTs habilitados?
	BNE waitu

        BX LR
        
; UART_config: configura a UART desejada
; R0 = endereço base da UART desejada
; Destrói: R1
UART_config:
        LDR R1, [R0, #UART_CTL]
        BIC R1, #0x01 ; desabilita UART (bit UARTEN = 0)
        STR R1, [R0, #UART_CTL]

        ; clock = 16MHz, baud rate = 300 bps
        MOV R1, #104
        STR R1, [R0, #UART_IBRD]
        MOV R1, #11
        STR R1, [R0, #UART_FBRD]
        
        MOV R1, #01100010b
        STR R1, [R0, #UART_LCRH]
        
        ; clock source = system clock
        MOV R1, #0x00
        STR R1, [R0, #UART_CC]
        
        LDR R1, [R0, #UART_CTL]
        ORR R1, #0x01 ; habilita UART (bit UARTEN = 1)
        STR R1, [R0, #UART_CTL]

        BX LR


; GPIO_special: habilita funcões especiais no port de GPIO desejado
; R0 = endereço base do port desejado
; R1 = padrão de bits (1) a serem habilitados como funções especiais
; Destrói: R2
GPIO_special:
	LDR R2, [R0, #GPIO_AFSEL]
	ORR R2, R1 ; configura bits especiais
	STR R2, [R0, #GPIO_AFSEL]

	LDR R2, [R0, #GPIO_DEN]
	ORR R2, R1 ; habilita função digital
	STR R2, [R0, #GPIO_DEN]

        BX LR

; GPIO_select: seleciona funcões especiais no port de GPIO desejado
; R0 = endereço base do port desejado
; R1 = máscara de bits a serem alterados
; R2 = padrão de bits (1) a serem selecionados como funções especiais
; Destrói: R3
GPIO_select:
	LDR R3, [R0, #GPIO_PCTL]
        BIC R3, R1
	ORR R3, R2 ; seleciona bits especiais
	STR R3, [R0, #GPIO_PCTL]

        BX LR
;----------

; GPIO_enable: habilita clock para os ports de GPIO selecionados em R2
; R2 = padrão de bits de habilitação dos ports
; Destrói: R0 e R1
GPIO_enable:
        LDR R0, =SYSCTL_BASE
	LDR R1, [R0, #SYSCTL_RCGCGPIO]
	ORR R1, R2 ; habilita ports selecionados
	STR R1, [R0, #SYSCTL_RCGCGPIO]

waitg	LDR R1, [R0, #SYSCTL_PRGPIO]
	TEQ R1, R2 ; clock dos ports habilitados?
	BNE waitg

        BX LR

; GPIO_digital_output: habilita saídas digitais no port de GPIO desejado
; R0 = endereço base do port desejado
; R1 = padrão de bits (1) a serem habilitados como saídas digitais
; Destrói: R2
GPIO_digital_output:
	LDR R2, [R0, #GPIO_DIR]
	ORR R2, R1 ; configura bits de saída
	STR R2, [R0, #GPIO_DIR]

	LDR R2, [R0, #GPIO_DEN]
	ORR R2, R1 ; habilita função digital
	STR R2, [R0, #GPIO_DEN]

        BX LR

; GPIO_write: escreve nas saídas do port de GPIO desejado
; R0 = endereço base do port desejado
; R1 = máscara de bits a serem acessados
; R2 = bits a serem escritos
GPIO_write:
        STR R2, [R0, R1, LSL #2] ; escreve bits com máscara de acesso
        BX LR

; GPIO_digital_input: habilita entradas digitais no port de GPIO desejado
; R0 = endereço base do port desejado
; R1 = padrão de bits (1) a serem habilitados como entradas digitais
; Destrói: R2
GPIO_digital_input:
	LDR R2, [R0, #GPIO_DIR]
	BIC R2, R1 ; configura bits de entrada
	STR R2, [R0, #GPIO_DIR]

	LDR R2, [R0, #GPIO_DEN]
	ORR R2, R1 ; habilita função digital
	STR R2, [R0, #GPIO_DEN]

	LDR R2, [R0, #GPIO_PUR]
	ORR R2, R1 ; habilita resitor de pull-up
	STR R2, [R0, #GPIO_PUR]

        BX LR

; GPIO_read: lê as entradas do port de GPIO desejado
; R0 = endereço base do port desejado
; R1 = máscara de bits a serem acessados
; R2 = bits lidos
GPIO_read:
        LDR R2, [R0, R1, LSL #2] ; lê bits com máscara de acesso
        BX LR

; SW_delay: atraso de tempo por software
; R0 = valor do atraso
; Destrói: R0
SW_delay:
        CBZ R0, out_delay
        SUB R0, R0, #1
        B SW_delay        
out_delay:
        BX LR
        
        END