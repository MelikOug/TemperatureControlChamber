#include <xc.inc>
    
;Holds all the code required for communication with sensor

global I2C_Setup, I2C_Set_Sensor_On, I2C_Read_Pixel
    
psect	udata_acs	;reserve data in acess RAM 
I2D_Data: ds 1
    
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
    
I2C_Read_Pixel: 
    ;Grid-EYE_AMG88X_I2C communication (p20)
    ;(p317)
    bsf	    SSP1CON2, 0	    ;Generate start (SEN) condition
    call    check_int
    movlw   110100010B	    ;MS7Bits = slave address, LSB = 0 = Write
    movwf   SSP1BUF
    call    check_AckR
    call    check_int
    
    movlw   0x80	    ;Pixel 1 register address
    movwf   SSP1BUF
    call    check_AckR
    call    check_int
    
    bsf     SSP1CON2, 1	    ;Generate  Repeated Start (RSEN) condition
    call    check_int
    movlw   110100011B	    ;MS7Bits = slave address, LSB = 1 = Read
    movwf   SSP1BUF
    call    check_AckR
    call    check_int
    
    bsf	    SSP1CON2, 3	    ;Reception mode (RCEN) enabled
    call    check_int
    movff   SSP1BUF, I2C_Data, A    ;Moves received data to var
    bsf	    SSP1CON2, 5     ;Sets ACKDT Bit (NACK) (NACK only for final)
    bsf	    SSP1CON2, 4	    ;Sets ACKEN bit to transmit ACKDT to slave
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
    
check_AckS:
    btfsc SSP1CON2, 6; check if ack was received by slave (0 if received)
    bra check_AckR
    return