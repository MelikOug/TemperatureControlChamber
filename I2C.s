#include <xc.inc>
    
;Holds all the code required for communication with sensor

global I2C_Setup, I2C_Set_Sensor_On, I2C_Read_Pixel, I2C_Data
    
    
psect	udata_acs	;reserve data in access RAM 
I2C_Data: ds 1
count:	  ds 1
    
psect	udata_bank3	;reserve data in RAM bank 3 (doesnt affect other vars)
Pixel_Data:	ds 0x80 ;reserve 128 bytes for temperature data from pixels
    
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
    ;21.4.6.1 I2C? Master Mode Operation (p312+317)
    ;
    bsf	    SSP1CON2, 0	    ;Generate start condition
			    ;SSPxIF is set (bsf PIR1, 3 ) when done
    call    check_int	    ;check to see if done
    movlw   110100010B	    ;MS7Bits = slave address, LSB = 0 = Write
    call    load_buff	    ;Send to into buffer which sends out to sensor
			    ;Perform necessary checks before continuing
			    
    movlw   0x00	    ;Power control register address (p2)
    call    load_buff
    
    movlw   0x00	    ;Set sensor to normal mode instruction (p2)
    call    load_buff	    
    
    bsf	    SSP1CON2, 2	    ;Generate stop condition
			    ;SSPxIF is set (bsf PIR1, 3 ) when done
    call    check_int	    
    return
    
I2C_Read_Pixel: 
    ;Grid-EYE_AMG88X_I2C communication (p20)
    ;(p317)
    lfsr    0, Pixel_Data   ;loads FSR0 with the address of Pixel_Data in bank3
    bsf	    SSP1CON2, 0	    ;Generate start (SEN) condition
    call    check_int
    
    movlw   110100010B	    ;MS7Bits = slave address, LSB = 0 = Write
    call    load_buff
    
    movlw   0x80	    ;Pixel 1 register address  (Grid-EYE p13)
    call    load_buff
    
    bsf     SSP1CON2, 1	    ;Generate  Repeated Start (RSEN) condition (p316)
    call    check_int
    
    movlw   110100011B	    ;MS7Bits = slave address, LSB = 1 = Read
    call    load_buff
    
    movlw   128		    ;Number of Pixels to read * 2 (Each pixel sends low and high byte)
    movwf   count, A	    ;Set this value equal to a count variable
    bsf	    SSP1CON2, 3	    ;Reception mode (RCEN) enabled (p317)
    call    check_int
Read_Loop:
    movff   SSP1BUF, POSTINC0 ;Moves received data to wherever FSR0 points to in bank3
			    ;Then increments the address in FSR0 ready for the next pixel data
    bcf	    SSP1CON2, 5     ;Clears ACKDT Bit (Prepares and acknowledge)
    call    check_int
    bsf	    SSP1CON2, 4	    ;Sets ACKEN bit to transmit ACKDT to sensor
    call    check_int	    
    decfsz  count, A	    ;Decrement count variable by 1. Skip if 0.
    bra	    Read_Loop	    ;Repeat until all data is read
    
    bsf	    SSP1CON2, 5     ;Sets ACKDT Bit (NACK) (NACK only for final)
    bsf	    SSP1CON2, 4	    ;Sets ACKEN bit to transmit ACKDT to slave
    call    check_int	    
    
    bsf	    SSP1CON2, 2	    ;Generate stop condition
    call    check_int
    return
    
    
    
    
    
load_buff:
    movwf   SSP1BUF
    call    check_AckR
    call    check_int
    
check_int:
    btfss   PIR1, 3	    ;is start condition finished setting up
    bra	    check_int	    ;continue polling if not
    bcf	    PIR1, 3	    ;must be cleared by software (manually)
    return
    
check_AckR:
    btfsc SSP1CON2, 6	    ;check if ack was received by slave (0 if received)
    bra check_AckR	    ;continue polling if not
    return
   