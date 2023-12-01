#include <xc.inc>
    
;Holds all the code required for communication with sensor

global I2C_Setup, I2C_Write_Test
    
psect	I2C_code,class=CODE
    
I2C_Setup:    
    movlw 00101000B 
    movwf SSP1CON1 ; config for master mode
    
    movlw 0x27
    movwf SSP1ADD ; baud rate = 400KHz @ 16MHz
    
    movlw 00000000B 
    movwf SSP1STAT ; slew rate
    
    movlw 00011000B
    iorwf TRISC,F ; SCL and SDA are inputs
    
    return

I2C_Set_Sensor_On: 
    ;Grid-EYE_AMG88X_I2C communication (p2)
    ;21.4.6.1 I2C? Master Mode Operation (p312)
    
    bsf	    SSP1CON2, 0	    ;Generate start condition
    ;SSPxIF is set (bsf PIR1, 3 )
    ;The MSSP module will wait the required start time
    ;before any other operation takes place
    call    check_int
    movlw   110100010B	    ;MS7Bits = slave address, LSB = 0 = Write
    movwf   SSP1BUF
    call    check_AckR
    call    check_int
    movlw   0x00	    ;Power control register address
    movwf   SSP1BUF
    call    check_AckR
    call    check_int
    movlw   0x00	    ;Set sensor to normal mode
    movwf   SSP1BUF
    call    check_AckR
    call    check_int
    bsf	    SSP1CON2, 2	    ;Generate stop condition
    call    check_int
    return
    
check_int:
    btfss PIR1, 3    ;is start condition finished setting up
    bra check_int
    bcf	  PIR1, 3    ;must be cleared by software
    return
    
check_AckR:
    btfsc SSP1CON2, 6; check if ack was received by slave (0 if received)
    bra check_AckR
    return
    


    
Ack_Event:
    bcf SSP1CON2, 5 ; set (ACKDT) bit  to 0
    bsf SSP1CON2, 4 ; set (ACKEN) bit to 1
    return
    
NAck_Event:
    bsf SSP1CON2, 5 ; set (ACKDT) bit to 1
    bsf SSP1CON2, 4 ; set (ACKEN) bit to 0
    return