#include <xc.inc>

;Holds all the code required for communication with sensor

global I2C_Setup, I2C_Set_Sensor_On, I2C_Read_Pixels, I2C_Average_Pixels
global Pixel_Data, overflow, bitnum, numerator, denominator
    
psect	udata_acs	;reserve data in access RAM 
count:	     ds 1
bitnum:	     ds 1
sum_low:     ds 2
sum_high:    ds 2
overflow:    ds 1
numerator:   ds 1
denominator: ds 1

    
psect	udata_bank3	;reserve data in RAM bank 3 (doesnt affect other vars)
Pixel_Data: ds 0x80 ;reserve 128 bytes for temperature data from pixels
    
psect	I2C_code,class=CODE
    
I2C_Setup:    
    clrf    SSP1CON2
    
    bcf	    RCON, 7	    ;(Clear IPEN bit) Disable priority levels on all interrupts (p162)
    bcf	    INTCON, 7	    ;Clear GIE (Disables all interrupts) (p143)
    bcf	    INTCON, 6	    ;Clear PEIE (Disable all peripheral interrupts) (p143)
    
    bsf	    PIE1, 3	    ;Sets SSP1IE Bit (Master Scynchronous Serial Port Interrupt Enable bit (p152) 
    bsf	    IPR1, 3	    ;Master Synchronous Serial Port Interrupt Priority bit = High priorty (p157)
    
    bsf	    TRISC, 3	    ;SCL1 (RC3) and SDA1 (RC4) are inputs (p175)
    bsf	    TRISC, 4
    
    movlw   00000000B	    ;MSB = 0 = Slew-Rate control enabled for 400kHz mode (p292)
    movwf   SSP1STAT	
    
    movlw   0x27	    ;baud rate = 100KHz @ 16MHz (p313)
    movwf   SSP1ADD	
    ;When the MSSP is configured in Master mode, the lower seven
    ;bits of SSPxADD act as the Baud Rate Generator reload value (p291)
    
    movlw   00101000B 
    movwf   SSP1CON1	    ;config for master mode (p293) 
    ;SSPEN <5> = 1 
    ;SSPM <3:0> = 1000 = I2C Master mode: clock = FOSC/(4 * (SSPxADD + 1))
    
    return

I2C_Set_Sensor_On: 
    ;Grid-EYE_AMG88X_I2C communication (p2)
    ;21.4.6.1 I2C Master Mode Operation (p312)
    bcf	    PIR1, 3
    bsf	    SSP1CON2, 0	    ;Generate start condition (p294) 
    ;SSP1IF is set (bsf PIR1, 3 ) when done (p312)
    call    check_int	    ;check to see if done 
    
    
    movlw   11010000B	    ;MS7Bits = slave address, LSB = 0 = Write
    call    load_buff	    ;Send to into buffer which sends out to sensor
			    ;Perform necessary checks before continuing  			    
			    
    movlw   0x00	    ;Power control register address (p2)
    call    load_buff
    
    movlw   0x00	    ;Set sensor to normal mode instruction (p2)
    call    load_buff	    
    
    bsf	    SSP1CON2, 2	    ;Generate stop condition
    call    check_int	    ;Check if SSP1IF is set		
    	    
 
    return
    
I2C_Read_Pixels: 
    ;Grid-EYE_AMG88X_I2C communication (p20)
    ;(p317)
    movlw   128		    ;Number of Pixels to read * 2 (Each pixel sends low and high byte)
    movwf   count, A	    ;Set this value equal to a count variable
    lfsr    0, Pixel_Data   ;loads FSR0 with the address of Pixel_Data in bank3
    
    bsf	    SSP1CON2, 0	    ;Generate start (set SEN bit) condition
    call    check_int	    ;Check if SSP1IF is set
    
    movlw   11010000B	    ;MS7Bits = slave address, LSB = 0 = Write
    call    load_buff
    
    movlw   0x80	    ;Pixel 1 register address  (Grid-EYE p13)
    call    load_buff
    
    bsf     SSP1CON2, 1	    ;Generate  Repeated Start (RSEN) condition (p316)
    call    check_int
    
    movlw   11010001B	    ;MS7Bits = slave address, LSB = 1 = Read
    call    load_buff
    
Read_Loop:
    bsf	    SSP1CON2, 3	    ;Reception mode (RCEN) enabled (p317)
    call    check_int
    movff   SSP1BUF, POSTINC0 ;Moves received data to wherever FSR0 points to in bank3
			    ;Then increments the address in FSR0 ready for the next pixel data
    bcf	    SSP1CON2, 5     ;Clears ACKDT Bit (Prepares and acknowledge)
    bsf	    SSP1CON2, 4	    ;Sets ACKEN bit to transmit ACKDT to sensor
    call    check_int   
		    
    decfsz  count, A	    ;Decrement count variable by 1. Skip if 0.
    bra	    Read_Loop	    ;Repeat until all data is read
			    ;Read last data byte
    bsf	    SSP1CON2, 3	    ;Reception mode (RCEN) enabled (p317)
    call    check_int
    movff   SSP1BUF, POSTINC0 ;Moves received data to wherever FSR0 points to in bank3
    
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
    return
    
check_int:
    btfss   PIR1, 3	    ;is start condition finished setting up
    bra	    check_int	    ;continue polling if not
    bcf	    PIR1, 3	    ;must be cleared by software (manually) 
    return
    
check_AckR:
    btfsc   SSP1CON2, 6	    ;check if ack was received by slave (0 if received)
    bra	    check_AckR	    ;continue polling if not   
    return
  
    
I2C_Average_Pixels:
I2C_Sum_Pixels:
    ;Need to add the contents of all the 64 pixels (12bit) 
    lfsr    0, Pixel_Data   ;loads FSR0 with the address of Pixel_Data in bank3
    movlw   64
    movwf   count, A
    
    movf    POSTINC0, W
    addwf   sum_low, F, A
    
    movf    POSTINC0, W
    addwfc  sum_high, F, A  ;add through carry
    
    decfsz  count, A
    bra     I2C_Rotate_8
    bra	    I2C_Sum_Pixels

    
I2C_Rotate_8:
    movlw   8
    movwf   count	    ;Number of right rotations
    lfsr    0, Pixel_Data
    bcf	    STATUS, 0	    ;clear carry flag
    clrf    overflow, A	    ;clear overflow
    clrf    bitnum, A	    ;tracks the bit num of overflow from 0 to 7
    lfsr    1, bitnum
    movf    INDF1, W
    movlw   00000001B
    movwf   denominator, A	    ;set denominator to 1 for now
    movlw   2
    movwf   count, A
    
loop:
    rlncf   overflow, F, A
    rrcf    INDF0, F, A  ;Rotate right, trigger carry flag
    btfsc   STATUS, 0
    bsf	    overflow,0, A ;set the overflow <value stored in FSR1 address = bitnum>  bit (0 then 1)
    incf    bitnum, F, A
    rlncf   denominator, F, A
    decf    count, F, A
    movlw   0		    ;comparison value for later
    cpfseq  count, A
    call    loop
    movff   overflow, numerator, A	    
    
    
    
    return
    
    
    
    
    