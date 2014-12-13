; build a new map on diskette

newmap
newmpv
        jsr  clnbam
        ldy  #0
        lda  #18        ; set link to 18.1
        sta  (bmpnt),y
        iny
        tya
        sta  (bmpnt),y
        iny
        iny
        iny     	; .y=4
nm10
        lda  #0         ; clear track map
        sta  t0
        sta  t1
        sta  t2

        tya      	; 4=>1
        lsr  a
        lsr  a          ; .a=track #
        jsr  maxsec     ; store blks free byte away
        sta  (bmpnt),y
        iny
        tax
nm20
        sec     	; set map bits
        rol  t0         ;      t0          t1          t2
        rol  t1         ;   76543210  111111         xxx21111
        rol  t2         ;             54321098          09876
        dex      	;   11111111  11111111          11111
        bne  nm20
nm30            	; .x=0
        lda  t0,x
        sta  (bmpnt),y  ; write out bit map
        iny
        inx
        cpx  #3
        bcc  nm30
        cpy  #$90       ; end of bam, 4-143
        bcc  nm10

        jmp  nfcalc     ; calc # free sectors

; write out the bit map to
; the drive in lstjob(active)

mapout  jsr  getact
        tax
        lda  lstjob,x
mo10    and  #1
        sta  drvnum     ; check bam before writing

; write bam according to drvnum

scrbam
        ldy  drvnum
        lda  mdirty,y
        bne  sb10
        rts     	; not dirty
sb10
        lda  #0         ; set to clean bam
        sta  mdirty,y
        jsr  setbpt     ; set bit map ptr
        lda  drvnum
        asl  a
        pha
;put memory images to bam
        jsr  putbam
        pla
        clc
        adc  #1
        jsr  putbam
; verify the bam block count
; matches the bits

        lda  track
        pha     	; save track var
        lda  #1
        sta  track
sb20
        asl  a
        asl  a
        sta  bmpnt

        jsr  avck       ; check available blocks

        inc  track
        lda  track
        cmp  trknum
        bcc  sb20
        pla     	; restore track var
        sta  track

        jmp  dowrit     ; write it out

; set bit map ptr, read in bam if nec.

setbpt
        jsr  bam2a
        tax
        jsr  redbam     ; read bam if not in
        ldx  jobnum
        lda  bufind,x   ; set the ptr
        sta  bmpnt+1
        lda  #0
        sta  bmpnt
        rts

; calc the number of free blocks on drvnum

numfre
        ldx  drvnum
        lda  ndbl,x
        sta  nbtemp
        lda  ndbh,x
        sta  nbtemp+1
        rts
