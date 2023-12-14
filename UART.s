#include <xc.inc>
    
global  UART_Setup, UART_Transmit_Pixels, Pixel_Data, Pixel_Counter

;reserve data space in access ram for variables
psect	udata_acs		
UART_counter: ds    1		
Pixel_Counter:ds    1

psect	uart_code,class=CODE
UART_Setup:
    bsf	    SPEN		    ;enable
    bcf	    SYNC		    ;synchronous
    bcf	    BRGH		    ;slow speed
    bsf	    TXEN		    ;enable transmit
    bcf	    BRG16		    ;8-bit generator only
    movlw   103			    ;gives 9600 Baud rate (actually 9615)
    movwf   SPBRG1, A		    ;set baud rate
    bsf	    TRISC, PORTC_TX1_POSN, A	;TX1 pin is output on RC6 pin
					;must set TRISC6 to 1
    return

UART_Transmit_Pixels:	    
    movlw   128
    movwf   UART_counter, A	    ;Moves number of bytes to transmit to counter variable
    lfsr    0, Pixel_Data	    ;FSR0 holds the address of the low byte of the first pixel
    
UART_Loop_message:
    movf    POSTINC0, W, A	    ;Moves data stored at address in FSR0 to WR. Incrememnts FSR0.
    call    UART_Transmit_Byte	    ;Transmits data in WR
    decfsz  UART_counter, A	    ;Decrements counter. Skip if 0.
    bra	    UART_Loop_message	    ;Repeat until counter is 0
    
    movlw   0x0A		
    call    UART_Transmit_Byte	    ;Send End Byte (b'\n') 
    return
    

UART_Transmit_Byte:	    
    btfss   TX1IF		    ;TX1IF is set when TXREG1 is empty, skip if set
    bra	    UART_Transmit_Byte	    ;Keep polling
    movwf   TXREG1, A		    ;When TXREG1 is empty, move WR into it to transmit
    return
