#include <xc.inc>

extrn	KEY_Setup, KEY_Read_Message  ; external subroutines
extrn	LCD_Setup, LCD_Update
extrn	UART_Setup, UART_Transmit_Message
extrn	I2C_Setup, I2C_Set_Sensor_On, I2C_Read_Pixels
extrn	External_Setup
    
global delay
	
psect	udata_acs   ; reserve data space in access ram
counter:    ds 1    ; reserve one byte for a counter variable
delay_count:ds 1    ; reserve one byte for counter in the delay routine



 
psect	udata_bank4 ; reserve data anywhere in RAM (here at 0x400)
myArray:    ds 0x80 ; reserve 128 bytes for message data




    
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
	
start:
	call	KEY_Read_Message
	;call	delay
	;call	I2C_Read_Pixels
	call	UART_Transmit_Message
	call	LCD_Update
	bra	start
	
delay:
	movlw   0x0F
	movwf   delay_count, A
	decfsz  delay_count, A
	bra	delay
	return  
    

	end	rst
