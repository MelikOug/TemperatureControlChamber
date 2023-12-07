#include <xc.inc>
    
global  External_Setup
psect	external_code,class=CODE
External_Setup:
    clrf    LATJ
    movlw   0x00
    movwf   TRISJ,A
    
    bcf	    LATJ, 0	;Direction  (0)
    bsf	    LATJ, 1	;Brake	    (1)
    bsf	    LATJ, 2	;Duty Cycle (1)
    return



