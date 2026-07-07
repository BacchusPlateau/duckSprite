; printing variables and constants
putchar_ptr = $346                      ; CONSTANT: putchar_ptr = $346 (OS character output vector address)
csrhinh     = $2F0                      ; CONSTANT: csrhinh = $2F0 (OS cursor visible/hidden control address)        
rowcrs      = $54                       ; CONSTANT: rowcrs = $54 (OS zero page address that controls cursor row)
colcrs      = $55                       ; CONSTANT: colcrs = $55 (OS zero page address that controls cursor column)
offset_to_char = $30                    ; Offset from integer literal to ATASCII character equivalent of the number

; graphics variables and constants
plotX_lo    = $80       ; low byte of X coordinate (0-319 needs 2 bytes!)
plotX_hi    = $81       ; high byte of X coordinate
plotY       = $82       ; Y coordinate (0-191, fits in one byte)
temp_lo     = $83       ; temporary storage low byte
temp_hi     = $84       ; temporary storage high byte
scrptr_lo   = $85       ; calculated screen address low byte
scrptr_hi   = $86       ; calculated screen address high byte
save_lo     = $87       ; saved plotY × 8 low byte
save_hi     = $88       ; saved plotY × 8 high byte
bitpos      = $89       ; bit position within byte (plotX mod 8) that our pixel lives in
bitmask     = $8A       ; save our mask that we will use to turn ONLY our pixel on

strptr_lo   = $8B                       ; low byte of string address
strptr_hi   = $8C                       ; high byte of string address

; drawLine variables
x1      = $8D       ; start X low byte
x1_hi   = $8E       ; start X high byte
y1      = $8F       ; start Y
x2      = $90       ; end X low byte
x2_hi   = $91       ; end X high byte
y2      = $92       ; end Y
dx_lo   = $93       ; delta X low byte
dx_hi   = $94       ; delta X high byte
dy      = $95       ; delta Y
err_lo  = $96       ; error accumulator low byte
err_hi  = $97       ; error accumulator high byte

; drawCircle variables
cx      = $9B       ; center X low byte
cx_hi   = $9C       ; center X high byte
cy      = $9D       ; center Y
radius  = $9E       ; circle radius
circX   = $9F       ; current x offset (starts at 0)
circY   = $A0       ; current y offset (starts at radius)
cerr_lo = $A1       ; error term low byte (signed)
cerr_hi = $A2       ; error term high byte

; print16bit variables
p16_val_lo  = $A3       ; 16-bit value to print low byte
p16_val_hi  = $A4       ; 16-bit value to print high byte
p16_digit   = $A5       ; current digit counter

; GR.8 color registers
COLPF1  = $02C5     ; foreground pixel color shadow
COLPF2  = $02C6     ; background color shadow
COLBK   = $02C8     ; border color shadow

spritePtr_lo = $A6      ; pointer into sprite data, advances each byte
spritePtr_hi = $A7
spriteByte   = $A8      ; current byte being tested
spriteMask   = $A9      ; current bit mask (shifts right each test)
spriteRow    = $AA      ; current row (0-11)
columnBase   = $AB      ; 0 or 8 depending on which byte in the row
byteCount    = $AC      ; 0-23, total byte counter
baseX_lo     = $AD      ; ship's starting X (saved so we can recompute each pixel)
baseX_hi     = $AE
baseY        = $AF      ; ship's starting Y
bitCounter   = $B0

; =====================================================================
; CIO (Central I/O) constants
; CIO is the Atari OS I/O system. We use it to open graphics mode.
; Each I/O channel uses an IOCB (I/O Control Block) — a fixed block
; of memory containing command, device, buffer address, and aux bytes.
; We use IOCB6 (base address $0360) for graphics.
; X register = $60 tells CIOV which IOCB to use (IOCB6).
; =====================================================================
CIOV    = $E456     ; OS CIO entry point — call jsr CIOV to execute
ICCOM   = $0342     ; IOCB6 command register
                    ;   $03 = OPEN   (open a device)
                    ;   $0C = CLOSE  (close a device)
ICBAL   = $0344     ; IOCB6 buffer address low byte
                    ;   for OPEN: points to device name string "S:"
ICBAH   = $0345     ; IOCB6 buffer address high byte
                    ;   together with ICBAL forms 16-bit pointer to "S:"
ICAX1   = $034A     ; IOCB6 auxiliary byte 1
                    ;   for OPEN: $0C = read/write access mode
ICAX2   = $034B     ; IOCB6 auxiliary byte 2
                    ;   for OPEN: graphics mode number (8 = GR.8)

; =====================================================================
; Screen RAM pointer
; After CIO opens GR.8, the OS stores the address of screen RAM
; in SAVMSC (two bytes). $58 = low byte, $59 = high byte.
; On our 800XL PAL system screen RAM ends up at $B060.
; =====================================================================
SAVMSC  = $58       ; zero page address — low byte of screen RAM address
                    ; $59 automatically contains the high byte

; =====================================================================
; Attract mode constants
; The Atari OS has an attract mode that kicks in after inactivity
; to prevent screen burn-in. It does this by desaturating all colors
; making everything appear as shades of grey/blue.
; We must continuously reset these in our main loop to keep colors!
; =====================================================================
ATRACT  = $4D       ; attract mode counter — OS increments this each frame
                    ; when it reaches a threshold attract mode activates
                    ; we keep writing 0 to prevent it from activating
ATRMSK  = $4E       ; attract mode color mask
                    ; OS ANDs all colors with this value
                    ; $FE strips hue leaving only luminance (grey/blue)
                    ; $FF = full color (no masking) — what we want

; =====================================================================
; Player-Missile Graphics (PMG) constants
; PMG is dedicated GTIA/ANTIC hardware for moving sprites — completely
; separate from the GR.8 bitmap screen RAM we've been drawing into.
; ANTIC reads this memory automatically every frame and GTIA overlays
; it on top of the playfield, with zero CPU cost for the overlay itself.
; =====================================================================

PMBASE  = $5000     ; start of our PM memory block. MUST be page-aligned
                    ; (low byte = $00) because ANTIC only stores a HIGH
                    ; byte pointer to this memory — there's no low byte
                    ; register, so the low byte is implicitly always $00

; --- OS shadow registers (same pattern as SDMCTL/SDLSTL we already use) ---
PMBASE_SHADOW = $D407   ; hardware register: tells ANTIC the HIGH byte
                        ; of where PM memory starts (PMBASE ÷ 256)
                        ; NOTE: unlike SDMCTL, there's no safe OS shadow
                        ; register for this one — we write directly to
                        ; hardware, similar to how we had to fight
                        ; attract mode by writing hardware directly

GRACTL  = $D01D     ; GTIA register — Graphics Control
                    ; controls whether players/missiles are displayed
                    ; at all, and whether collision detection is active
                    ; bit 0 = enable missile graphics
                    ; bit 1 = enable player graphics
                    ; bit 2 = enable latching (collision detection mode)

; --- Player 0 hardware registers ---
HPOSP0  = $D000     ; horizontal position of Player 0 (one byte!)
                    ; THIS is the magic register — changing this one
                    ; byte instantly moves the sprite left/right with
                    ; no redraw needed at all, unlike our manual sprite
SIZEP0  = $D008     ; width of Player 0: 0=normal, 1=double, 3=quad width
COLPM0  = $D012     ; color of Player 0 (shadow: $02C0)

; --- DMACTL bit for enabling PM DMA (added to what openGR8 already sets) ---
; DMACTL is the SAME register as SDMCTL we already use in openGR8 —
; PM graphics needs an ADDITIONAL bit set on top of what we already
; configure for the playfield, not a separate register
PMG_ENABLE_BIT = %00010000   ; bit 4 of SDMCTL enables single-line
                            ; resolution PM DMA (we'll OR this into
                            ; whatever openGR8 already sets)
SDMCTL  = $022F     ; OS shadow register for DMA control — CIO already
                    ; writes the correct playfield bits here when
                    ; opening a graphics mode; we OR in our PM bit
                    ; on top of whatever CIO set, rather than guessing                                            


; --- Corrected per bumbershootsoft.wordpress.com reference ---
GPRIOR  = $026F     ; shadow for PRIOR ($D01B) — priority/5-player mode
                    ; not strictly needed for a single player test,
                    ; but useful to know about going forward

PMG_DMACTL_VALUE = $2E    ; full correct DMACTL value, not just one bit:
                          ; bits 0-1 = playfield width (2 = normal)
                          ; bit 2 = missile DMA enable
                          ; bit 3 = player DMA enable
                          ; bit 5 = display list DMA enable (needed
                          ;         for ANY playfield to show at all!)                    

shipX = $B1        ; sprite 0 current X position
shipY = $B2        ; sprite 0 current Y position
walkFrame = $B3    ; increments on ANY movement (either axis) — drives
                   ; which walk-cycle frame shows, independent of
                   ; shipX/shipY themselves
; =====================================================================
; Joystick input
; The OS polls the joystick hardware every frame and stores the
; debounced result here for us — no need to touch the PIA directly.
; =====================================================================
STICK0  = $0278     ; joystick 1 direction bits, ACTIVE LOW (0=pressed):
                    ; bit 0 = Up, bit 1 = Down, bit 2 = Left, bit 3 = Right