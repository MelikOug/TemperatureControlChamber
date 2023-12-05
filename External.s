#include <xc.inc>
    
global  External_Setup
psect	external_code,class=CODE
External_Setup:
    clrf    LATJ
    movlw   0x00
    movwf   TRISJ,A
    
    bsf	    LATJ, 0	;Direction
    bcf	    LATJ, 1	;Brake
    bsf	    LATJ, 2	;Duty Cycle
    return



