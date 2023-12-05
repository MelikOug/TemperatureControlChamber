#include <xc.inc>
    
global  External_Setup

External_Setup:
    clrf    LATF
    movlw   0x00
    movwf   TRISF,A
    bcf	    LATF, 0
    return



