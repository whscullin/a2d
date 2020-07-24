;;; ============================================================
;;; Hello World - Desk Accessory
;;;
;;; Minimal desk accessory.
;;; ============================================================

        .setcpu "6502"

        .include "apple2.inc"
        .include "../inc/apple2.inc"
        .include "../inc/macros.inc"
        .include "../mgtk/mgtk.inc"
        .include "../common.inc"
        .include "../desktop/desktop.inc"
        .include "../inc/fp_macros.inc"

;;; ============================================================

        .org DA_LOAD_ADDRESS

da_start:

;;; Copy the DA to AUX for easy bank switching
.scope
        copy16  #da_start, STARTLO
        copy16  #da_end, ENDLO
        copy16  #da_start, DESTINATIONLO
        sec                     ; main>aux
        jsr     AUXMOVE
.endscope

.scope
        ;; Run the DA
        sta     RAMRDON
        sta     RAMWRTON
        jsr     init

        ;; Back to main for exit
        sta     RAMRDOFF
        sta     RAMWRTOFF
        rts
.endscope

;;; ============================================================

kDAWindowId     = 60
kDAWidth        = 256
kDAHeight       = 32
kDALeft         = (kScreenWidth - kDAWidth)/2
kDATop          = (kScreenHeight - kMenuBarHeight - kDAHeight)/2 + kMenuBarHeight

title_pos:
        DEFINE_POINT (kDAWidth - 60)/ 2, 18
title_label:
        PASCAL_STRING "Hello World"

.params winfo
window_id:      .byte   kDAWindowId
options:        .byte   MGTK::Option::go_away_box
title:          .addr   title_label
hscroll:        .byte   MGTK::Scroll::option_none
vscroll:        .byte   MGTK::Scroll::option_none
hthumbmax:      .byte   32
hthumbpos:      .byte   0
vthumbmax:      .byte   32
vthumbpos:      .byte   0
status:         .byte   0
reserved:       .byte   0
mincontwidth:   .word   kScreenWidth / 5
mincontlength:  .word   kScreenHeight / 5
maxcontwidth:   .word   kScreenWidth
maxcontlength:  .word   kScreenHeight
port:
viewloc:        DEFINE_POINT kDALeft, kDATop
mapbits:        .addr   MGTK::screen_mapbits
mapwidth:       .byte   MGTK::screen_mapwidth
reserved2:      .byte   0
maprect:        DEFINE_RECT 0, 0, kDAWidth, kDAHeight, maprect
pattern:        .res    8, $FF
colormasks:     .byte   MGTK::colormask_and, MGTK::colormask_or
penloc:          DEFINE_POINT 0, 0
penwidth:       .byte   1
penheight:      .byte   1
penmode:        .byte   0
textback:       .byte   $7F
textfont:       .addr   DEFAULT_FONT
nextwinfo:      .addr   0
.endparams

;;; ============================================================

event_params := *
event_kind := event_params + 0
        ;; if kind is key_down
event_key := event_params + 1
event_modifiers := event_params + 2
        ;; if kind is no_event, button_down/up, drag, or apple_key:
event_coords := event_params + 1
event_xcoord := event_params + 1
event_ycoord := event_params + 3
        ;; if kind is update:
event_window_id := event_params + 1

screentowindow_params := *
screentowindow_window_id := screentowindow_params + 0
screentowindow_screenx := screentowindow_params + 1
screentowindow_screeny := screentowindow_params + 3
screentowindow_windowx := screentowindow_params + 5
screentowindow_windowy := screentowindow_params + 7
        .assert screentowindow_screenx = event_xcoord, error, "param mismatch"
        .assert screentowindow_screeny = event_ycoord, error, "param mismatch"

findwindow_params := * + 1    ; offset to x/y overlap event_params x/y
findwindow_mousex := findwindow_params + 0
findwindow_mousey := findwindow_params + 2
findwindow_which_area := findwindow_params + 4
findwindow_window_id := findwindow_params + 5
        .assert findwindow_mousex = event_xcoord, error, "param mismatch"
        .assert findwindow_mousey = event_ycoord, error, "param mismatch"

;;; Union of above params
        .res    10, 0

;;; ============================================================

.params closewindow_params
window_id:     .byte   kDAWindowId
.endparams

.params getwinport_params
window_id:      .byte   0
a_grafport:     .addr   grafport
.endparams

grafport:       .tag MGTK::GrafPort

;;; ============================================================

pencopy:        .byte   0
penOR:          .byte   1
penXOR:         .byte   2
penBIC:         .byte   3
notpencopy:     .byte   4
notpenOR:       .byte   5
notpenXOR:      .byte   6
notpenBIC:      .byte   7

;;; ============================================================
;;; Initialize window, unpack the date.

.proc init
        MGTK_CALL MGTK::OpenWindow, winfo

        MGTK_CALL MGTK::SetPort, winfo::port
        MGTK_CALL MGTK::SetPenMode, penXOR

        MGTK_CALL MGTK::MoveTo, title_pos
        addr_call DrawString, title_label

        MGTK_CALL MGTK::FlushEvents
        ;; fall through
.endproc

;;; ============================================================
;;; Input loop

.proc input_loop
        MGTK_CALL MGTK::GetEvent, event_params
        lda     event_kind
        cmp     #MGTK::EventKind::button_down
        bne     :+
        jmp     on_click

:       cmp     #MGTK::EventKind::key_down
        bne     input_loop
.endproc

.proc on_key
        lda     event_modifiers
        bne     input_loop
        lda     event_key

        cmp     #CHAR_ESCAPE
        beq     on_key_esc

        jmp     input_loop
.endproc

.proc on_key_esc
        lda     winfo::window_id
        jsr     get_window_port

        jmp     close_window
.endproc

.proc on_click
        MGTK_CALL MGTK::FindWindow, findwindow_params

        lda     findwindow_window_id
        cmp     #kDAWindowId
        bne     miss

        jmp     close_window

miss:   jmp     input_loop
.endproc

;;; ============================================================

.proc get_window_port
        sta     getwinport_params::window_id
        MGTK_CALL MGTK::GetWinPort, getwinport_params
        MGTK_CALL MGTK::SetPort, grafport
        rts
.endproc

;;; ============================================================

.proc close_window
        MGTK_CALL MGTK::CloseWindow, closewindow_params
        rts
.endproc

;;; ============================================================
;;; Draw Pascal String
;;; Input: A,X = string address

.proc DrawString
        ptr := $06
        params := $06

        stax    ptr
        ldy     #0
        lda     (ptr),y
        sta     $08
        inc16   ptr
        MGTK_CALL MGTK::DrawText, params
        rts
.endproc

;;; ============================================================

da_end := *
.assert * < $1B00, error, "DA too big"
        ;; I/O Buffer starts at MAIN $1C00
        ;; ... but icon tables start at AUX $1B00
