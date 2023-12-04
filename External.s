#include <xc.inc>
    


psect	udata_acs   ; reserve data space in access ram


psect	uart_code,class=CODE

External_Setup:
    bcf	TRISF, 0
    return


