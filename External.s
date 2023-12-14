#include <xc.inc>
    
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
    ;Compare current(sum_high) with target
    movf    target, W	
    
    cpfsgt  sum_high, A		;If current value is greater than (target), cool
    bra	    check_heat		;If it is not greater than target, check if need to heat
    bra	    cool
    
check_heat:			
    cpfslt  sum_high, A		;If current value is less than target, heat
    bra	    off			;If is not greater but not less than, turn off
    bra	    heat
    
cool: 
    bsf	    LATJ, 0		;Direction  (0)
    bcf	    LATJ, 1		;Brake	(0)
    movlw   10001111B
    call    LCD_Send_Byte_I
    movlw   10
    call    LCD_delay_x4us
    movlw   'C'
    call    LCD_Send_Byte_D
    movf    DDRAM_Address, W, A ;Address after target: (either 1st or 2nd)
    call    LCD_Send_Byte_I
    movlw   10			;wait 40us
    call    LCD_delay_x4us
    return
    
heat: 
    bcf	    LATJ, 0		;Direction  (1)
    bcf	    LATJ, 1		;Brake	(0)
    movlw   10001111B
    call    LCD_Send_Byte_I
    movlw   10
    call    LCD_delay_x4us
    movlw   'H'
    call    LCD_Send_Byte_D
    movf    DDRAM_Address, W, A ;Address after target: (either 1st or 2nd)
    call    LCD_Send_Byte_I
    movlw   10			;wait 40us
    call    LCD_delay_x4us
    return
    
off:
    bcf	    LATJ, 0		;Direction  (0)
    bsf	    LATJ, 1		;Brake	(1)
    movlw   10001111B
    call    LCD_Send_Byte_I
    movlw   10
    call    LCD_delay_x4us
    movlw   'O'
    call    LCD_Send_Byte_D
    
    movf    DDRAM_Address, W, A ;Address after target: (either 1st or 2nd)
    call    LCD_Send_Byte_I
    movlw   10			;wait 40us
    call    LCD_delay_x4us
    return



