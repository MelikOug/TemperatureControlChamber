#include <xc.inc>

extrn	KEY_Setup, KEY_Read_Message  ; external subroutines
extrn	LCD_Setup, LCD_Update
extrn	UART_Setup, UART_Transmit_Message
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
	call	UART_Setup
	call	LCD_Setup	; setup UART
	call	KEY_Setup	; setup KeyPad
	goto	start
	
start:
	call	KEY_Read_Message
	call	delay
	call	UART_Transmit_Message
	call	LCD_Update
	bra	start
	
delay:
	movlw   0x0F
	movwf   delay_count, A
	decfsz  delay_count
	bra	    delay
	return  
    

	end	rst