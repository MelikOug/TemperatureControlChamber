#include <xc.inc>
    
;Holds all the code required for communication with sensor

global I2C_Setup
    
psect	I2C_code,class=CODE
    
I2C_Setup:    
    return
    
    
Mode_Config:
    movlw 00101000B ; setup value
    ; into W register
    banksel SSP1CON1 ; select SFR
    ; bank
    movwf SSP1CON1 ; configure for
    ; Master I2C
    
Bit_Rate_Setup:
    movlw 00001001B ; setup value
    ; into W register
    banksel SSP1ADD ; select SFR bank
    movwf SSP1ADD ; baud rate =
    ; 400KHz @ 16MHz
    
Slew_Rate_Control:
    movlw 00000000B ; setup value
    ; into W register
    movwf SSP1STAT ; slew rate
    ; enabled
    banksel SSP1STAT ; select SFR bank
 
Pin_Setup:
    movlw 00011000B ; setup value
    ; into W register
    banksel TRISC ; select SFR bank
    iorwf TRISC,f ; SCL and SDA
    ; are inputs
   
Ack_Event:
    banksel SSP1CON2 ; select SFR
    ; bank
    bcf SSP1CON2, 5 ; set (ACKDT) bit
    ; state to 0
    bsf SSP1CON2, 4 ; initiate ack (ACKEN)
 
Not_Ack_Event:
    banksel SSP1CON2 ; select SFR
    ; bank
    bsf SSP1CON2, 5 ; set ack bit
    ; state to 1
    bsf SSP1CON2, 4 ; initiate ack

Idle_Check:
    ;i2c_idle ; routine name
    banksel SSP1STAT ; select SFR
    ; bank
    btfsc SSP1STAT,2 ; transmit (R/W)
    ; in progress?
    goto $-1 ; module busy
    ; so wait
    banksel SSP1CON2 ; select SFR
    ; bank
    movf SSP1CON2,w ; get copy
    ; of SSPCON2
    andlw 0x1F ; mask out
    ; non-status
    btfss STATUS,0 ; test for
    ; zero state
    goto $-3 ; bus is busy
    ; test again
    return ; return

