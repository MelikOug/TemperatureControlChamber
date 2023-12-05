#include <xc.inc>

extrn	KEY_Setup, KEY_Read_Message  ; external subroutines
extrn	LCD_Setup, LCD_Update
extrn	UART_Setup, UART_Transmit_Message
extrn	I2C_Setup, I2C_Set_Sensor_On, I2C_Read_Pixels, check_int
    
;extrn	External_Setup
    




    
psect	code, abs	
rst: 	org 0x0
 	goto	setup

int_hi: org 0x0008
        movlw 0x88
        movwf  LATE, A 
	retfie f
 ;goto check_int
	
    org	0x100		
	; ******* Programme FLASH read Setup Code ***********************
setup:	bcf	CFGS	; point to Flash program memory  
	bsf	EEPGD 	; access Flash program memory
	;	call	External_Setup
	call	I2C_Setup
	call	I2C_Set_Sensor_On
	call	I2C_Read_Pixels
	call	LCD_Setup	; setup LCD
	call	UART_Setup
	call	KEY_Setup	; setup KeyPad
	
	goto	start
	

    
	
	
start:
	call	KEY_Read_Message
	;call	I2C_Read_Pixels
	call	UART_Transmit_Message
	call	LCD_Update
	bra	start
	
	end	rst
