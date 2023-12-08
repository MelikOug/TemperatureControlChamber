#include <xc.inc>

;Holds all the code required for communication with sensor

global I2C_Setup, I2C_Set_Sensor_On, I2C_Read_Pixels, I2C_Average_Pixels
global Pixel_Data, sum_low, sum_high, below_point, count, temp_high
    
psect	udata_acs	;reserve data in access RAM 
count:	     ds 1
sum_low:     ds 1
sum_high:    ds 1
temp_high:   ds 1
below_point: ds 1

    
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
    	    
    ;movlw   00010001B
    ;movwf   LATE
    return
    
I2C_Read_Pixels: 
    ;Grid-EYE_AMG88X_I2C communication (p20)
    ;(p317)
    movlw   128	    ;Number of Pixels to read * 2 (Each pixel sends low and high byte)
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
    lfsr    0, Pixel_Data   ;loads FSR0 with the address of Pixel_Data in bank3
    movlw   64		    ;Number of pixels to read
    movwf   count, A
    clrf    sum_low, A
    clrf    sum_high, A	    ;Will end up being value before dp
    clrf    below_point, A  ;Will end up being value after dp
I2C_Sum_Pixels:
    ;Need to add the contents of all the 64 pixels (4bitH|8bitL) 
    movf    POSTINC0, W
    addwf   sum_low, F, A
    
    movf    POSTINC0, W
    addwfc  sum_high, F, A  ;add through carry
    
    decfsz  count, A
    bra	    I2C_Sum_Pixels
    bra     I2C_Divide_By_256
    
I2C_Divide_By_256:
    ;16 bit number rotated right 8 times (divided by 64 and then by 4 =  divided by 2^8)
    ;	1010 0011 1100 1111 (41935)
    ;-> 0000 0000 1010 0011 | 1100 1111  (163 | 207)
    ;sum_high becomes the integer quotient
    ;suml_low becomes the remainder
    ;41935/256 = 163.80859375
    ;207 * 100,000,000/256 = 80859375 which is our number beyond decimal point
    ;Will round to 1 dp
    ;((207*10) + x)/256 = 8 (iterate through x until result is a whole number)
    ;Fast way to do this is to increment 2070 until lower 8 bits are 0 -> LSB of high byte is incremented
    ;New incremented high byte = 8
    ;Therfore our average number is sum_high . ((HB of 2070)+1)
    
    movf    sum_low, W, A   ;Moves remainder into WR
    mullw   10		    ;Multiply by 10 and store in PRODH|PROD
    incf    PRODH, W, A	    ;increment the high byte of result by one
    movwf   below_point, A
    
    ;Convert sum_high decimal to equal hex
    movlw   0
    movwf   count, A
    movff   sum_high, temp_high, A
ten_loop:
    movlw   10		;move 10 to WR
    subwf   temp_high, F, A ;Subtract 10 from sum_high and store back in sum_high
    btfsc   STATUS, 4	;check if result is negative (sign flag)
    bra	    continue
    incf    count, A
    bra	    ten_loop    ;if not, repeat
    
continue:
    movf    temp_high, W, A
    addlw   10
    movwf   temp_high, A
    swapf   count, W, A ;if is, swap count = 0x0y to 0xy0 and store it  WR
    addwf   temp_high, F, A ;add WR (0xy0) to sum_high (0x0z) and store result (0xyz) back in sum_high
    ;sum_high has been converted from decimal value (ab) to 0xab
    return
    
    
    