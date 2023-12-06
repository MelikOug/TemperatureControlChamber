#include <xc.inc>

global  LCD_Setup, LCD_Update, LCD_delay_ms
global  LCD_tmp, msg, LCD_counter, LenLine1, LenLine2, Line1, Line2, Line1Array, Line2Array	
    
psect	udata_bank2	;reserve data in RAM bank 2 (doesnt affect other vars)
Line1Array:	ds 0x80 ;reserve 128 bytes for message data for line 1
Line2Array:	ds 0x80 ;reserve 128 bytes for message data for line 1

psect	data	
Line1:
	db	'T','a','r','g','e','t',':',0x0a ;message (in PR), plus carriage return that moves cursor to the end
	LenLine1   EQU	7	; length of data
	align	2				
Line2:
	db	'C','u','r','r','e','n','t',':'  ;message (in PR)	
	db	'N','/','A'
	LenLine2   EQU	11	; length of data
	align	2
					
psect	udata_acs   ; named variables in access ram
LCD_cnt_l:	ds 1   ; reserve 1 byte for variable LCD_cnt_l
LCD_cnt_h:	ds 1   ; reserve 1 byte for variable LCD_cnt_h
LCD_cnt_ms:	ds 1   ; reserve 1 byte for ms counter
LCD_tmp:	ds 1   ; reserve 1 byte for temporary use
LCD_counter:	ds 1   ; reserve 1 byte for counting through nessage
counter:	ds 1   ; reserve one byte for a counter variable
LCD_E	EQU 5	; LCD enable bit
LCD_RS	EQU 4	; LCD register select bit

	
	
psect	lcd_code,class=CODE

	
LCD_Setup:
	clrf    LATB, A
	movlw   11000000B	    ; RB0:5 all outputs
	movwf	TRISB, A
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
	
	lfsr	1, LenLine2
	call	LCD_Frame
	return

	
LCD_Frame:
		
;Current Line2    
	lfsr	0, Line2Array		; Load FSR0 with address in bank 2	
	movlw	low highword(Line2)	; address of data in PM
	movwf	TBLPTRU, A		; load upper bits to TBLPTRU
	movlw	high(Line2)		; address of data in PM
	movwf	TBLPTRH, A		; load high byte to TBLPTRH
	movlw	low(Line2)		; address of data in PM
	movwf	TBLPTRL, A		; load low byte to TBLPTRL
	movlw	LenLine2		; bytes to read
	movwf 	counter, A		; our counter register
loop: 	tblrd*+				; one byte from PM to TABLAT, increment TBLPRT
	movff	TABLAT, POSTINC0	; move data from TABLAT to (where FSR0 points), inc FSR0	
	decfsz	counter, A		; count down to zero
	bra	loop			; keep going until finished
	lfsr	2, Line2Array		; Moves address of Line2Array in FSR2
	movlw	LenLine2		; Moves address LenLine2 (11) into WR
	call	LCD_Write_Message

;Current Line1    
lfsr	0, Line1Array			; Load FSR0 with address in RAM	
	movlw	low highword(Line1)	; address of data in PM
	movwf	TBLPTRU, A		; load upper bits to TBLPTRU
	movlw	high(Line1)		; address of data in PM
	movwf	TBLPTRH, A		; load high byte to TBLPTRH
	movlw	low(Line1)		; address of data in PM
	movwf	TBLPTRL, A		; load low byte to TBLPTRL
	movlw	LenLine1		; bytes to read
	movwf 	counter, A		; our counter register
loop2: 	tblrd*+				; one byte from PM to TABLAT, increment TBLPRT
	movff	TABLAT, POSTINC0	; move data from TABLAT to (FSR0), inc FSR0	
	decfsz	counter, A		; count down to zero
	bra	loop2			; keep going until finished
	lfsr	2, Line1Array
	movlw	LenLine1		; Moves address of LenLine1 to WR 
	call	LCD_Write_Message
	return
	
	
LCD_Write_Message:	    
	cpfseq	FSR1			;compares WR to address in FSR1 (11)
	bra	LDC_Set_Line1
	bra	LDC_Set_Line2
	
LDC_Set_Line1:
	movwf	LCD_counter, A
	movlw	10000000B
	call	LCD_Send_Byte_I
	movlw	10		; wait 40us
	call	LCD_delay_x4us
	bra	LCD_Loop_message
	
LDC_Set_Line2:
	movwf	LCD_counter, A
	movlw	11000000B
	call	LCD_Send_Byte_I
	movlw	10		; wait 40us
	call	LCD_delay_x4us
	bra	LCD_Loop_message
	
	
LCD_Loop_message:
	movf    POSTINC2, W, A  ; Move value stored at FSR2 address to WR, Inc address
	call    LCD_Send_Byte_D
	decfsz  LCD_counter, A
	bra	LCD_Loop_message
	return

	
	;movlw   0xC0
	;call    LCD_Send_Byte_I	;changes LCD Output to 2nd line
	
	
	
LCD_Update:
    
Test_None:
	movlw	0xFF
	cpfseq	msg, A	;is msg = 0xFF -> return if True
	bra	Test_C	
	return
	    
Test_C:
	movlw	0x43
	cpfseq	msg, A	;is msg = 'C' -> call clear subroutine
	bra Test_E	
	bra	LCD_Clear
Test_E:
	movlw	0x45
	cpfseq	msg, A	;is msg = 'E' -> call enter subroutine
	bra	Update
	bra	LCD_Enter
	
LCD_Clear:
	movlw   0x01    ;sends 01 as instruction (this clears LCD)
	call    LCD_Send_Byte_I
	movlw	2
	call	LCD_delay_ms	; wait 2ms for LCD to start up properly		
	;call	LCD_delay_x4us ; wait 40us
	call	LCD_Frame
	
	return  ;returns to main.s
    
LCD_Enter:
	;Read number after "target:"
	;Send system message to change temp to target temp
	return

Update:
	;movlw	00000110B	; entry mode incr by 1 no shift
	;call	LCD_Send_Byte_I
	movf	msg, W, A; Transmits byte stored in msg to data reg
	call	LCD_Send_Byte_D
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


