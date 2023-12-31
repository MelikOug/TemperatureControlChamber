#include <xc.inc>

;Holds all the code required for communication with sensor

global I2C_Setup, I2C_Set_Sensor_On, I2C_Read_Pixels, I2C_Average_Pixels
global Pixel_Data, sum_high, below_point, temp_high
    
psect	udata_acs	    ;Reserve data in access RAM for variables that will be used
count:	     ds 1
sum_low:     ds 1
sum_high:    ds 1
temp_high:   ds 1
below_point: ds 1

    
psect	udata_bank3	    ;reserve data in RAM bank 3 (doesn't overwrite other variables)
Pixel_Data: ds 0x80	    ;reserve 128 bytes for temperature data from pixels
    
psect	I2C_code,class=CODE
    
I2C_Setup:        
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
    bcf	    PIR1, 3	    ;Clears the SSP1IF which is due to be set upon completion of start condition
    bsf	    SSP1CON2, 0	    ;Generate start condition (p294) 
    ;SSP1IF is set (bsf PIR1, 3 ) when done (p312)
    call    check_int	    ;check to see if done 
    
    movlw   11010000B	    ;MS7Bits = slave address, LSB = 0 = Write
    call    load_buff	    ;Send to into buffer which sends out to sensor
			    ;Perform necessary checks before continuing  			    
			    
    movlw   0x00	    ;Power control register address (p2)
    call    load_buff
    
    movlw   0x00	    ;Set sensor to normal operating mode instruction (p2)
    call    load_buff	    
    
    bsf	    SSP1CON2, 2	    ;Generate stop condition
    call    check_int	    		
    	 
    return
    
I2C_Read_Pixels: 
    ;Grid-EYE_AMG88X_I2C communication (p20)
    ;(p317)
    movlw   128		    ;(Number of Pixels to read) * 2 (Each pixel sends low (8bit) and high byte (4bit))
    movwf   count, A	    ;Set this value equal to a count variable
    lfsr    0, Pixel_Data   ;loads FSR0 with the address of Pixel_Data in bank3
    
    bsf	    SSP1CON2, 0	    ;Generate start (set SEN bit) condition
    call    check_int	   
    
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
    bcf	    SSP1CON2, 5     ;CLEARS ACKDT Bit (Prepares and acknowledge)
    bsf	    SSP1CON2, 4	    ;Sets ACKEN bit to transmit ACKDT to sensor
    call    check_int   
		    
    decfsz  count, A	    ;Decrement count variable by 1. Skip if 0.
    bra	    Read_Loop	    ;Repeat until all data is read
    
			    ;Read last data byte
    bsf	    SSP1CON2, 3	    ;Reception mode (RCEN) enabled (p317)
    call    check_int
    movff   SSP1BUF, POSTINC0 ;Moves received data to wherever FSR0 points to in bank3
    
    bsf	    SSP1CON2, 5     ;SETS ACKDT Bit (NACK)-(NACK only for final)
    bsf	    SSP1CON2, 4	    ;Sets ACKEN bit to transmit ACKDT to slave
    call    check_int	    
    
    bsf	    SSP1CON2, 2	    ;Generate stop condition
    call    check_int
    return
   
load_buff:
    movwf   SSP1BUF	    ;Move WR to output buffer which be sent to sensor
    call    check_AckR	   
    call    check_int
    return
    
check_int:
    btfss   PIR1, 3	    ;is SSP1IF set? (Previous action finished setting up?)
    bra	    check_int	    ;continue polling if not
    bcf	    PIR1, 3	    ;Clear SSP1IF and proceed
    return
    
check_AckR:
    btfsc   SSP1CON2, 6	    ;check if ack was received by slave (0 if received)
    bra	    check_AckR	    ;continue polling if not   
    return
  
    
    
    
I2C_Average_Pixels:	    ;The Subroutine calculates the average temperature across al pixels
    lfsr    0, Pixel_Data   ;loads FSR0 with the address of Pixel_Data in bank3
    movlw   64		    
    movwf   count, A	    ;Count variable = number of pixels to read
    
    ;Adding 12bit numbers requires two 8bit file registers to store result
    clrf    sum_low, A	    ;Will end up being the remainder
    clrf    sum_high, A	    ;Will end up being value before dp
    clrf    below_point, A  ;Will end up being value after dp
I2C_Sum_Pixels:
    ;Need to add the contents of all the 64 pixels (4bitH|8bitL) 
    movf    POSTINC0, W	    ;Moves the value stored in address in FSR0 to WR. Inc FSR0
    addwf   sum_low, F, A   ;Adds WR to sum_low file register
    
    movf    POSTINC0, W
    addwfc  sum_high, F, A  ;Add through carry generated by previous addition
    
    decfsz  count, A	    ;Decrement count by 1, skip if 0
    bra	    I2C_Sum_Pixels  ;Continue process with next pixel
    bra     I2C_Divide_By_256; Proceed to division stage
    
I2C_Divide_By_256:
    ;The temperature sensor sends the data where the actual temperature, in Celsius,
    ;is the decimal value divided by 4
    ;E.g: 0000 0000 0001 = 0.25 degrees C, 0000 1000 0000 = 32 degrees C
    ;16 bit number must be rotated right 8 times (divided by 64 and then by 4 =  divided by 2^8)
    ;	1010 0011 1100 1111 (41935)
    ;-> 0000 0000 1010 0011 | 1100 1111  (163 | 207)
    ;sum_high (MS 8 bits) becomes the integer quotient (163)
    ;suml_low (LS 8 bits) becomes the remainder (207)
    ;41935/256 = 163.80859375
    ;207*(10^8)/256 = 80859375 which is our number beyond decimal point
    ;Will round to UP to 1 dp
    ;((207*10^1) + x)/256 = y = 9 (iterate through x until result is a whole number y)
    ;Fast way to do this is to increment numerator (in this case 2070) until lower 8 bits are 0
    ;This is because we are dividing by 256 (rotating right 8 times) and want an integer
    ;2070 = 0000 1000 0001 0110, we want the smallest number greater than 2070 that satisfies this condition
    ;This number is therefore 0000 1001 0000 0000
    ;When this condition is met, the LSB of the high byte is thus, incremented
    ;New incremented high byte/256 = 9
    ;Therfore our average number is: [sum_high], ".", [(HB of (sum_low*10))+1]
    
    movf    sum_low, W, A   ;Moves remainder into WR
    mullw   10		    ;Multiply by 10 and store in {PRODH(HB) PROD(LB)}
    incf    PRODH, W, A	    ;Increment the high byte of result by one
    movwf   below_point, A  ;Move WR to below_point variable
    
    ;Checks to see if rounding up results in 10 below dp
    movlw   10
    cpfseq  below_point, A  ;Is below point = 10? Skip if True
    bra	    convert	    ;Continue to next section
    movlw   0		    
    movwf   below_point, A  ;If it is, set it to 0
    incf    sum_high, A	    ;increment value before decimal point
			    ;E.g: 20.10 -> 21.0 
    
convert:
    ;This section converts our 2 digit decimal (ab) to 0xab
    ;so that it can be easily manipulated to output to LCD
    movlw   0
    movwf   count, A	    
    movff   sum_high, temp_high, A  ;temp_high will store this 0xab version
    
    ;This section sees how many tens can be subtracted from temp_high until negative result
ten_loop:
    movlw   10	
    subwf   temp_high, F, A ;Subtract 10 from temp_high and store back in temp_high
    btfsc   STATUS, 4	    ;Check if result is negative (sign flag), skip if positive
    bra	    continue	    
    incf    count, A	    ;Counts how many times 10 is subtracted
    bra	    ten_loop	    ;Repeat process until result is negative
    
continue:
    movf    temp_high, W, A ;Move temp_high (which is now negative) to WR
    addlw   10		    ;Adds 10 to WR to make it (0b) in decimal = 0x0b
    movwf   temp_high, A    ;Move WR back into temp_high
    swapf   count, W, A	    ;Swap count = a = 0x0a to 0xa0 and store it  WR
			    ;y = the tens digit in decimal form (a in (ab))
    addwf   temp_high, F, A ;add WR (0xa0) to temp_high (0x0b) and store result (0xab) back in temp_high
    ;sum_high has been converted from decimal value (ab) to 0xab 
    ;which is now stored in temp_high and ready to be used by LCD.S
    return
    
    
    
