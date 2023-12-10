#include <xc.inc>
    
global  External_Setup, External_Mode
extrn	target, sum_high, LCD_Send_Byte_I, LCD_Send_Byte_D, LCD_delay_x4us, DDRAM_Address
psect	external_code,class=CODE
External_Setup:
    clrf    LATJ
    movlw   0x00
    movwf   TRISJ
    
External_Mode:
    ;Compare current(sum_high) with target
    
    incf    target, W, A	;Add 1 to target and store in WR
    cpfsgt  sum_high, A	;If current value is greater than (target+1), cool
    bra	    check_thresh;If it is not greater than upper threshold, check if in threshold
    bra	    cool
    
check_thresh:
    decf    target, W, A	;Subtract 1 from target and store in WR
    cpfsgt  sum_high, A	;If current value is greater than (target-2) (and less than target+1) turn off
    bra	    heat	;If its less than (target-2), heat
    bra	    off
    
cool: 
    bcf	    LATJ, 0	;Direction  (0)
    bcf	    LATJ, 1	;Brake	    (0)
    bsf	    LATJ, 2	;Duty Cycle (1)
    movlw   10001111B
    call    LCD_Send_Byte_I
    movlw   10
    call    LCD_delay_x4us
    movlw   'C'
    call    LCD_Send_Byte_D
    movf    DDRAM_Address, W, A ;Address after target: (either 1st or 2nd)
    call    LCD_Send_Byte_I
    movlw   10		; wait 40us
    call    LCD_delay_x4us
    return
    
heat: 
    bsf	    LATJ, 0	;Direction  (1)
    bcf	    LATJ, 1	;Brake	    (0)
    bsf	    LATJ, 2	;Duty Cycle (1)
    movlw   10001111B
    call    LCD_Send_Byte_I
    movlw   10
    call    LCD_delay_x4us
    movlw   'H'
    call    LCD_Send_Byte_D
    movf    DDRAM_Address, W, A ;Address after target: (either 1st or 2nd)
    call    LCD_Send_Byte_I
    movlw   10		; wait 40us
    call    LCD_delay_x4us
    return
    
off:
    bcf	    LATJ, 0	;Direction  (0)
    bsf	    LATJ, 1	;Brake	    (1)
    bsf	    LATJ, 2	;Duty Cycle (1)
    movlw   10001111B
    call    LCD_Send_Byte_I
    movlw   10
    call    LCD_delay_x4us
    movlw   'O'
    call    LCD_Send_Byte_D
    
    movf    DDRAM_Address, W, A ;Address after target: (either 1st or 2nd)
    call    LCD_Send_Byte_I
    movlw   10		; wait 40us
    call    LCD_delay_x4us
    return



