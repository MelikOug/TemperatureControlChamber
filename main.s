#include <xc.inc>

extrn	KEY_Setup, KEY_Read_Message  ; external subroutines
extrn	LCD_Setup, LCD_Update
extrn	UART_Setup, UART_Transmit_Message
extrn	I2C_Setup, I2C_Set_Sensor_On, I2C_Read_Pixels
;extrn	External_Setup
    




    
psect	code, abs	
rst: 	org 0x0
 	goto	setup

	; ******* Programme FLASH read Setup Code ***********************
setup:	bcf	CFGS	; point to Flash program memory  
	bsf	EEPGD 	; access Flash program memory
	;call	I2C_Setup
	;call	I2C_Set_Sensor_On
	call	LCD_Setup	; setup LCD
	call	UART_Setup
	call	KEY_Setup	; setup KeyPad
	call	External_Setup
	goto	start
	
External_Setup:
	clrf    LATJ
	movlw   0x00
	movwf   TRISJ,A
	bsf	LATJ, 0, A
	bcf	LATJ, 1, A
	bsf	LATJ, 2, A
	
	return
    
	
	
start:
	call	KEY_Read_Message
	;call	I2C_Read_Pixels
	call	UART_Transmit_Message
	call	LCD_Update
	bra	start
	
	end	rst
