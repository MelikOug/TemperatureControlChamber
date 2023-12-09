#include <xc.inc>

global  LCD_Setup, LCD_Update, LCD_delay_ms
global  LCD_tmp, msg, LCD_counter, LenLine1, LenLine2, Line1, Line2, Line1Array, Line2Array
global	target, lineargU,lineargH,lineargL, linearrayarg, lengtharg, addressarg
extrn	temp_high, below_point
    
psect	udata_bank2	;reserve data in RAM bank 2 (doesnt affect other vars)
Line1Array:	ds 0x20 ;reserve 32 bytes for message data for line 1
Line2Array:	ds 0x20 ;reserve 32 bytes for message data for line 1
SetArray:	ds 0x10
linearrayarg:   ds 1



    
psect	data	
Line1:
	db	'T','a','r','g','e','t',':';,0x0a ;message (in PR), plus carriage return that moves cursor to the end
	LenLine1   EQU	7	; length of data
	align	2				
Line2:
	db	'C','u','r','r','e','n','t',':'  ;message (in PR)	
	db	'N','/','A'
	LenLine2   EQU	11	; length of data
	align	2

LineSet:db	'(','S','e','t',')'
	LenSet	   EQU  5
	align	2
					
psect	udata_acs   ; named variables in access ram
LCD_cnt_l:	ds 1   ; reserve 1 byte for variable LCD_cnt_l
LCD_cnt_h:	ds 1   ; reserve 1 byte for variable LCD_cnt_h
LCD_cnt_ms:	ds 1   ; reserve 1 byte for ms counter
LCD_tmp:	ds 1   ; reserve 1 byte for temporary use
LCD_counter:	ds 1   ; reserve 1 byte for counting through message
counter:	ds 1   ; reserve one byte for a counter variable
    
input_high:	ds 1
input_low:	ds 1
    
target:		ds 1
 
DDRAM_Address:  ds 1
    
lengtharg:	ds 1
addressarg:	ds 1
lineargU:	ds 2
lineargH:	ds 2
lineargL:	ds 2
    
LCD_E	EQU 5	; LCD enable bit
LCD_RS	EQU 4	; LCD register select bit

	
	
psect	lcd_code,class=CODE

	
LCD_Setup:
	clrf    LATB, A
	movlw   11000000B	    ; RB0:5 and below all outputs
	movwf	TRISB, A
	clrf	input_high, A
	clrf	input_low, A
	movlw	10000111B
	movwf	DDRAM_Address, A    ;Set DDRAM_Address to 1 after target:
	movlw	0x20
	movwf	target, A	    ;default target
	
	movlw   40
	call	LCD_delay_ms	; wait 40ms for LCD to start up properly
	movlw	00110000B	; Function set 4-bit
	call	LCD_Send_Byte_I
	movlw	10		; wait 40us
	call	LCD_delay_x4us
	movlw	00101000B	; 2 line display 5x8 dot characters
	call	LCD_Send_Byte_I
	movlw	10		; wait 40us
	call	LCD_delay_x4us
	movlw	00101000B	; repeat, 2 line display 5x8 dot characters
	call	LCD_Send_Byte_I
	movlw	10		; wait 40us
	call	LCD_delay_x4us
	movlw	00001111B	; display on, cursor on, blinking on
	call	LCD_Send_Byte_I
	movlw	10		; wait 40us
	call	LCD_delay_x4us
	movlw	00000001B	; display clear
	call	LCD_Send_Byte_I
	movlw	2		; wait 2ms
	call	LCD_delay_ms
	movlw	00000110B	; entry mode incr by 1 no shift
	call	LCD_Send_Byte_I
	movlw	10		; wait 40us
	call	LCD_delay_x4us
	call	LCD_Frame
	return
	
	
LCD_Frame:
	;Set the line arguement
	;Set the line array arguement
	;Set the line length temporary variable (arguement)
	;Set the start address arguement
	;call write line
	
	;Target:
	movlw	low highword(Line1)
	movwf	lineargU, A
	movlw	high(Line1)
	movwf	lineargH, A
	movlw	low(Line1)
	movwf	lineargL, A
	
	movff	Line1Array, linearrayarg, A
	movlw	LenLine1
	movwf	LCD_counter, A
	movwf	counter, A
	movlw	10000000B
	movwf	addressarg, A
	call	LCD_Write_Line
	
	;Current: 
	movlw	low highword(Line2)
	movwf	lineargU, A
	movlw	high(Line2)
	movwf	lineargH, A
	movlw	low(Line2)
	movwf	lineargL, A
	
	movff	Line2Array, linearrayarg, A
	movlw	LenLine2
	movwf	LCD_counter, A
	movwf	counter, A
	movlw	11000000B
	movwf	addressarg, A
	call	LCD_Write_Line
	
	return
	
	
	
LCD_Write_Line:
	lfsr	0, linearrayarg		; Load FSR0 with address in bank 2	
	movff	lineargU, TBLPTRU, A	; load upper bits to TBLPTRU
	movff	lineargH, TBLPTRH, A	; load high byte to TBLPTRH
	movff	lineargL, TBLPTRL, A	; load low byte to TBLPTRL
loop: 	tblrd*+				; one byte from PM to TABLAT, increment TBLPRT
	movff	TABLAT, POSTINC0	; move data from TABLAT to (where FSR0 points), inc FSR0	
	decfsz	counter, A		; count down to zero
	bra	loop			; keep going until finished
	lfsr	2, linearrayarg		; Moves address of Line2Array in FSR2
LDC_Set_Line:
	movf	addressarg, W, A
	call	LCD_Send_Byte_I
	movlw	10			; wait 40us
	call	LCD_delay_x4us
LCD_Loop_message:
	movf    POSTINC2, W, A		; Move value stored at FSR2 address to WR, Inc address
	call    LCD_Send_Byte_D
	decfsz  LCD_counter, A
	bra	LCD_Loop_message
	return
	
	
	
LCD_Update:
    
Test_None:
	movlw	0x00
	cpfseq	msg, A		;is msg = 0x00 -> Update current if true
	bra	Test_C
	call	Update_Current
	return
	    
Test_C:
	movlw	'C'
	cpfseq	msg, A		;is msg = 'C' -> call clear subroutine
	bra	Test_E	
	bra	LCD_Clear
Test_E:
	movlw	'E'
	cpfseq	msg, A		;is msg = 'E' -> call enter subroutine
	bra	Test_A
	bra	LCD_Enter

Test_A:
	movlw	'A'
	cpfseq	msg, A		;is msg = 'A' -> return
	bra	Test_B
	return
	
Test_B:
	movlw	'B'
	cpfseq	msg, A		;is msg = 'B' -> return
	bra	Test_D
	return

Test_D:
	movlw	'D'
	cpfseq	msg, A		;is msg = 'D' -> return
	bra	Test_F
	return

Test_F:
	movlw	'F'
	cpfseq	msg, A		;is msg = 'F' -> return
	bra	check_high	;if not, continue
	return

  
LCD_Clear:
	clrf	input_high, A
	clrf	input_low, A
	clrf	target, A
	movlw	10000111B
	movwf	DDRAM_Address, A ;Reset DDRAM_Address to after target:
	
	movlw   0x01    ;sends 01 as instruction (this clears LCD)
	call    LCD_Send_Byte_I
	movlw	2
	call	LCD_delay_ms	; wait 2ms for LCD to start up properly	
	movlw	00001111B	; display on, cursor on, blinking on
	call	LCD_Send_Byte_I
	movlw	10		; wait 40us
	call	LCD_delay_x4us
	call	LCD_Frame
	return  ;returns to main.s
    
LCD_Enter:
	movlw	10001000B
	cpfseq	DDRAM_Address, A    ;Has only one number been typed?
	bra	two_num		    ;If not, treats first value as a tens digit
	movf	input_high, W, A    ;If yes, treats first value as a ones unit
	andlw	0x0F		    ;Keeps lower nibble (ascii to decimal)
	movwf	target, A
	bra	Write_Set
	
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
	movlw	10001011B
	movwf	addressarg, A
	call	LCD_Write_Line
	
	movlw	00001100B
	call	LCD_Send_Byte_I
	movlw	10
	call	LCD_delay_x4us
	return
	
check_high:
	movlw	0
	cpfseq	input_high, A	    ;check if input_high already has a value
	bra	check_low	    ;if it does, branch to check_low
	movff	msg, input_high, A	    ;if it doesn't, move our ascii message to WR
	call	Update_Target
	return
	
check_low:
	movlw	0
	cpfseq	input_low, A
	return			    ;if input_low already has a value, just return. Only options are Clear or Enter.
	movff	msg, input_low, A
	call	Update_Target
	return
	
	
Update_Target:
	movf	msg, W, A; Transmits byte stored in msg to data reg
	call	LCD_Send_Byte_D
	incf	DDRAM_Address, F, A
	return
	

Update_Current:
	movlw	0xC8	;Address of pixel after "current:" (9th along)(1)48 = C8
	call	LCD_Send_Byte_I
	movlw	10		; wait 40us
	call	LCD_delay_x4us
	
	swapf	temp_high, W, A
	andlw	0x0F	;gets lower nibble (tens)
	addlw	0x30	;converts to ascii 
	call	LCD_Send_Byte_D
	
	movf	temp_high, W, A
	andlw	0x0F	;gets lower nibble (ones)
	addlw	0x30	;converts to ascii 
	call	LCD_Send_Byte_D
	
	movlw	'.'
	call	LCD_Send_Byte_D
	
	movf	below_point, W, A
	addlw	0x30	;converts to ascii 
	call	LCD_Send_Byte_D
	
	movf	DDRAM_Address, W, A ;Address after target: (either 1st or 2nd)
	call	LCD_Send_Byte_I
	movlw	10		; wait 40us
	call	LCD_delay_x4us
	return
    
    
    
    
    
LCD_Send_Byte_I:	    ; Transmits byte stored in W to instruction reg
	movwf   LCD_tmp, A
	swapf   LCD_tmp, W, A   ; swap nibbles, high nibble goes first
	andlw   0x0F	    ; select just low nibble
	movwf   LATB, A	    ; output data bits to LCD
	bcf	LATB, LCD_RS, A	; Instruction write clear RS bit
	call    LCD_Enable  ; Pulse enable Bit 
	movf	LCD_tmp, W, A   ; swap nibbles, now do low nibble
	andlw   0x0F	    ; select just low nibble
	movwf   LATB, A	    ; output data bits to LCD
	bcf	LATB, LCD_RS, A	; Instruction write clear RS bit
        call    LCD_Enable  ; Pulse enable Bit 
	return

LCD_Send_Byte_D:
	movwf   LCD_tmp, A
	swapf   LCD_tmp, W, A	; swap nibbles, high nibble goes first

	andlw   0x0F	    ; select just low nibble
	movwf   LATB, A	    ; output data bits to LCD
	bsf	LATB, LCD_RS, A	; Data write set RS bit
	call    LCD_Enable  ; Pulse enable Bit 
	movf	LCD_tmp, W, A	; swap nibbles, now do low nibble
	andlw   0x0F	    ; select just low nibble
	movwf   LATB, A	    ; output data bits to LCD
	bsf	LATB, LCD_RS, A	; Data write set RS bit	    
        call    LCD_Enable  ; Pulse enable Bit 
	movlw	10	    ; delay 40us
	call	LCD_delay_x4us
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
    
; ** a few delay routines below here as LCD timing can be quite critical ****
LCD_delay_ms:		    ; delay given in ms in W
	movwf	LCD_cnt_ms, A
lcdlp2:	movlw	250	    ; 1 ms delay
	call	LCD_delay_x4us	
	decfsz	LCD_cnt_ms, A
	bra	lcdlp2
	return
    
LCD_delay_x4us:		    ; delay given in chunks of 4 microsecond in W
	movwf	LCD_cnt_l, A	; now need to multiply by 16
	swapf   LCD_cnt_l, F, A	; swap nibbles
	movlw	0x0f	    
	andwf	LCD_cnt_l, W, A ; move low nibble to W
	movwf	LCD_cnt_h, A	; then to LCD_cnt_h
	movlw	0xf0	    
	andwf	LCD_cnt_l, F, A ; keep high nibble in LCD_cnt_l
	call	LCD_delay
	return

LCD_delay:			; delay routine	4 instruction loop == 250ns	    
	movlw 	0x00		; W=0
lcdlp1:	decf 	LCD_cnt_l, F, A	; no carry when 0x00 -> 0xff
	subwfb 	LCD_cnt_h, F, A	; no carry when 0x00 -> 0xff
	bc 	lcdlp1		; carry, then loop again
	return			; carry reset so return


    end


