#include <xc.inc>

;Holds all the code required to control the output of the LCD based on sensor readings and user inputs
    
global  LCD_Setup, LCD_Update, LCD_delay_ms
global  LCD_tmp, msg, LCD_counter, LenLine1, LenLine2, Line1, Line2, Line1Array, Line2Array
global	target, lineargU,lineargH,lineargL, linearrayarg, lengtharg, addressarg, DDRAM_Address
global	LCD_Send_Byte_I, LCD_Send_Byte_D,LCD_delay_x4us
extrn	temp_high, below_point	    ;
    
psect	udata_bank2	;reserve data in RAM bank 2 (doesnt affect other vars)
Line1Array:	ds 0x20 ;reserve 32 bytes for message data for line 1
Line2Array:	ds 0x20 ;reserve 32 bytes for message data for line 1
SetArray:	ds 0x10
linearrayarg:   ds 1	;will store the start address of either one of the LineArrays




psect	data		;reserve data in program memory for messages to display on LCD
Line1:
	db	'T','a','r','g','e','t',':'	;define byte to reserve space and set values in consecutive addresses
	LenLine1   EQU	7	;length of data
	align	2		;shift data in Line1 to every even file address		
Line2:
	db	'C','u','r','r','e','n','t',':' 	
	db	'N','/','A'	;On start it initall displays the current temperature as 'N/A' until data is read
	LenLine2   EQU	11	;length of data
	align	2

LineSet:
	db	'(','S','e','t',')'
	LenSet	   EQU  5
	align	2
					
psect	udata_acs	;named variables in access ram
LCD_cnt_l:	ds 1    ;reserve 1 byte for variable LCD_cnt_l
LCD_cnt_h:	ds 1    ;reserve 1 byte for variable LCD_cnt_h
LCD_cnt_ms:	ds 1    ;reserve 1 byte for ms counter
LCD_tmp:	ds 1    ;reserve 1 byte for temporary use
LCD_counter:	ds 1    ;reserve 1 byte for counting through message
counter:	ds 1    ;reserve one byte for a counter variable
    
input_high:	ds 1
input_low:	ds 1
    
target:		ds 1
 
DDRAM_Address:  ds 1
    
lengtharg:	ds 1
addressarg:	ds 1
lineargU:	ds 2
lineargH:	ds 2
lineargL:	ds 2
    
LCD_E	EQU 5		;LCD enable bit
LCD_RS	EQU 4		;LCD register select bit

	
	
psect	lcd_code,class=CODE


LCD_Setup:			    
	;List of instructions sent to LCD for required function
	clrf    LATB, A		    
	movlw   11000000B	    
	movwf	TRISB, A	    ;RB0:5 set to outputs
	clrf	input_high, A	    ;Clear Keypad input variables
	clrf	input_low, A
	movlw	15
	movwf	target, A	    ;Set default target to 15 degrees on start
	
	movlw   40
	call	LCD_delay_ms	    ;wait 40ms for LCD to start up properly
	movlw	00110000B	    ;Function set 4-bit
	call	LCD_Send_Byte_I
	movlw	10		    
	call	LCD_delay_x4us	    ;wait 40us
	movlw	00101000B	    ;2 line display 5x8 dot characters
	call	LCD_Send_Byte_I
	movlw	10		    
	call	LCD_delay_x4us	    ;wait 40us
	movlw	00101000B	    ;repeat, 2 line display 5x8 dot characters
	call	LCD_Send_Byte_I
	movlw	10		    
	call	LCD_delay_x4us	    ;wait 40us
	movlw	00001111B	    ;display on, cursor on, blinking on
	call	LCD_Send_Byte_I
	movlw	10		
	call	LCD_delay_x4us	    ;wait 40us
	movlw	00000001B	    ;display clear
	call	LCD_Send_Byte_I
	movlw	2		
	call	LCD_delay_ms	    ;wait 2ms
	movlw	00000110B	    ;entry mode incr by 1 no shift
	call	LCD_Send_Byte_I
	movlw	10		    ;wait 40us
	call	LCD_delay_x4us
	call	LCD_Frame	    
	return			    ;return to position in main.s
	
	
LCD_Frame:
	;Subroutine writes the starting text ("Target:" and "Current:") to the LCD
	
	;Target:
	movlw	low highword(Line1)
	movwf	lineargU, A	    ;Set the line address arguement (21 bits in 3 file registers)
	movlw	high(Line1)
	movwf	lineargH, A 
	movlw	low(Line1)
	movwf	lineargL, A
	
	movff	Line1Array, linearrayarg, A	;Set the line array arguement
	movlw	LenLine1
	movwf	LCD_counter, A	    
	movwf	counter, A	    ;Set the LCD_Counter to the length of Line1 = its address (EQU 7)
	movlw	10000000B
	movwf	addressarg, A	    ;Set the start address of the message to write (first row, first entry)
	call	LCD_Write_Line	    ;Calls the write line function which uses the arguments set in the section of code
	
	;Current: 
	movlw	low highword(Line2)
	movwf	lineargU, A
	movlw	high(Line2)
	movwf	lineargH, A
	movlw	low(Line2)
	movwf	lineargL, A
	
	movff	Line2Array, linearrayarg, A
	movlw	LenLine2
	movwf	LCD_counter, A	    ;Set the LCD_Counter to the length of Line2 = its address (EQU 11)
	movwf	counter, A
	movlw	11000000B
	movwf	addressarg, A	    ;Set the start address of the message to write (second row, first entry)
	call	LCD_Write_Line
	
	return
	
	
	
LCD_Write_Line:
	lfsr	0, linearrayarg		;load FSR0 with address in bank 2 (linearrayarg)	
	movff	lineargU, TBLPTRU, A	;load upper bits of linearg to TBLPTRU
	movff	lineargH, TBLPTRH, A	;load high byte to TBLPTRH
	movff	lineargL, TBLPTRL, A	;load low byte to TBLPTRL
loop: 	tblrd*+				;move data from where TBLPTR from PM to TABLAT, increment TBLPRT
	movff	TABLAT, POSTINC0	;move data from TABLAT to (where FSR0 points), inc FSR0	
	decfsz	counter, A		;count down from length of message to zero
	bra	loop			;keep going until finished
	lfsr	2, linearrayarg		;moves address of linearrayarg in FSR2
LDC_Set_Line:
	movf	addressarg, W, A
	call	LCD_Send_Byte_I		;set DDRAM_Address to beginning of corresponding message to write
	movlw	10			
	call	LCD_delay_x4us		;wait 40us
LCD_Loop_message:
	movf    POSTINC2, W, A		;move value stored at FSR2 address to WR, Inc address
	call    LCD_Send_Byte_D		;write that value to the LCD
	decfsz  LCD_counter, A		;decrement counter that stores length of message currently writing
	bra	LCD_Loop_message	;continue until counter reaches 0
	return
	
	
	
LCD_Update:
    
Test_None:
	movlw	0x00
	cpfseq	msg, A		;is msg = 0x00 (nothing registered on keypad)
	bra	Test_C		;check next condition if false
	call	Update_Current	;update current if true
	return
	    
Test_C:
	movlw	'C'
	cpfseq	msg, A		;is msg = 'C' (user wants to clear input) 
	bra	Test_E		
	bra	LCD_Clear	;clear input if true
Test_E:
	movlw	'E'
	cpfseq	msg, A		;is msg = 'E' (User wants to set a new target temperature) 
	bra	Test_A
	bra	LCD_Enter	;update target temperature with the user's input
	
Test_A:
	movlw	'A'
	cpfseq	msg, A		;is msg = 'A' (invalid input)
	bra	Test_B
	return
	
Test_B:
	movlw	'B'
	cpfseq	msg, A		;is msg = 'B' (invalid input)
	bra	Test_D
	return

Test_D:
	movlw	'D'
	cpfseq	msg, A		;is msg = 'D' (invalid input)
	bra	Test_F
	return

Test_F:
	movlw	'F'
	cpfseq	msg, A		;is msg = 'F' (invalid input)
	bra	check_high	;if not, branch to chec_high (must be a valid number input)
	return

  
LCD_Clear:
	clrf	input_high, A	    ;clear the user input variables
	clrf	input_low, A
	movlw	10000111B
	movwf	DDRAM_Address, A    ;Reset DDRAM_Address to after target:
	
	movlw   0x01		
	call    LCD_Send_Byte_I	    ;sends 01 as instruction (this clears LCD)
	movlw	2
	call	LCD_delay_ms	    ;wait 2ms for LCD to start up properly	
	movlw	00001111B	
	call	LCD_Send_Byte_I	    ;display on, cursor on, blinking on
	movlw	10		
	call	LCD_delay_x4us	    ;wait 40us
	call	LCD_Frame	    ;rebuilds the frame text
	return			    ;return to position in main.s
	
	
LCD_Enter:
one_num:
	movlw	10001000B
	cpfseq	DDRAM_Address, A    ;Does DDRAM_Address indicate that only one number been typed?
	bra	two_num		    ;If not, treats first value as a tens digit (branch to two_num)
	movf	input_high, W, A    ;If yes, treats first value as a ones unit
	andlw	0x0F		    ;Keeps lower nibble (ascii to decimal) (0x3y -> 0x0y)
	movwf	target, A	    ;Set this single number input to the target variable
	bra	Write_Set	    ;Call function that indicates target has been set
	
two_num:
	movf	input_high, W, A    ;moves the tens digit to wr
	andlw	0x0F		    ;convert to decimal
	mullw	10		    ;multiply by ten and store in PROD
	movf	input_low, W, A	    ;moves the ones digit to wr
	andlw	0x0F		    ;convert to decimal
	addwf	PROD, W, A	    ;adds whatever was in the tens column  with the ones column to give number above dp
	movwf	target, A	    ;target is updated

Write_Set:
	movlw	low highword(LineSet)
	movwf	lineargU, A
	movlw	high(LineSet)
	movwf	lineargH, A
	movlw	low(LineSet)
	movwf	lineargL, A
	
	movff	SetArray, linearrayarg, A
	movlw	LenSet
	movwf	LCD_counter, A
	movwf	counter, A
	movlw	10001010B
	movwf	addressarg, A
	call	LCD_Write_Line
	
	movlw	00001100B
	call	LCD_Send_Byte_I
	movlw	10
	call	LCD_delay_x4us
	return			    ;return to position in main.s
	
check_high:
	movlw	0
	cpfseq	input_high, A	    ;check if input_high already has a value
	bra	check_low	    ;if it does, branch to check_low
	movff	msg, input_high, A  ;if it doesn't, move our ascii message to input_high
	call	Update_Target	    ;calls the subroutine that writes the keypad input to the LCD
	return			    ;return to position in main.s
	
check_low:
	movlw	0
	cpfseq	input_low, A
	return			    ;if input_low already has a value, just return. Only options are Clear or Enter.
	movff	msg, input_low, A
	call	Update_Target
	return			    ;return to position in main.s
	
	
Update_Target:
	movf	msg, W, A	    
	call	LCD_Send_Byte_D	    ;writes msg (which is in ascii form) to the LCD
				    ;DDRAM_Address is already either 1 or 2 after "target:"
	incf	DDRAM_Address, F, A ;increments DDRAM_Address so that the next number inputted is written after
	return
	

Update_Current:
	movlw	0xC8		    ;Address of pixel after "current:" (9th along)(1)48 = C8
	call	LCD_Send_Byte_I
	movlw	10		    
	call	LCD_delay_x4us	    ;wait 40us
	
	swapf	temp_high, W, A	    ;temp_high holds the 0xyz hex version of yz decmial version 
				    ;swaps nibbles
	andlw	0x0F		    ;gets lower nibble (tens)
	addlw	0x30		    ;converts to ascii 
	call	LCD_Send_Byte_D	    ;writes value to LCD
	
	movf	temp_high, W, A
	andlw	0x0F		    ;gets lower nibble (ones)
	addlw	0x30		    ;converts to ascii 
	call	LCD_Send_Byte_D	    ;writes value to LCD
	
	movlw	'.'		    
	call	LCD_Send_Byte_D	    ;writes the decimal point to the LCD
	
	movf	below_point, W, A   ;moves below_point to wr
	addlw	0x30		    ;converts to ascii 
	call	LCD_Send_Byte_D	    ;writes to LCD
	
	movf	DDRAM_Address, W, A ;Address after target: (either 1st or 2nd)
	call	LCD_Send_Byte_I	    ;set address to DDRAM_Address so that next keypad input writes to correct position
	movlw	10		    
	call	LCD_delay_x4us	    ;wait 40us
	return
    
    
    
    
    
LCD_Send_Byte_I:	    
	;Transmits byte stored in W to instruction reg
	movwf   LCD_tmp, A
	swapf   LCD_tmp, W, A	    ;swap nibbles, high nibble goes first
	andlw   0x0F		    ;select just low nibble
	movwf   LATB, A		    ;output data bits to LCD
	bcf	LATB, LCD_RS, A	    ;Instruction write clear RS bit
	call    LCD_Enable	    ;Pulse enable Bit 
	movf	LCD_tmp, W, A	    ;swap nibbles, now do low nibble
	andlw   0x0F		    ;select just low nibble
	movwf   LATB, A		    ;output data bits to LCD
	bcf	LATB, LCD_RS, A	    ;Instruction write clear RS bit
        call    LCD_Enable	    ;Pulse enable Bit 
	return

LCD_Send_Byte_D:
	movwf   LCD_tmp, A
	swapf   LCD_tmp, W, A	    ;swap nibbles, high nibble goes first

	andlw   0x0F		    ;select just low nibble
	movwf   LATB, A		    ;output data bits to LCD
	bsf	LATB, LCD_RS, A	    ;Data write set RS bit
	call    LCD_Enable	    ;Pulse enable Bit 
	movf	LCD_tmp, W, A	    ;swap nibbles, now do low nibble
	andlw   0x0F		    ;select just low nibble
	movwf   LATB, A		    ;output data bits to LCD
	bsf	LATB, LCD_RS, A	    ;Data write set RS bit	    
        call    LCD_Enable	    ;Pulse enable Bit 
	movlw	10		    
	call	LCD_delay_x4us	    ;delay 40us
	return

LCD_Enable:	    ; pulse enable bit LCD_E for 500ns
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	bsf	LATB, LCD_E, A	    ; Take enable high
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	bcf	LATB, LCD_E, A	    ; Writes data to LCD
	return
    
	
	
	
	
; ** a few delay routines below here as LCD timing can be quite critical (borrowed from template code) ****
LCD_delay_ms:			 ;delay given in ms in W
	movwf	LCD_cnt_ms, A
lcdlp2:	movlw	250		 ;1 ms delay
	call	LCD_delay_x4us	
	decfsz	LCD_cnt_ms, A
	bra	lcdlp2
	return
    
LCD_delay_x4us:			;delay given in chunks of 4 microsecond in W
	movwf	LCD_cnt_l, A	;now need to multiply by 16
	swapf   LCD_cnt_l, F, A	;swap nibbles
	movlw	0x0f	    
	andwf	LCD_cnt_l, W, A ;move low nibble to W
	movwf	LCD_cnt_h, A	;then to LCD_cnt_h
	movlw	0xf0	    
	andwf	LCD_cnt_l, F, A ;keep high nibble in LCD_cnt_l
	call	LCD_delay
	return

LCD_delay:			;delay routine	4 instruction loop == 250ns	    
	movlw 	0x00		;W=0
lcdlp1:	decf 	LCD_cnt_l, F, A	;no carry when 0x00 -> 0xff
	subwfb 	LCD_cnt_h, F, A	;no carry when 0x00 -> 0xff
	bc 	lcdlp1		;carry, then loop again
	return			;carry reset so return


    end


