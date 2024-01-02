#include <xc.inc>
    
;This holds the sequence of subroutine executions in external files for the program to run 
    
;External subroutines called by the main.s file
extrn	KEY_Setup, KEY_Read_Message  
extrn	LCD_Setup, LCD_Update
extrn	UART_Setup, UART_Transmit_Pixels
extrn	I2C_Setup, I2C_Set_Sensor_On, I2C_Read_Pixels, I2C_Average_Pixels
extrn	External_Setup, External_Mode
        
    
psect	code, abs	
rst: 	org 0x0
 	goto	setup
		
	org	0x100			;The address in PM of where the instructions start storing
setup:	bcf	CFGS			;Point to Flash program memory  
	bsf	EEPGD			;Access Flash program memory
	call	External_Setup		;Configures PORTJ that will control the Heating Module 
	call	I2C_Setup		;Configures the I2C protocol that will be used to read data from the temperature sensor
	call	I2C_Set_Sensor_On	;Turns on the temperature sensor
 	call	UART_Setup		;Configures the UART protocol which will be used to send sensor data to PC
	call	LCD_Setup		;Configures the LCD Screen
	call	KEY_Setup		;Configures PORTE and variables required to read data from keypad
	goto	start

start:
	call	I2C_Read_Pixels		;Reads data from each pixel on temperature sensor to microcontroller via I2C
	call	UART_Transmit_Pixels	;Sends this data to PC
	call	I2C_Average_Pixels	;Calculates the mean temperature across all pixels
	call	LCD_Update		;Updates LCD screen with necessary information
 	call	KEY_Read_Message	;Reads message inputted on keypad
	call	External_Mode		;Sets the mode of the heating module depending parameters
	bra	start
	
	end	rst
