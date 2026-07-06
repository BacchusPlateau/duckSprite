        icl 'equates.asm'
        icl 'routines.asm'

        org $2000

 .proc main

        jsr openGR8
        jsr initPMG

        ; point scrptr at Player 0's section, offset 16 (visible Y start)
        lda #<PMBASE
        sta scrptr_lo
        lda #>PMBASE
        clc
        adc #$02
        sta scrptr_hi
        lda scrptr_lo
        clc
        adc #16
        sta scrptr_lo

        ldx #0
loadDuck:
        lda duckShape,x
        ldy #0
        sta (scrptr_lo),y

        inc scrptr_lo
        bne loadNoCarry
        inc scrptr_hi
loadNoCarry:
        inx
        cpx #.len duckShape
        bne loadDuck

        ; set the ship's STARTING position only — waitFrames will
        ; keep re-asserting these registers continuously from here on
        mva #90 shipX
        ;lda shipX
        ;sta HPOSP0
        ;lda #$1E
        ;sta COLPM0

        ;ldx #10
        ;jsr waitFrames           ; holds here ~1 second, refreshing
                                ; HPOSP0/COLPM0 every frame internally

        ; shipX is CHANGING here, so we explicitly update it —
        ; but we don't need to also write HPOSP0/COLPM0 right after,
        ; because the NEXT waitFrames call will pick up the new
        ; shipX value automatically and keep refreshing it
        ;mva #120 shipX
keepDucking:
       
        lda shipX               ; a = shipX
        cmp #120                ; a == 120?
        beq stop                ; if equal, jumpt OUT

        sta HPOSP0              ; push shipX to the horizontal position for sprite player zero P0
        inc shipX               ; shipX++
        lda #$1E                ; TODO: this should be a variable in equates, why the magic string? 
        sta COLPM0              ; COLPM0 is the color register for Player 0 

        ldx #10                 ; this seems to be a good value?
        jsr waitFrames           ; holds here ~1 second, refreshing
                                 ; HPOSP0/COLPM0 every frame internally
        jmp keepDucking        


stop:
        jsr fightAttract
        lda shipX
        sta HPOSP0               ; stop loop also needs to refresh,
        lda #$1E                ; since it's another long-running
        sta COLPM0               ; loop with the same characteristics
        jmp stop

        .endp

        
; Data section
;===================================================================

        ; Bit order: bit 7 (leftmost) = screen-left, bit 0 (rightmost) =
        ; screen-right, same convention as beowulfShape. Row count is
        ; free — .len duckShape in the load loop above picks up
        ; whatever you put here, add/remove rows as you like.
        .local duckShape
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
        .byte %00100100     ; row 14 - legs
        .byte %01100110     ; row 15 - webbed feet
        .endl


        run main