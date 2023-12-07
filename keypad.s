#include <xc.inc>
    
global  KEY_Setup, KEY_Read_Message
global  state, val, col_val, row_val, num, Bindex, pos, msg
extrn	LCD_delay_ms

psect	udata_acs   ;reserve data space in access ram
state:	    ds 1
col_val:    ds 1
row_val:    ds 1
val:	    ds 1
num:	    ds 1
Bindex:	    ds 1
pos:	    ds 1
msg:	    ds 1

psect	data
map:		    ;stores map of keypad in program memory (psect data)
    db '1', '2', '3', 'F'
    db '4', '5', '6', 'E'
    db '7', '8', '9', 'D'
    db  'A', '0','B', 'C'
    align 2	    ;program memory must be shifter to even final byte address numbers (i.e. 0,2,4...)
    ;can check address of this map by opening file memory window, 
    ;selcting format Hex, filter ASCII and typing in a relevant letter)
    
psect	key_code,class=CODE

KEY_Setup:	    ;sets up Keypad
    movlb   15
    bsf	    REPU
    clrf    LATE    ;clears LATE   
    clrf    LATH    ;clears LATH
    clrf    PORTH   ;clears PORTH (just to be sure could probably remove)
    movlw   0x0F
    movwf   state, A	;defines 'state' to be 0x0F or 0000 1111
    clrf    col_val, A	;Next lines reset variables
    clrf    row_val, A
    clrf    val, A
    clrf    num, A
    movlw   0x00
    movwf   TRISH	    ;sets all pins to outputs (0000 0000) on PORTH   
    movff   state, TRISE    ;sets pins 0,1,2,3 to inputs on PORTE
    return
    

KEY_Read_Message:	    
    movf  PORTE, W, A	    ;move value in PORTE to WR
    XORWF state, W, A	    ;Exclusive OR WR (PORTE) with State. If PORTE is default -> 0000 0000
    movwf LATH		    ;move value in WR to PORTH
    movff LATH, val	    ;move value in LATH to variable val
    
KEY_Find_CorR:
test_None:		    ;test to see if anything is pressed
    movlw   0x00	    
    cpfseq  val, A	    ;compares val with 0x00
    bra	    test_end	    ;if not equal, branch to test_end
    ;bra		    ;KEY_Read_Message;if equal, read message again
    movlw   0x00
    movwf   msg, A
    return		    ;If equal set msg to 0xFF and return
   
test_end:		    ;test to see if this is the end of number reading process
    clrf    Bindex, A	    ;Clears Bindex
    bsf	    Bindex, 0, A    ;Sets LSB to 1 -> Bindex = 0x01
    movlw   0x00
    cpfseq  col_val, A	    ;sees if col_val = 0 (check for value in col_val)
    bra     decode	    ;if col_val not 0, we are in the second stage of reading so we go to decode
    bra	    switch_to_row   ;if col_val is 0, switch to row stage
    
      
check_bit_loop:		 ;subroutine to convert values of  (1,2,4,8) to (1,2,3,4)
    btfss   val, 0, A    ;check if LSB is 1 (skip if 1) (will either be 1,2,4 or 8)
    bra continue	 ;if not 1, branch to continue
    return
continue:
    rrncf   val, A	;shifts val to the right i.e (0000 0010) -> (0000 0001)
    incf    Bindex, A	;increments Bindex by 1 (think of it like a shift counter)
    bra	    check_bit_loop ;repeat process
        
    
    
switch_to_row:
    call    check_bit_loop
    movff   Bindex, col_val, A	;moves Bindex (shift counter) returned by check_bit_loop to col_val
    
    movlw   0xF0
    movwf   state, A
    movff   state, TRISE    ;sets input pins to 4,5,6,7 ready for row testing stage
    movlw   10
    call    LCD_delay_ms	    ;delay 10ms so that TRISE pins have time to settle
    
    bra	    KEY_Read_Message	;read message from keypad again
  
decode:
    swapf   val,F, A	    ;in this stage val will be either (0x80,0x40,0x20 or 0x10) we want to swap nibbles (4bit sections) 
    call    check_bit_loop  ;swapped val is passed into this subroutine to determine shift
    swapf   Bindex,F, A	    ;returned shift swapped from either (0x01,0x02,0x03,0x04) to (0x10,0x20,0x30,0x40)
    movff   Bindex, row_val, A	;value moved to row value
    
    movf    col_val, W, A
    addwf   row_val, W, A
    movwf   num, A	    ;num is the addition of both col_val with row_val to give a number that is (row_val,col_val)
    
    ;convert num to corresponding character on keypad map
    ;address in program memory is 21 bits long split into 5 (low highword), 8 (high) and 8 (low)
    movlw   low highword(map)	;moves highest 5bits of address of map in program memory to WR
    movwf   TBLPTRU, A		;moves these 5bits to tablepointer upper file reg
    movlw   high (map)		;moves middle 8bits of address of map in program memory to WR
    movwf   TBLPTRH, A		;moves middle 8bits of address of map in program memory to WR
    ;These parts of the address remain constant for all values in keypad map
    ;Only the lower 8 bits differ for each value
    
    movf    num, W, A		;moves out num (map coordinate) to WR
    andlw   0x0F		;moves the first byte (column index) to WR
    addlw   0xFF		;actually decrements W by 1 (following maths requires 0-based indexing hence the -1)
    movwf   pos, A		;moves this value to a variable called position 
				;(which is the number of values you need to move along linear the map to get appropriate value)
    
    swapf   num, W, A		;swaps the nibbles in num and stores in WR (row,col) -> (col,row)
    andlw   0x0F		;moves first byte (row index) to WR
    addlw   0xFF		;dec W by 1
    mullw   0x04		;multiplies this new row index by 4, result auto stored in PROD register
    movf    PROD, W		;moves value in PROD to WR
    addwf   pos, A		;adds WR to pos and stores in pos
   
    movlw   low (map)		;moves the address of lowest 8bits of map in program memory to WR
				;these are the ones that change depending on value 
    addwf   pos, W, A		;adds position along the map line to this address
    movwf   TBLPTRL, A		;moves this new 8 bit address to TBLPTRL
    TBLRD*			;reads the combined address of TBLPTRU|TBLPTRH|TBLPTRU from program memory and stores result in TABLAT

test_continue:			;test to see if button is still being held
    movf    PORTE, W, A		;move value in PORTE to WR
    XORWF   state, W, A		;Exclusive OR WR (PORTE) with State (Should be same value)
    movwf   LATH			;move value in WR to LATH
    movff   LATH, val		;moves value of LATH to val
    movlw   0x00		
    cpfseq  val, A		;is val = 0 (button off). If true skip line
    bra	    test_continue		;val is not 0, button is still on, repeat loop 
    movff   TABLAT, msg, A	;stores keypad character in WR ready to be used
    call    KEY_Setup		;returns program to initial state
    return			;returns to main program
	

