        icl 'equates.asm'
        icl 'routines.asm'

        org $2000

 .proc main

        jsr openGR8
        jsr initPMG

        ; set the duck's STARTING position BEFORE the first draw —
        ; loadDuckFrame reads shipY to know where to draw, so it must
        ; already hold a real value, not whatever garbage zero-page
        ; happened to have at boot
        mva #90 shipX
        mva #0 shipY
        mva #0 walkFrame

        ; load the STARTING frame (duckShape1) into PM memory —
        ; point spritePtr at it and let loadDuckFrame do the copy
        lda #<duckShape1
        sta spritePtr_lo
        lda #>duckShape1
        sta spritePtr_hi
        jsr loadDuckFrame

keepDucking:
        lda shipX               ; a = shipX
        sta HPOSP0              ; push shipX to Player 0's horizontal position

        jsr eraseDuckFrame      ; clear the OLD row — must happen before
                                ; shipY changes below, or we'd erase the
                                ; NEW position instead of the old one

        mva #0 temp_lo          ; "did we move this step?" flag — reused
                                ; zero-page var, unused elsewhere here

        lda STICK0
        and #%00000100      ; isolate bit 2 (Left)
        beq isLeft
        jmp checkRight
isLeft:
        dec shipX
        mva #1 temp_lo

checkRight:
        lda STICK0
        and #%00001000      ; isolate bit 3 (Right)
        beq isRight
        jmp checkUp
isRight:
        inc shipX
        mva #1 temp_lo

checkUp:
        lda STICK0
        and #%00000001      ; isolate bit 0 (Up)
        beq isUp
        jmp checkDown
isUp:
        dec shipY
        mva #1 temp_lo

checkDown:
        lda STICK0
        and #%00000010      ; isolate bit 1 (Down)
        beq isDown
        jmp doneReading
isDown:
        inc shipY
        mva #1 temp_lo

doneReading:
        lda temp_lo             ; did ANY direction fire this step?
        beq noFlip              ; no movement at all -> don't flip
        inc walkFrame           ; exactly ONE increment per step,
                                ; no matter how many axes moved
noFlip:

        ; --- pick this step's walk-cycle frame ---
        ; even walkFrame -> duckShape1, odd walkFrame -> duckShape2
        ; walkFrame now increments once per MOVED STEP, not once per
        ; axis — so diagonals flip the same as straight movement

        lda walkFrame
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
 
        ; Target row = playfield top (PMBASE+$0200+16) + shipY.
        ; shipY=0 means "top of the visible screen" — the fixed
        ; +16 offset is baked into this proc so callers never need
        ; to think about PM memory layout, only screen position.
        lda #<(PMBASE+$0200+16)
        clc
        adc shipY               ; no '#' — read the BYTE STORED at
                                 ; shipY, not the address itself
        sta scrptr_lo
 
        lda #>(PMBASE+$0200+16)
        adc #0                  ; propagate any carry out of the low
                                 ; byte add above — do NOT clc here,
                                 ; we want to keep that carry
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


;=========================================================================
; eraseDuckFrame
; Zeroes 16 bytes at Player 0's CURRENT row (same address math as
; loadDuckFrame). Call this BEFORE shipY changes, so it clears where
; the duck IS, not where it's about to go — PM memory doesn't clear
; itself, so skipping this leaves a frozen duplicate duck behind
; every time you move vertically.
;=========================================================================
        .proc eraseDuckFrame

        lda #<(PMBASE+$0200+16)
        clc
        adc shipY
        sta scrptr_lo

        lda #>(PMBASE+$0200+16)
        adc #0
        sta scrptr_hi

        ldx #0
eraseLoop:
        ldy #0
        lda #0
        sta (scrptr_lo),y

        inc scrptr_lo
        bne eraseNoCarry
        inc scrptr_hi
eraseNoCarry:
        inx
        cpx #16
        bne eraseLoop

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