        icl 'equates.asm'
        icl 'routines.asm'

        org $2000

 .proc main

        jsr openGR8
        jsr initPMG

        ; load the STARTING frame (duckShape1) into PM memory —
        ; point spritePtr at it and let loadDuckFrame do the copy
        lda #<duckShape1
        sta spritePtr_lo
        lda #>duckShape1
        sta spritePtr_hi
        jsr loadDuckFrame

        ; set the duck's STARTING position only — waitFrames will
        ; keep re-asserting HPOSP0 continuously from here on
        mva #90 shipX

keepDucking:
        lda shipX               ; a = shipX
        sta HPOSP0              ; push shipX to Player 0's horizontal position

        ; --- pick this step's walk-cycle frame ---
        ; even shipX -> duckShape1, odd shipX -> duckShape2

        lda STICK0
        and #%00000100      ; isolate bit 2 (Left)
        beq isLeft
        jmp checkRight
isLeft:
        dec shipX

checkRight:
        lda STICK0
        and #%00001000      ; isolate bit 3 (Right)
        beq isRight
        jmp doneReading
isRight:
        inc shipX

doneReading:

        lda shipX
        and #%00000001           ; isolate bit 0 (the "is it odd" bit)
        beq useFrame1

        lda #<duckShape2
        sta spritePtr_lo
        lda #>duckShape2
        sta spritePtr_hi
        jmp doLoad

useFrame1:
        lda #<duckShape1
        sta spritePtr_lo
        lda #>duckShape1
        sta spritePtr_hi

doLoad:
        jsr loadDuckFrame        ; copy whichever table we just pointed at

        lda #$1E                 ; TODO: this should be a variable in equates
        sta COLPM0                ; color for Player 0

        ldx #5                  ; frames to hold before the next step
        jsr waitFrames           ; holds here, refreshing HPOSP0/COLPM0
                                 ; every frame internally
        jmp keepDucking


stop:
        jsr fightAttract
        lda shipX
        sta HPOSP0               ; stop loop also needs to refresh,
        lda #$1E                ; since it's another long-running
        sta COLPM0               ; loop with the same characteristics
        jmp stop

        .endp


;=========================================================================
; loadDuckFrame
; Copies a 16-byte duck walk-cycle frame into Player 0's visible PM
; memory (PMBASE + $0200 + 16, combined here at assemble time since
; none of those three values change at runtime).
; ON ENTRY: spritePtr_lo/spritePtr_hi point at a 16-byte frame table
;           (duckShape1 or duckShape2)
; ON EXIT:  spritePtr_lo/spritePtr_hi have been walked forward by 16 —
;           reload them before calling again
;=========================================================================
        .proc loadDuckFrame

        lda #<(PMBASE+$210)
        sta scrptr_lo
        lda #>(PMBASE+$210)
        sta scrptr_hi

        ldx #0
frameLoop:
        ldy #0
        lda (spritePtr_lo),y
        sta (scrptr_lo),y

        inc spritePtr_lo
        bne spNoCarry
        inc spritePtr_hi
spNoCarry:
        inc scrptr_lo
        bne scNoCarry
        inc scrptr_hi
scNoCarry:
        inx
        cpx #16                  ; both frames MUST be 16 bytes for this
        bne frameLoop            ; fixed count to be safe

        rts
        .endp


; Data section
;===================================================================

        ; Bit order: bit 7 (leftmost) = screen-left, bit 0 (rightmost) =
        ; screen-right, same convention as beowulfShape. Row count is
        ; free — .len duckShape in the load loop above picks up
        ; whatever you put here, add/remove rows as you like.
        .local duckShape1
        .byte %00111100     ; row 0  - crown of head
        .byte %01110100     ; row 1  - head
        .byte %01111111     ; row 2  - head, eye level
        .byte %01111110     ; row 3  - beak
        .byte %01111101     ; row 4  - chin, head narrows
        .byte %00111000     ; row 5  - neck
        .byte %00111000     ; row 6  - neck/body transition
        .byte %00111000     ; row 7  - body widening
        .byte %00111000     ; row 8  - body, max width
        .byte %11111111     ; row 9  - body, max width
        .byte %11111111     ; row 10 - body
        .byte %01111110     ; row 11 - body narrowing
        .byte %00111100     ; row 12 - tail / body bottom
        .byte %00100100     ; row 13 - legs
        .byte %01100100     ; row 14 - legs
        .byte %00000110     ; row 15 - webbed feet
        .endl

        ; identical clone of duckShape — edit this one's legs/wing rows
        ; to create the second walk-cycle pose (frame length can differ
        ; from duckShape's if you use .len duckShape2 wherever this
        ; table's row count matters)
        .local duckShape2
        .byte %00111100     ; row 0  - crown of head
        .byte %01110100     ; row 1  - head
        .byte %01111111     ; row 2  - head, eye level
        .byte %01111111     ; row 3  - beak
        .byte %01111100     ; row 4  - chin, head narrows
        .byte %00111000     ; row 5  - neck
        .byte %00111000     ; row 6  - neck/body transition
        .byte %00111000     ; row 7  - body widening
        .byte %00111000     ; row 8  - body, max width
        .byte %01111110     ; row 9  - body, max width
        .byte %11111111     ; row 10 - body
        .byte %01111110     ; row 11 - body narrowing
        .byte %00111100     ; row 12 - tail / body bottom
        .byte %00100100     ; row 13 - legs
        .byte %00100110     ; row 14 - legs
        .byte %01100000     ; row 15 - webbed feet
        .endl


        run main
