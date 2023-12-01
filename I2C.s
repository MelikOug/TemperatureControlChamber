#include <xc.inc>
    
;Holds all the code required for communication with sensor

global I2C_Setup, I2C_Write_Test
    
psect	I2C_code,class=CODE
    
I2C_Setup:    
    call Mode_Config
    call Bit_Rate_Setup
    call Slew_Rate_Control
    call Pin_Setup
    return

I2C_Write_Test:
    movlw 11010000B ; load value
    ; into W
    movwf SSP1BUF ; initiate I2C
    ; write cycle
    ; This code checks for completion of I2C
    ; write event
    btfsc SSP1STAT, 2 ; test write bit (R/W bit)
; state
    goto $-1 ; module busy
    
    
I2C_Read_Event:
    ; bank
    bsf SSP1CON2,3 ; initiate (RCEN Bit)
    ; I2C read
    ; This code checks for completion of I2C
    ; read event
    btfsc SSP1CON2,3 ; test read(RCEN Bit)
    ; bit state
    goto $-1 ; module busy
    ; so wait
    return
    

    
Mode_Config:
    movlw 00101000B ; setup value
    ; into W register
    banksel SSP1CON1 ; select SFR
    ; bank
    movwf SSP1CON1 ; configure for
    ; Master I2C
    return
    
Bit_Rate_Setup:
    movlw 0x27 ; setup value
    ; into W register
    movwf SSP1ADD ; baud rate =
    ; 400KHz @ 16MHz
    return
    
Slew_Rate_Control:
    movlw 00000000B ; setup value
    ; into W register
    movwf SSP1STAT ; slew rate
    ; enabled
    return
 
Pin_Setup:
    movlw 00011000B ; setup value
    ; into W register
    iorwf TRISC,F ; SCL and SDA
    ; are inputs
    return
    
Ack_Event:
    ; bank
    bcf SSP1CON2, 5 ; set (ACKDT) bit
    ; state to 0
    bsf SSP1CON2, 4 ; initiate ack (ACKEN)
    return
    
Not_Ack_Event:
    ; bank
    bsf SSP1CON2, 5 ; set ack bit
    ; state to 1
    bsf SSP1CON2, 4 ; initiate ack
    return
    
Idle_Check:
    ;i2c_idle ; routine name
    ; bank
    btfsc SSP1STAT,2 ; transmit (R/W)
    ; in progress?
    goto $-1 ; module busy
    ; so wait
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

