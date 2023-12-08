#include <xc.inc>
    
global  UART_Setup, UART_Transmit_Pixels, Pixel_Data, Pixel_Counter
extrn	LCD_delay_ms

psect	udata_acs   ; reserve data space in access ram
UART_counter: ds    1	    ; reserve 1 byte for variable UART_counter
Pixel_Counter:ds    1

psect	uart_code,class=CODE
UART_Setup:
    bsf	    SPEN	; enable
    bcf	    SYNC	; synchronous
    bcf	    BRGH	; slow speed
    bsf	    TXEN	; enable transmit
    bcf	    BRG16	; 8-bit generator only
    movlw   103		; gives 9600 Baud rate (actually 9615)
    movwf   SPBRG1, A	; set baud rate
    bsf	    TRISC, PORTC_TX1_POSN, A	; TX1 pin is output on RC6 pin
					; must set TRISC6 to 1
    return

UART_Transmit_Pixels:	    ; Message stored at FSR2, length is 128
    movlw   130
    movwf   UART_counter, A
    movlw   3
    movwf   Pixel_Counter, A; 3-1 = 2
    lfsr    0, Pixel_Data
UART_Loop_message:
    decfsz  Pixel_Counter, A
    bra	    Continue
    call    Pixel_Delay
    bra	    Continue
    
Continue:
    movf    POSTINC0, W, A  ;Moves data stored at address in FSR0 to WR
    call    UART_Transmit_Byte
    decfsz  UART_counter, A
    bra	    UART_Loop_message
    return
    

UART_Transmit_Byte:	    ; Transmits byte stored in W
    btfss   TX1IF	    ; TX1IF is set when TXREG1 is empty
    bra	    UART_Transmit_Byte
    movwf   TXREG1, A
    return

    
Pixel_Delay:
    movlw   1
    call    LCD_delay_ms
    movlw   2
    movwf   Pixel_Counter, A	;reset pixel counter 
    Return