.DSEG
.ORG 0x00


;===GAME BOARD===
;Memory locations 0x00-0x3F
;represents the minesweeper board, each number is a box
;0: revealed, 1: has mine, 2: is flagged, 5,6,7: adjacent mines
;Ex: 0x40: a mine that has not been flagged or revealed
board: .DB 0x40, 0x01, 0x00, 0x01, 0x40, 0x01, 0x02, 0x40
	   .DB 0x02, 0x03, 0x02, 0x03, 0x02, 0x01, 0x02, 0x40
	   .DB 0x40, 0x02, 0x40, 0x40, 0x01, 0x00, 0x01, 0x01
	   .DB 0x01, 0x02, 0x02, 0x03, 0x02, 0x02, 0x01, 0x01
	   .DB 0x00, 0x00, 0x00, 0x01, 0x40, 0x02, 0x40, 0x01
	   .DB 0x00, 0x00, 0x01, 0x02, 0x02, 0x02, 0x01, 0x01
	   .DB 0x00, 0x00, 0x01, 0x40, 0x01, 0x00, 0x00, 0x00
	   .DB 0x00, 0x00, 0x01, 0x01, 0x01, 0x00, 0x00, 0x00


;===REGISTERS===
;R01: game won
;R02: game lost
;R03: unflagged mines
;R04: Draw address high
;R05: Draw address low
;R06: Draw color
;R07: Draw y coord
;R08: Draw x coord
;R09: Ending x, y coord
;R10: saved coordinate
;R13: background
;R15: cursor x
;R16: cursor y 
;R17: keyboard input
;R23: x coord
;R24: y coord
;R25: memtoxy address
;R26: loaded box
;R27: check_box temp
;R28: check_box adjacent
;R29: check_box revealed
;R30: check_box has mine
;R31: check_box is flagged


.CSEG
.ORG 0x88


.EQU VGA_HADD = 0x90
.EQU VGA_LADD = 0x91
.EQU VGA_COLOR = 0x92


init:		MOV R3, 0x0A
		CALL draw_init
		SEI


input:		IN  R17, 0x44
		BRN input


;MAIN=================================
;Main method called when the keyboard 
;sends an interrupt, handles user input
;and calls the various draw, reveal,
;and flag functions when necessary
;=====================================
.ORG 0x90

;checks the keypress and branches to 
;a different method based on the key
ISR:		CMP	R17, 0x1D
		BREQ move_up
		CMP R17, 0x1C
		BREQ move_left
		CMP R17, 0x1B
		BREQ move_down
		CMP R17, 0x23
		BREQ move_right
		CMP R17, 0x2D
		BREQ mov_reveal
		CMP R17, 0x2B
		BREQ move_flag
		RETIE

;checks to see if cursor is in
;bounds for a key press up
move_up:	CMP R16, 0x00
		BRNE move_up_cn
		RETIE

;moves the cursor up
move_up_cn:	SUB R16, 0x01
		CALL draw_cursr
		RETIE

;checks if the cursor is in
;bounds for a key press left
move_left:	CMP R15, 0x00
		BRNE move_lf_cn
		RETIE

;moves the cursor left
move_lf_cn: SUB R15, 0x01
		CALL draw_cursr
		RETIE

;checks if the cursor is in
;bounds for a key press down
move_down:	CMP R16, 0x07
		BRNE move_dn_cn
		RETIE

;moves the cursor down
move_dn_cn: ADD R16, 0x01
		CALL draw_cursr
		RETIE

;checks if the cursor is in 
;bounds for a key press right
move_right: 	CMP R15, 0x07
		BRNE move_rt_cn
		RETIE

;moves the cursor right
move_rt_cn: 	ADD R15, 0x01
		CALL draw_cursr
		RETIE

;reveals the box at cursor 
;location, if the box has
;a mine, sets the game lost
mov_reveal: 	MOV R23, R15
		MOV R24, R16
		CALL reveal_box
		CMP R2, 0x01
		BREQ game_lost
		CALL upd_board
		RETIE

;flags the box at cursor 
;location, if all mines
;are flagged, sets the game
;won
move_flag:	MOV R23, R15
		MOV R24, R16
		CALL flag_box
		CALL upd_board
		CMP R1, 0x01
		BREQ game_won
		RETIE

;game won state, draws a smile!
game_won:	CALL draw_smile
		BRN game_won

;game lost state, draws a frown :(
game_lost:	CALL draw_frown
		BRN game_lost
;END MAIN=============================


;REVEAL===============================
;Reveals a square that the cursor is on
;sets game lost if a mine is revealed, 
;recursively reveals boxs with zero
;adjacency
;=====================================

;loads box from mem and checks to see
;if box has already been revealed
reveal_box: 	CALL x_y_to_mem	
		LD  R26, (R25)
		CALL check_revl
		CMP R29, 0x80
		BRNE rv_box_flg
		RET 

;check to see if box is flagged, if so
;return from the reveal subroutine 
rv_box_flg: 	CALL check_flag
		CMP R31, 0x20
		BRNE rv_box_min
		RET

;checks to see if mine is revealed, if
;so set the game as lost
rv_box_min:	CALL check_mine
		CMP R30, 0x40
		BRNE rv_box_blk
		MOV R2, 0x01
		RET

;reveals box, checks adjacent, if zero
;recursively reveals adjacent mines
rv_box_blk: 	OR R26, 0x80
		ST  R26, (R25)
		CALL check_adjc
		CMP R28, 0x00
		BREQ rv_box_all
		RET


;RECURSIVE REVEAL======================
;reveals all adjacent boxes recursively,
;starting with the left most box
;this method utilizes the stack to save
;x and y values before entering a recursive
;subroutine, then popping them from the 
;stack when exiting the subroutine
;======================================

rv_box_all: 	CALL rv_bx_left
		CALL rev_box_up
		CALL rv_box_rit		
		CALL rv_box_bot	
		RET

rv_bx_left: 	CMP R23, 0x00
		BRNE rv_bx_lf_l
		RET

;reveal left most box
rv_bx_lf_l: 	PUSH R23
		PUSH R24
		SUB R23, 0x01
		CALL reveal_box
		POP R24
		POP R23
		CMP R24, 0x00
		BRNE rv_bx_lf_u
		RET

;reveal top left box
rv_bx_lf_u: 	PUSH R23
		PUSH R24
		SUB R23, 0x01
		SUB R24, 0x01
		CALL reveal_box
		POP R24
		POP R23
		RET

rev_box_up: 	CMP R24, 0x00
		BRNE rv_bx_up_u
		RET

;reveal top most box
rv_bx_up_u:	PUSH R23
		PUSH R24
		SUB R24, 0x01
		CALL reveal_box
		POP R24
		POP R23
		CMP R23, 0x07
		BRNE rv_bx_up_r
		RET

;reveal top right box
rv_bx_up_r: 	PUSH R23
		PUSH R24
		ADD R23, 0x01
		SUB R24, 0x01
		CALL reveal_box
		POP R24
		POP R23
		RET

rv_box_rit: 	CMP R23, 0x07
		BRNE rv_bx_rt_r
		RET

;reveal right most box
rv_bx_rt_r: 	PUSH R23
		PUSH R24
		ADD R23, 0x01
		CALL reveal_box 
		POP R24
		POP R23
		CMP R24, 0x07
		BRNE rv_bx_rt_b
		RET

;reveal bottom right box
rv_bx_rt_b: 	PUSH R23
		PUSH R24
		ADD R23, 0x01
		ADD R24, 0x01
		CALL reveal_box
		POP R24
		POP R23
		RET

rv_box_bot: 	CMP R24, 0x07
		BRNE rv_bx_bt_b
		RET

;reveal bottom most box
rv_bx_bt_b: 	PUSH R23
		PUSH R24
		ADD R24, 0x01
		CALL reveal_box
		POP R24
		POP R23
		CMP R23, 0x00
		BRNE rv_bx_bt_l
		RET

;reveal bottom left box
rv_bx_bt_l: 	PUSH R23
		PUSH R24
		SUB R23, 0x01
		ADD R24, 0x01
		CALL reveal_box
		POP R24
		POP R23
		RET
;END REVEAL===========================


;FLAG=================================
;flags selected box if box has not been
;revealed, if box is already flagged,
;removes flag, changes unflagged mines
;accordingly
;=====================================

;load box from mem, if box has not been
;revealed, flag or unflag
flag_box:	CALL x_y_to_mem
		LD R26, (R25)
		CALL check_revl
		CMP R29, 0x80
		BRNE flag_con
		RET

;check to see if box has flag, if so 
;remove flag, checks to see if box has
;mine, if so decrement unflagged mines
flag_con:	CALL check_flag
		CMP R31, 0x20
		BREQ remove_flg
		OR R26, 0x20
		CALL check_mine
		CMP R30, 0x40
		BREQ add_flag
		BRN flag_done

;if box has mine, decrement unflagged mines,
;checks to see if game is won
add_flag:	SUB R3, 0x01
		CMP R3, 0x00
		BRNE flag_done
		ADD R1, 0x01
		RET

;removes flag if square is already flagged,
;increases unflagged mine count if box had
;a mine
remove_flg:	AND R26, 0xDF
		CALL check_mine
		CMP R30, 0x40
		BRNE flag_done
		ADD R3, 0x01
		BRN flag_done

flag_done:	ST R26, (R25)
		RET
;END FLAG=============================


;DRAW=================================
;Draw methods, draws each box individually
;then the board as a whole, draws using
;the imported draw_dot method
;=====================================

;initializes the board, draws the background
;lines in between squares, and face
draw_init:	CALL draw_background
		CALL drw_hz_lns
		CALL drw_vt_lns
		CALL draw_face
		CALL draw_cursr
		RET

;updates the board, drawing each individual
;square as well as the cursor
upd_board:	MOV R8, 0x01
		MOV R7, 0x00
		MOV R25, 0x00
		BRN upd_brd_lp

;loops through the board, loading a box 
;from memory then drawing it		
upd_brd_lp: 	LD R26, (R25)
		CALL mem_to_x_y
		CALL draw_loc
		CALL check_flag
		CALL check_adjc
		CALL check_revl 
		CMP R29, 0x80
		BREQ upd_brd_rv
		CMP R31, 0x20
		BREQ upd_b_flag
		MOV R6, 0x92
		CALL clear_sqr
		BRN upd_brd_fn

;draws a square that is revealed, decides
;the value to be drawn based on its 
;adjacency
upd_brd_rv: 	CMP R28, 0x00
		BREQ upd_b_blnk
		CMP R28, 0x01
		BREQ upd_b_one
		CMP R28, 0x02
		BREQ upd_b_two
		CMP R28, 0x03
		BREQ upd_b_thre
		CMP R28, 0x04
		BREQ upd_b_four
		BRN upd_brd_fn

;clears a square with no adjacency			
upd_b_blnk: 	MOV R6, 0x73
		CALL clear_sqr
		BRN upd_brd_fn

;draws a "one"
upd_b_one: 	CALL draw_one
		BRN upd_brd_fn

;draws a "two"
upd_b_two:	CALL draw_two
		BRN upd_brd_fn

;draws a "three"
upd_b_thre:	CALL draw_three
		BRN upd_brd_fn

;draws a "four"
upd_b_four:	CALL draw_four
		BRN upd_brd_fn

;draws a "flag"
upd_b_flag:	CALL draw_flag
		BRN upd_brd_fn

;finalizes the loop and increments memory	
upd_brd_fn:	ADD R25, 0x01
		CMP R25, 0x40
		BRNE upd_brd_lp
		RET

;clears a given square on, drawing in a given
;color
clear_sqr: 	MOV R9, R8
		ADD R9, 0x02
		CALL draw_horizontal_line
		ADD R7, 0x01
		CALL draw_horizontal_line
		CMP R7, 0x1D
		BRNE fn_clr_sqr
		RET

;finishes clear square method
fn_clr_sqr: 	ADD R7, 0x01
		CALL draw_horizontal_line
		RET

;Draws the cursor, checks to see if cursor
;is in bounds of the board, redraws the 
;horizontal and vertical lines to clear
;the previous cursor
draw_cursr: 	CALL drw_hz_lns
		CALL drw_vt_lns
		MOV R23, R15
		MOV R24, R16
		CALL draw_loc
		MOV R6, 0xF4
		SUB R8, 0x01
		CALL draw_dot
		ADD R8, 0x04
		CALL draw_dot
		SUB R8, 0x03
		CMP R16, 0x00
		BRNE draw_c_top
		BRN con_drw_cr

con_drw_cr: 	CMP R16, 0x1C
		BRNE draw_c_bot
		RET

;draws the top part of the cursor
draw_c_top:	SUB R8, 0x01
		SUB R7, 0x01
		CALL draw_dot
		ADD R8, 0x01
		CALL draw_dot
		ADD R8, 0x02
		CALL draw_dot
		ADD R8, 0x01
		CALL draw_dot	
		SUB R8, 0x03
		ADD R7, 0x01
		BRN con_drw_cr

;draws the bottom part of the cursor
draw_c_bot: 	ADD R7, 0x02
		SUB R8, 0x01
		CALL draw_dot
		ADD R7, 0x01
		CALL draw_dot
		ADD R8, 0x01
		CALL draw_dot
		ADD R8, 0x02
		CALL draw_dot
		ADD R8, 0x01
		CALL draw_dot
		SUB R7 ,0x01
		CALL draw_dot
		RET

;draws the horizontal lines
;on the board
drw_hz_lns: 	MOV R6, 0x00
		MOV R7, 0x03
		MOV R9, 0x1F
		BRN con_drw_hz

con_drw_hz: 	MOV R8, 0x00
		CALL draw_horizontal_line
		CMP R7, 0x1B
		BREQ fn_draw_hz
		ADD R7, 0x04
		BRN con_drw_hz

fn_draw_hz: 	RET
	
;draws the vertical lines
;on the board
drw_vt_lns: 	MOV R6, 0x00
		MOV R8, 0x00
		MOV R9, 0x1D
		BRN con_drw_vt

con_drw_vt: 	MOV R7, 0x00
		CALL draw_vertical_line
		CMP R8, 0x20
		BREQ fn_draw_vt
		ADD R8, 0x04
		BRN con_drw_vt

fn_draw_vt: 	RET

;draws the default face on the side
;of the screen
draw_face:  	MOV R6, 0xF4
		MOV R7, 0x01
		MOV R8, 0x23
		CALL draw_dot
		ADD R7, 0x01	
		CALL draw_dot
		ADD R8, 0x02
		CALL draw_dot
		SUB R7, 0x01
		CALL draw_dot
		MOV R7, 0x05
		MOV R8, 0x22
		MOV R9, 0x26	
		CALL draw_horizontal_line
		MOV R8, 0x00
		MOV R7, 0x00
		RET

;draws a smile if game is won
draw_smile: 	MOV R6, 0xF4
		MOV R7, 0x04
		MOV R8, 0x22
		CALL draw_dot
		MOV R8, 0x26
		CALL draw_dot
		RET

;draws a frown if game is lost
draw_frown: 	MOV R6, 0xF4
		MOV R7, 0x06
		MOV R8, 0x22
		CALL draw_dot	
		MOV R8, 0x26
		CALL draw_dot
		RET

;draws the number one
draw_one:	MOV R6, 0x03
		CALL draw_dot
		ADD R8, 0x01
		CALL draw_dot
		ADD R7, 0x01
		CALL draw_dot
		CMP R7, 0x1D
		BRNE f_draw_one
		SUB R7, 0x01
		SUB R8, 0x01
		RET

;continues if in bounds
f_draw_one:	ADD R7, 0x01
		CALL draw_dot
		SUB R8, 0x01
		CALL draw_dot
		ADD R8, 0x02
		CALL draw_dot
		CALL reset_x_y
		RET

;draws the number two
draw_two: 	MOV R6, 0x14
		CALL draw_dot
		ADD R8, 0x01
		CALL draw_dot
		ADD R7, 0x01
		CALL draw_dot
		CMP R7, 0x1D
		BRNE f_draw_two
		SUB R7, 0x01
		SUB R8, 0x01
		RET

;continues if in bounds		
f_draw_two: 	ADD R7, 0x01
		CALL draw_dot
		ADD R8, 0x01
		CALL draw_dot
		CALL reset_x_y
		RET

;draws the number three		
draw_three:	MOV R6, 0x80
		CALL draw_dot
		ADD R8, 0x01
		CALL draw_dot
		ADD R8, 0x01
		CALL draw_dot
		ADD R7, 0x01
		CALL draw_dot
		SUB R8, 0x01
		CALL draw_dot
		CMP R7, 0x1D
		BRNE f_drw_thre
		SUB R7, 0x01
		SUB R8, 0x01
		RET

;continues if in bounds
f_drw_thre: 	ADD R7, 0x01
		CALL draw_dot
		SUB R8, 0x01
		CALL draw_dot
		ADD R8, 0x02
		CALL draw_dot
		CALL reset_x_y
		RET

;draws the number four
draw_four:	MOV R6, 0x82
		CALL draw_dot
		ADD R7, 0x01
		CALL draw_dot
		ADD R8, 0x01
		CALL draw_dot
		ADD R8, 0x01
		CALL draw_dot
		SUB R7, 0x01
		CALL draw_dot
		CMP R7, 0x1C
		BRNE f_drw_four
		SUB R8, 0x02
		RET

;continues if in bounds
f_drw_four: 	ADD R7, 0x02
		CALL draw_dot
		RET

;draws a flagged space
draw_flag: 	MOV R6, 0xE0
		CALL draw_dot
		ADD R7, 0x01
		CALL draw_dot
		ADD R8, 0x01
		CALL draw_dot
		SUB R7, 0x01
		CALL draw_dot
		MOV R6, 0xFF
		ADD R8, 0x01
		CALL draw_dot
		ADD R7, 0x01
		CALL draw_dot
		CMP R7, 0x1D
		BRNE f_drw_flag
		SUB R7, 0x01
		SUB R8, 0x02
		RET

;continues if in bounds
f_drw_flag:	ADD R7, 0x01
		CALL draw_dot
		RET	

;draws a horizontal line to a set
;address across the screen
draw_horizontal_line:
		MOV R10, R8
		BRN loop_horizontal_line

loop_horizontal_line:	
		CALL draw_dot
		CMP R8, R9
		BREQ reset_horizontal_line
		ADD R8, 0x01
		BRN loop_horizontal_line
		
reset_horizontal_line:
		MOV R8, R10
		RET

;draws a vertical line to a set
;address across the screen
draw_vertical_line:
		MOV R10, R7
		BRN loop_vertical_line

loop_vertical_line:          
        CALL draw_dot
		CMP	R7, R9
        BREQ reset_vertical_line
		ADD R7, 0x01
		BRN loop_vertical_line

reset_vertical_line:
		MOV R7, R10
		RET
;END DRAW=============================


;HELPER METHODS=======================
;finds the draw location based on
;the x and y coords of the board
draw_loc:	MOV R7, R24
			ROL R7
			ROL	R7
			MOV R8, R23
			ROL R8
			ROL R8
			ADD R8, 0x01
			RET
			
;resets the x and y draw coords
;within each square being drawn
reset_x_y:	SUB R7, 0x02
			SUB R8, 0x02
			RET

;checks if a loaded box has been
;revealed
check_revl: MOV R27, R26
			AND R27, 0x80
			MOV R29, R27
			RET

;checks if a loaded box has a 
;mine
check_mine: MOV R27, R26
			AND R27, 0x40
			MOV R30, R27
			RET 

;checks if a loaded box has been
;flagged
check_flag: MOV R27, R26
			AND R27, 0x20
			MOV R31, R27 
			RET

check_adjc: MOV R27, R26
			AND R27, 0x07
			MOV R28, R27 
			RET

;converts a memory location
;to x and y coords
mem_to_x_y: MOV R23, R25
			AND R23, 0x07
			MOV R24, R25
			AND R24, 0x38
			ROR R24
			ROR R24
			ROR R24
			RET 

;converts x and y coords to 
;a memory location
x_y_to_mem: MOV R25, R24
			ROL R25
			ROL R25
			ROL R25
			ADD R25, R23
			RET


;IMPORTED METHODS-----------------------------------------------------
;- Subrountine: draw_dot
;- 
;- This subroutine draws a dot on the display the given coordinates: 
;- 
;- (X,Y) = (r8,r7)  with a color stored in r6  
;- 
;- Tweaked registers: r4,r5
;---------------------------------------------------------------------
draw_dot: 
           MOV   r4,r7         ; copy Y coordinate
           MOV   r5,r8         ; copy X coordinate

           AND   r5,0x3F       ; make sure top 2 bits cleared
           AND   r4,0x1F       ; make sure top 3 bits cleared
           LSR   r4             ; need to get the bot 2 bits of r4 into sA
           BRCS  dd_add40
t1:        LSR   r4
           BRCS  dd_add80

dd_out:    OUT   r5,VGA_LADD   ; write bot 8 address bits to register
           OUT   r4,VGA_HADD   ; write top 3 address bits to register
           OUT   r6,VGA_COLOR  ; write data to frame buffer
           RET

dd_add40:  OR    r5,0x40       ; set bit if needed
           CLC                  ; freshen bit
           BRN   t1             

dd_add80:  OR    r5,0x80       ; set bit if needed
           BRN   dd_out

;draws the background of the screen gray
;using the draw_horizontal lines function
draw_background: 
         MOV   r6, 0x92		            ; use default color
         MOV   r13,0x00                 ; r13 keeps track of rows
start:   MOV   r7,r13                   ; load current row count 
         MOV   r8,0x00                  ; restart x coordinates
         MOV   r9,0x27 
 
         CALL  draw_horizontal_line
         ADD   r13,0x01                 ; increment row count
         CMP   r13,0x1D                 ; see if more rows to draw
         BRNE  start                    ; branch to draw more rows
         RET

;END HELPER METHODS===================


;===INTERUPT===
.ORG 0x3FF

interupt:	BRN ISR
