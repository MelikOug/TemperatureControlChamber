#include <xc.inc>
    
global  External_Setup, External_Mode
psect	external_code,class=CODE
External_Setup:
    clrf    LATJ
    movlw   0x00
    movwf   TRISJ,A
    
External_Mode:
    ;Compare sum_high and below_point with target_high and target_below_point variable
    
    bcf	    LATJ, 0	;Direction  (0)
    bsf	    LATJ, 1	;Brake	    (1)
    bsf	    LATJ, 2	;Duty Cycle (1)
    return



