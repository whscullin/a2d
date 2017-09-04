        .setcpu "65C02"
        .org $800

        .include "../inc/prodos.inc"
        .include "../inc/auxmem.inc"
        .include "a2d.inc"

        ;; Big questions:
        ;; * How can we hide/show the cursor on demand?
        ;; * Can we trigger menu redraw? (if not, need to preserve for fullscreen)

start:  jmp     copy2aux

save_stack:.byte   0

;;; Copy $800 through $13FF (the DA) to aux
.proc copy2aux
        tsx
        stx     save_stack
        sta     RAMWRTON
        ldy     #0
src:    lda     start,y         ; self-modified
dst:    sta     start,y         ; self-modified
        dey
        bne     src
        sta     RAMWRTOFF
        inc     src+2
        inc     dst+2
        sta     RAMWRTON
        lda     dst+2
        cmp     #$14
        bne     src
.endproc

call_main_trampoline   := $20 ; installed on ZP, turns off auxmem and calls...
call_main_addr         := call_main_trampoline+7        ; address patched in here

;;; Copy the following "call_main_template" routine to $20
.scope
        sta     RAMWRTON
        sta     RAMRDON
        ldx     #(call_main_template_end - call_main_template)
loop:   lda     call_main_template,x
        sta     call_main_trampoline,x
        dex
        bpl     loop
        jmp     call_init
.endscope

.proc call_main_template
        sta     RAMRDOFF
        sta     RAMWRTOFF
        jsr     $1000           ; overwritten (in zp version)
        sta     RAMRDON
        sta     RAMWRTON
        rts
.endproc
call_main_template_end:         ; can't .sizeof(proc) before declaration
        ;; https://github.com/cc65/cc65/issues/478

.proc call_init
        ;; run the DA
        jsr     init

        ;; tear down/exit
        sta     ALTZPON
        lda     LCBANK1
        lda     LCBANK1
        sta     RAMRDOFF
        sta     RAMWRTOFF
        ldx     save_stack
        txs
        rts
.endproc

;;; ==================================================
;;; ProDOS MLI calls

.proc open_file
        jsr     copy_params_aux_to_main
        sta     ALTZPOFF
        MLI_CALL OPEN, open_params
        sta     ALTZPON
        jsr     copy_params_main_to_aux
        rts
.endproc


.proc read_file
        jsr     copy_params_aux_to_main
        sta     ALTZPOFF
        MLI_CALL READ, read_params
        sta     ALTZPON
        jsr     copy_params_main_to_aux
        rts
.endproc


.proc close_file
        jsr     copy_params_aux_to_main
        sta     ALTZPOFF
        MLI_CALL CLOSE, close_params
        sta     ALTZPON
        jsr     copy_params_main_to_aux
        rts
.endproc

;;; ==================================================

;;; Copies param blocks from Aux to Main
.proc copy_params_aux_to_main
        ldy     #(params_end - params_start + 1)
        sta     RAMWRTOFF
loop:   lda     params_start - 1,y
        sta     params_start - 1,y
        dey
        bne     loop
        sta     RAMRDOFF
        rts
.endproc

;;; Copies param blocks from Main to Aux
.proc copy_params_main_to_aux
        pha
        php
        sta     RAMWRTON
        ldy     #(params_end - params_start + 1)
loop:   lda     params_start - 1,y
        sta     params_start - 1,y
        dey
        bne     loop
        sta     RAMRDON
        plp
        pla
        rts
.endproc

;;; ----------------------------------------

params_start:
;;; This block gets copied between main/aux

;;; ProDOS MLI param blocks

.proc open_params
        .byte   3               ; param_count
        .addr   pathname        ; pathname
        .addr   $0C00           ; io_buffer
ref_num:.byte   0               ; ref_num
.endproc

        hires   := $2000
        hires_size := $2000

.proc read_params
        .byte   4               ; param_count
ref_num:.byte   0               ; ref_num
buffer: .addr   hires           ; data_buffer
request:.word   hires_size      ; request_count
        .word   0               ; trans_count
.endproc

.proc close_params
        .byte   1               ; param_count
ref_num:.byte   0               ; ref_num
.endproc

.proc pathname                 ; 1st byte is length, rest is full path
length: .byte   $00
data:   .byte   $00,$00,$00,$00,$00,$00,$00,$00
        .byte   $00,$00,$00,$00,$00,$00,$00,$00
        .byte   $00,$00,$00,$00,$00,$00,$00,$00
        .byte   $00,$00,$00,$00,$00,$00,$00,$00
        .byte   $00,$00,$00,$00,$00,$00,$00,$00
        .byte   $00,$00,$00,$00,$00,$00,$00,$00
        .byte   $00,$00,$00,$00,$00,$00,$00,$00
        .byte   $00,$00,$00,$00,$00,$00,$00,$00
.endproc


params_end:
;;; ----------------------------------------

        window_id := $64

.proc line_pos
left:   .word   0
base:   .word   0
.endproc


.proc button_params             ; queried to track mouse-up
state:  .byte   $00
.endproc

        default_width := 560
        default_height := 192
        default_left := 0
        default_top := 0

.proc window_title
        .byte 0                 ; length
.endproc

.proc window_params
id:     .byte   window_id       ; window identifier
flags:  .byte   A2D_CWF_NOTITLE
title:  .addr   window_title

hscroll:.byte   A2D_CWS_NOSCROLL
vscroll:.byte   A2D_CWS_NOSCROLL
hscroll_max:
        .byte   32
hscroll_pos:
        .byte   0
vscroll_max:
        .byte   32
vscroll_pos:
        .byte   0

        ;; ???
        .byte   $00,$00,$C8,$00,$33,$00

width:  .word   default_width
height: .word   default_height

.proc text_box
left:   .word   default_left
top:    .word   default_top
        .word   $2000           ; ??? never changed
        .word   $80             ; ??? never changed
hoffset:.word   0               ; Also used for A2D_CLEAR_BOX
voffset:.word   0
width:  .word   default_width
height: .word   default_height
.endproc
.endproc

        ;; unused?
        .byte   $00,$00,$00,$00,$00,$00,$00
        .byte   $00,$FF,$00,$00,$00,$00,$00,$01
        .byte   $01,$00,$7F,$00,$88,$00,$00


.proc init
        sta     ALTZPON
        lda     LCBANK1
        lda     LCBANK1

        ;; Get filename by checking DeskTop selected window/icon

        ;; Check that an icon is selected
        lda     #0
        sta     pathname::length
        lda     file_selected
        beq     abort           ; some file properties?
        lda     path_index      ; prefix index in table
        bne     :+
abort:  rts

        ;; Copy path (prefix) into pathname buffer.
:       src := $06
        dst := $08

        asl     a               ; (since address table is 2 bytes wide)
        tax
        lda     path_table,x          ; pathname ???
        sta     src
        lda     path_table+1,x
        sta     src+1
        ldy     #0
        lda     (src),y
        tax
        inc     src
        bne     :+
        inc     src+1
:       lda     #<(pathname::data)
        sta     dst
        lda     #>(pathname::data)
        sta     dst+1
        jsr     copy_pathname   ; copy x bytes (src) to (dst)

        ;; Append separator.
        lda     #'/'
        ldy     #0
        sta     (dst),y
        inc     pathname::length
        inc     dst
        bne     :+
        inc     dst+1

        ;; Get file entry.
:       lda     file_index      ; file index in table
        asl     a               ; (since table is 2 bytes wide)
        tax
        lda     file_table,x
        sta     src
        lda     file_table+1,x
        sta     src+1

        ;; Exit if a directory.
        ldy     #2              ; 2nd byte of entry
        lda     (src),y
        and     #$70            ; check that one of bits 4,5,6 is set ???
        ;; some vague patterns, but unclear
        ;; basic = $32,$33, text = $52, sys = $11,$14,??, bin = $23,$24,$33
        ;; dir = $01 (so not shown)
        bne     :+
        rts                     ; abort ???

        ;; Append filename to path.
:       ldy     #9
        lda     (src),y         ; grab length
        tax                     ; name has spaces before/after
        dex                     ; so subtract 2 to get actual length
        dex
        clc
        lda     src
        adc     #11             ; 9 = length, 10 = space, 11 = name
        sta     src
        bcc     :+
        inc     src+1
:       jsr     copy_pathname   ; copy x bytes (src) to (dst)

        jmp     open_file_and_init_window

.proc copy_pathname             ; copy x bytes from src to dst
        ldy     #0              ; incrementing path length and dst
loop:   lda     (src),y
        sta     (dst),y
        iny
        inc     pathname::length
        dex
        bne     loop
        tya
        clc
        adc     dst
        sta     dst
        bcc     end
        inc     dst+1
end:    rts
.endproc

.endproc

.proc open_file_and_init_window
        jsr     open_file
        lda     open_params::ref_num
        sta     read_params::ref_num
        sta     close_params::ref_num

        jsr     stash_menu

        ;; create window
        A2D_CALL A2D_CREATE_WINDOW, window_params
        A2D_CALL A2D_TEXT_BOX1, window_params::text_box

        jsr     show_file

        A2D_CALL $2B, 0         ; ???
        ;; fall through
.endproc

;;; ==================================================
;;; Main Input Loop

.proc input_loop
        A2D_CALL A2D_GET_BUTTON, button_params
        lda     button_params::state
        cmp     #1              ; was clicked?
        bne     input_loop      ; nope, keep waiting

        A2D_CALL A2D_DESTROY_WINDOW, window_params

        jsr     unstash_menu

        jsr     UNKNOWN_CALL    ; ???
        .byte   $0C
        .addr   0

        rts                     ; exits input loop
.endproc

.proc show_file
        sta     PAGE2OFF
        jsr     read_file
        jsr     close_file

        jsr     hgr_to_dhr
        rts
.endproc


.proc hgr_to_dhr
        ptr     := $06
        rows    := 192
        cols    := 40
        spill   := $08          ; spill-over

        lda     #0              ; row
rloop:  pha
        tax
        lda     hires_table_lo,x
        sta     ptr
        lda     hires_table_hi,x
        sta     ptr+1

        ldy     #0              ; col
        sty     spill           ; spill-over
cloop:  lda     (ptr),y         ; between pairs
        tax
        lda     hgr_to_dhr_aux,x
        ora     spill
        sta     PAGE2ON
        sta     (ptr),y
        lda     hgr_to_dhr_main,x
        sta     PAGE2OFF
        sta     (ptr),y

        rol     a               ; shift high bit
        lda     #0              ; to low bit
        rol     a
        sta     spill           ; and save

        iny
        cpy     #cols
        bne     cloop

        pla
        inc
        cmp     #rows
        bne     rloop

        ;; TODO: Restore PAGE2 state?
done:   sta     PAGE2OFF
        rts
.endproc


        stash := $1200          ; Past DA code
        rows = 13
        cols = 40

.proc stash_menu
        src := $08
        dst := $06
        lda     #<stash
        sta     dst
        lda     #>stash
        sta     dst+1

        sta     PAGE2ON
        jsr     inner
        sta     PAGE2OFF

inner:

        lda     #0              ; row #
rloop:  pha
        tax
        lda     hires_table_lo,x
        sta     src
        lda     hires_table_hi,x
        sta     src+1
        ldy     #cols-1
cloop:  lda     (src),y
        sta     (dst),y
        dey
        bpl     cloop

        clc                     ; src += cols
        lda     src
        adc     #<cols
        sta     src
        lda     src+1
        adc     #>cols
        sta     src+1

        clc                     ; dst += cols
        lda     dst
        adc     #<cols
        sta     dst
        lda     dst+1
        adc     #>cols
        sta     dst+1

        pla
        inc
        cmp     #rows
        bcc     rloop
        rts
.endproc

.proc unstash_menu
        src := $08
        dst := $06
        lda     #<stash
        sta     src
        lda     #>stash
        sta     src+1

        sta     PAGE2ON
        jsr     inner
        sta     PAGE2OFF

inner:

        lda     #0              ; row #
rloop:  pha
        tax
        lda     hires_table_lo,x
        sta     dst
        lda     hires_table_hi,x
        sta     dst+1
        ldy     #cols-1
cloop:  lda     (src),y
        sta     (dst),y
        dey
        bpl     cloop

        clc                     ; src += cols
        lda     src
        adc     #<cols
        sta     src
        lda     src+1
        adc     #>cols
        sta     src+1

        clc                     ; dst += cols
        lda     dst
        adc     #<cols
        sta     dst
        lda     dst+1
        adc     #>cols
        sta     dst+1

        pla
        inc
        cmp     #rows
        bcc     rloop
        rts
.endproc



hires_table_lo:
	.byte	$00,$00,$00,$00,$00,$00,$00,$00
	.byte	$80,$80,$80,$80,$80,$80,$80,$80
	.byte	$00,$00,$00,$00,$00,$00,$00,$00
	.byte	$80,$80,$80,$80,$80,$80,$80,$80
	.byte	$00,$00,$00,$00,$00,$00,$00,$00
	.byte	$80,$80,$80,$80,$80,$80,$80,$80
	.byte	$00,$00,$00,$00,$00,$00,$00,$00
	.byte	$80,$80,$80,$80,$80,$80,$80,$80
	.byte	$28,$28,$28,$28,$28,$28,$28,$28
	.byte	$a8,$a8,$a8,$a8,$a8,$a8,$a8,$a8
	.byte	$28,$28,$28,$28,$28,$28,$28,$28
	.byte	$a8,$a8,$a8,$a8,$a8,$a8,$a8,$a8
	.byte	$28,$28,$28,$28,$28,$28,$28,$28
	.byte	$a8,$a8,$a8,$a8,$a8,$a8,$a8,$a8
	.byte	$28,$28,$28,$28,$28,$28,$28,$28
	.byte	$a8,$a8,$a8,$a8,$a8,$a8,$a8,$a8
	.byte	$50,$50,$50,$50,$50,$50,$50,$50
	.byte	$d0,$d0,$d0,$d0,$d0,$d0,$d0,$d0
	.byte	$50,$50,$50,$50,$50,$50,$50,$50
	.byte	$d0,$d0,$d0,$d0,$d0,$d0,$d0,$d0
	.byte	$50,$50,$50,$50,$50,$50,$50,$50
	.byte	$d0,$d0,$d0,$d0,$d0,$d0,$d0,$d0
	.byte	$50,$50,$50,$50,$50,$50,$50,$50
	.byte	$d0,$d0,$d0,$d0,$d0,$d0,$d0,$d0

hires_table_hi:
	.byte	$20,$24,$28,$2c,$30,$34,$38,$3c
	.byte	$20,$24,$28,$2c,$30,$34,$38,$3c
	.byte	$21,$25,$29,$2d,$31,$35,$39,$3d
	.byte	$21,$25,$29,$2d,$31,$35,$39,$3d
	.byte	$22,$26,$2a,$2e,$32,$36,$3a,$3e
	.byte	$22,$26,$2a,$2e,$32,$36,$3a,$3e
	.byte	$23,$27,$2b,$2f,$33,$37,$3b,$3f
	.byte	$23,$27,$2b,$2f,$33,$37,$3b,$3f
	.byte	$20,$24,$28,$2c,$30,$34,$38,$3c
	.byte	$20,$24,$28,$2c,$30,$34,$38,$3c
	.byte	$21,$25,$29,$2d,$31,$35,$39,$3d
	.byte	$21,$25,$29,$2d,$31,$35,$39,$3d
	.byte	$22,$26,$2a,$2e,$32,$36,$3a,$3e
	.byte	$22,$26,$2a,$2e,$32,$36,$3a,$3e
	.byte	$23,$27,$2b,$2f,$33,$37,$3b,$3f
	.byte	$23,$27,$2b,$2f,$33,$37,$3b,$3f
	.byte	$20,$24,$28,$2c,$30,$34,$38,$3c
	.byte	$20,$24,$28,$2c,$30,$34,$38,$3c
	.byte	$21,$25,$29,$2d,$31,$35,$39,$3d
	.byte	$21,$25,$29,$2d,$31,$35,$39,$3d
	.byte	$22,$26,$2a,$2e,$32,$36,$3a,$3e
	.byte	$22,$26,$2a,$2e,$32,$36,$3a,$3e
	.byte	$23,$27,$2b,$2f,$33,$37,$3b,$3f
	.byte	$23,$27,$2b,$2f,$33,$37,$3b,$3f

;;; HGR to DHR - Aux Mem Bytes
hgr_to_dhr_aux:
        .byte   $00, $03, $0c, $0f, $30, $33, $3c, $3f
        .byte   $40, $43, $4c, $4f, $70, $73, $7c, $7f
        .byte   $00, $03, $0c, $0f, $30, $33, $3c, $3f
        .byte   $40, $43, $4c, $4f, $70, $73, $7c, $7f
        .byte   $00, $03, $0c, $0f, $30, $33, $3c, $3f
        .byte   $40, $43, $4c, $4f, $70, $73, $7c, $7f
        .byte   $00, $03, $0c, $0f, $30, $33, $3c, $3f
        .byte   $40, $43, $4c, $4f, $70, $73, $7c, $7f
        .byte   $00, $03, $0c, $0f, $30, $33, $3c, $3f
        .byte   $40, $43, $4c, $4f, $70, $73, $7c, $7f
        .byte   $00, $03, $0c, $0f, $30, $33, $3c, $3f
        .byte   $40, $43, $4c, $4f, $70, $73, $7c, $7f
        .byte   $00, $03, $0c, $0f, $30, $33, $3c, $3f
        .byte   $40, $43, $4c, $4f, $70, $73, $7c, $7f
        .byte   $00, $03, $0c, $0f, $30, $33, $3c, $3f
        .byte   $40, $43, $4c, $4f, $70, $73, $7c, $7f
        .byte   $00, $06, $18, $1e, $60, $66, $78, $7e
        .byte   $00, $06, $18, $1e, $60, $66, $78, $7e
        .byte   $00, $06, $18, $1e, $60, $66, $78, $7e
        .byte   $00, $06, $18, $1e, $60, $66, $78, $7e
        .byte   $00, $06, $18, $1e, $60, $66, $78, $7e
        .byte   $00, $06, $18, $1e, $60, $66, $78, $7e
        .byte   $00, $06, $18, $1e, $60, $66, $78, $7e
        .byte   $00, $06, $18, $1e, $60, $66, $78, $7e
        .byte   $00, $06, $18, $1e, $60, $66, $78, $7e
        .byte   $00, $06, $18, $1e, $60, $66, $78, $7e
        .byte   $00, $06, $18, $1e, $60, $66, $78, $7e
        .byte   $00, $06, $18, $1e, $60, $66, $78, $7e
        .byte   $00, $06, $18, $1e, $60, $66, $78, $7e
        .byte   $00, $06, $18, $1e, $60, $66, $78, $7e
        .byte   $00, $06, $18, $1e, $60, $66, $78, $7e
        .byte   $00, $06, $18, $1e, $60, $66, $78, $7e

;;; HGR to DHR - Main Mem Bytes
hgr_to_dhr_main:
        .byte   $00, $00, $00, $00, $00, $00, $00, $00
        .byte   $01, $01, $01, $01, $01, $01, $01, $01
        .byte   $06, $06, $06, $06, $06, $06, $06, $06
        .byte   $07, $07, $07, $07, $07, $07, $07, $07
        .byte   $18, $18, $18, $18, $18, $18, $18, $18
        .byte   $19, $19, $19, $19, $19, $19, $19, $19
        .byte   $1e, $1e, $1e, $1e, $1e, $1e, $1e, $1e
        .byte   $1f, $1f, $1f, $1f, $1f, $1f, $1f, $1f
        .byte   $60, $60, $60, $60, $60, $60, $60, $60
        .byte   $61, $61, $61, $61, $61, $61, $61, $61
        .byte   $66, $66, $66, $66, $66, $66, $66, $66
        .byte   $67, $67, $67, $67, $67, $67, $67, $67
        .byte   $78, $78, $78, $78, $78, $78, $78, $78
        .byte   $79, $79, $79, $79, $79, $79, $79, $79
        .byte   $7e, $7e, $7e, $7e, $7e, $7e, $7e, $7e
        .byte   $7f, $7f, $7f, $7f, $7f, $7f, $7f, $7f
        .byte   $00, $00, $00, $00, $00, $00, $00, $00
        .byte   $03, $03, $03, $03, $03, $03, $03, $03
        .byte   $0c, $0c, $0c, $0c, $0c, $0c, $0c, $0c
        .byte   $0f, $0f, $0f, $0f, $0f, $0f, $0f, $0f
        .byte   $30, $30, $30, $30, $30, $30, $30, $30
        .byte   $33, $33, $33, $33, $33, $33, $33, $33
        .byte   $3c, $3c, $3c, $3c, $3c, $3c, $3c, $3c
        .byte   $3f, $3f, $3f, $3f, $3f, $3f, $3f, $3f
        .byte   $c0, $c0, $c0, $c0, $c0, $c0, $c0, $c0
        .byte   $c3, $c3, $c3, $c3, $c3, $c3, $c3, $c3
        .byte   $cc, $cc, $cc, $cc, $cc, $cc, $cc, $cc
        .byte   $cf, $cf, $cf, $cf, $cf, $cf, $cf, $cf
        .byte   $f0, $f0, $f0, $f0, $f0, $f0, $f0, $f0
        .byte   $f3, $f3, $f3, $f3, $f3, $f3, $f3, $f3
        .byte   $fc, $fc, $fc, $fc, $fc, $fc, $fc, $fc
        .byte   $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
