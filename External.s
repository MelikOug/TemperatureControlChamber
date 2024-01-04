#include <xc.inc>
  
;Holds the code that controls the heating part of the system    

global  External_Setup, External_Mode
    
extrn	target, sum_high, DDRAM_Address
extrn	LCD_Send_Byte_I, LCD_Send_Byte_D, LCD_delay_x4us
psect	external_code,class=CODE
    
External_Setup:
    clrf    LATJ
    movlw   0x00
    movwf   TRISJ		;Set all pins to output
    bsf	    LATJ, 2		;Duty Cycle (1)
    
External_Mode:
    ;Compare current temperature (sum_high value) (above the decimal point) with target
    ;Leaves peltier off when within range of 1 degree C either side of sum_high
    movf    target, W, A	
    
    cpfsgt  sum_high, A		;If sum_high value is greater than (target), cool
    bra	    check_heat		;If it is not greater than target, check if need to heat
    bra	    cool
    
check_heat:	
    decf    target, W, A
    cpfslt  sum_high, A		;If sum_high value is less than target-1, heat
    bra	    off			;If is not greater but not less than, turn off
    bra	    heat
    
cool: 
    bsf	    LATJ, 0		;Direction  (1)
    bcf	    LATJ, 1		;Brake	(0)
    movlw   10001111B
    call    LCD_Send_Byte_I	;Sets DDRAM address to bottom right square
    movlw   10
    call    LCD_delay_x4us	;wait 40us
    movlw   'C'
    call    LCD_Send_Byte_D	;writes 'C' to LCD to indicate cooling
    movf    DDRAM_Address, W, A ;Address after target: (either 1st or 2nd)
    call    LCD_Send_Byte_I	;revert DDRAM address back to what it was before
    movlw   10			
    call    LCD_delay_x4us	;wait 40us
    return
    
heat: 
    bcf	    LATJ, 0		;Direction  (0)
    bcf	    LATJ, 1		;Brake	(0)
    movlw   10001111B
    call    LCD_Send_Byte_I	;Sets DDRAM address to bottom right square
    movlw   10
    call    LCD_delay_x4us	;wait 40us
    movlw   'H'
    call    LCD_Send_Byte_D	;writes 'H' to LCD to indicate heating
    movf    DDRAM_Address, W, A 
    call    LCD_Send_Byte_I	;revert DDRAM address back to what it was before
    movlw   10			
    call    LCD_delay_x4us	
    return
    
off:
    bsf	    LATJ, 1		;Brake	(1)
    movlw   10001111B
    call    LCD_Send_Byte_I	;Sets DDRAM address to bottom right square
    movlw   10
    call    LCD_delay_x4us	;writes 'O' to LCD to indicate peltier is off
    movlw   'O'
    call    LCD_Send_Byte_D
    
    movf    DDRAM_Address, W, A 
    call    LCD_Send_Byte_I	;revert DDRAM address back to what it was before
    movlw   10			
    call    LCD_delay_x4us
    return



