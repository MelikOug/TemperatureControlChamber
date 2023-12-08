#include <xc.inc>

extrn	KEY_Setup, KEY_Read_Message  ; external subroutines
extrn	LCD_Setup, LCD_Update
extrn	UART_Setup, UART_Transmit_Pixels
extrn	I2C_Setup, I2C_Set_Sensor_On, I2C_Read_Pixels, I2C_Average_Pixels
extrn	External_Setup, External_Mode
    




    
psect	code, abs	
rst: 	org 0x0
 	goto	setup

		
	org 0x100
setup:	bcf	CFGS	; point to Flash program memory  
	bsf	EEPGD 	; access Flash program memory
	call	External_Setup
	call	I2C_Setup
	call	I2C_Set_Sensor_On
	call	LCD_Setup	; setup LCD
	call	UART_Setup
	call	KEY_Setup	; setup KeyPad
	goto	start

start:
	call	KEY_Read_Message
	call	I2C_Read_Pixels
	call	UART_Transmit_Pixels
	call	I2C_Average_Pixels
	call	LCD_Update
	call	External_Mode
	bra	start
	
	end	rst
