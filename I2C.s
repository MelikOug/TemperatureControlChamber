#include <xc.inc>
    
;Holds all the code required for communication with sensor

global I2C_Setup
    
psect	I2C_code,class=CODE
    
I2C_Setup:    
    return
    
    
Mode_Config:
    movlw 00101000B ; setup value
    ; into W register
    banksel SSPCON1 ; select SFR
    ; bank
    movwf SSPCON1 ; configure for
    ; Master I2C
    
Bit_Rate_Setup:
    movlw 00001001B ; setup value
    ; into W register
    banksel SSPADD ; select SFR bank
    movwf SSPADD ; baud rate =
    ; 400KHz @ 16MHz
    
Slew_Rate_Control:
    movlw 00000000B ; setup value
    ; into W register
    movwf SSPSTAT ; slew rate
    ; enabled
    banksel SSPSTAT ; select SFR bank
 
Pin_Setup:
    movlw 00011000B ; setup value
    ; into W register
    banksel TRISC ; select SFR bank
    iorwf TRISC,f ; SCL and SDA
    ; are inputs
   
Ack_Event:
    banksel SSPCON2 ; select SFR
    ; bank
    bcf SSPCON2, ACKDT ; set ack bit
    ; state to 0
    bsf SSPCON2, ACKEN ; initiate ack
 
Not_Ack_Event:
    banksel SSPCON2 ; select SFR
    ; bank
    bsf SSPCON2, ACKDT ; set ack bit
    ; state to 1
    bsf SSPCON2, ACKEN ; initiate ack

Idle_Check:
    ;i2c_idle ; routine name
    banksel SSPSTAT ; select SFR
    ; bank
    btfsc SSPSTAT,R_W ; transmit
    ; in progress?
    goto $-1 ; module busy
    ; so wait
    banksel SSPCON2 ; select SFR
    ; bank
    movf SSPCON2,w ; get copy
    ; of SSPCON2
    andlw 0x1F ; mask out
    ; non-status
    btfss STATUS,Z ; test for
    ; zero state
    goto $-3 ; bus is busy
    ; test again
    return ; return

