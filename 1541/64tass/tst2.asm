lruint  ldx  #0         ; init lru table
lruilp  txa
        sta  lrutbl,x
        inx
        cpx  #cmdchn
        bne  lruilp

	lda  #cmdchn+2
        sta  lrutbl,x
        rts

; least recently used table update
; input parms: lindx-current chnl
; output parms: lrutbl-update

lruupd  ldy  #cmdchn
        ldx  lindx
lrulp1  lda  lrutbl,y
        stx  lrutbl,y
        cmp  lindx
        beq  lruext

        dey
        bmi  lruint

        tax
        jmp  lrulp1

lruext  rts

; double buffer
; rtn to switch the active and
; inactive buffers
dblbuf
        jsr  lruupd
        jsr  getina
        bne  dbl15
        jsr  setdrn
        jsr  getbuf
        bmi  dbl30
        jsr  putina
        lda  track
        pha
        lda  sector
        pha
        lda  #1
        jsr  drdbyt
        sta  sector
        lda  #0
        jsr  drdbyt
        sta  track
        beq  dbl10

        jsr  typfil
        beq  dbl05      ; it's rel

        jsr  tstwrt
        bne  dbl05      ; read ahead

        jsr  tglbuf     ; just switch on write
        jmp  dbl08

dbl05	jsr  tglbuf
	jsr  rdab
dbl08
        pla
        sta  sector
        pla
        sta  track
        jmp  dbl20
dbl10
        pla
        sta  sector
        pla
        sta  track
dbl15   jsr  tglbuf
dbl20   jsr  getact
        tax
        jmp  watjob
;
; there are no buffers to steal
;
dbl30
        lda  #nochnl
        jmp  cmderr
;
;********************************
;
dbset
        jsr  lruupd
        jsr  getina
        bne  dbs10

        jsr  getbuf
        bmi  dbl30      ; no buffers

        jsr  putina     ; store inactive buff #
dbs10
        rts
; toggle the inactive and active
; buffers. input parms: lindx-chnl#
;
tglbuf  ldx  lindx
        lda  buf0,x
        eor  #$80
        sta  buf0,x
        lda  buf1,x
        eor  #$80
        sta  buf1,x
        rts

pibyte  ldx  #iwsa
        stx  sa
        jsr  fndwch
        jsr  setlds
        jsr  typfil
        bcc  pbyte

        lda  #ovrflo
        jsr  clrflg
pbyte   lda  sa
        cmp  #15
        beq  l42

        bne  l40

; main routine to write to chanl
;
put     lda  orgsa      ; is chanl cmd or dat
        and  #$8f
        cmp  #15        ; <15
        bcs  l42

l40     jsr  typfil     ; data byte to store
        bcs  l41        ; branch if rnd

        lda  data       ; seq file
        jmp  wrtbyt     ; write byte to chanl

l41     bne  l46

        jmp  wrtrel

l46     lda  data       ; rnd file write
        jsr  putbyt     ; write to chanl
        ldy  lindx      ; prepare nxt byte
        jmp  rnget2

l42     lda  #cmdchn    ; write to cmd chanl
        sta  lindx
        jsr  getpnt     ; test if comm and buffer full
        cmp  #<cmdbuf+cmdlen+1
        beq  l50        ; it is full (>cmdlen)

        lda  data       ; not full yet
        jsr  putbyt     ; store the byte
l50     lda  eoiflg     ; tst if lst byte of msg
        beq  l45        ; it is
        rts     	; not yet , return

l45     inc  cmdwat     ; set cmd waiting flag
        rts
; put .a into active buffer of lindx
;
putbyt  pha     	;  save .a
        jsr  getact     ; get active buf#
        bpl  putb1      ; brach if there is one

        pla     	; no buffer error
        lda  #filnop
        jmp  cmderr     ;  jmp to error routine

putb1   asl  a          ; save the byte in buffer
        tax
        pla
        sta  (buftab,x)
        inc  buftab,x   ; inc the buffer pointer
        rts     	; last slot in buf, acm=1
;
; find the active buffer # (lindx)
intdrv  jsr  simprs     ; init drvs (command)
	jsr  initdr	; set def parms
        jmp  endcmd

itrial  .proc
	jsr  bam2a
	tay
	ldx  buf0,y
	cpx  #$ff
	bne  nk
	pha
	jsr  getbuf
	tax
	bpl  +
	lda  #nochnl
	jsr  cmder3
+	pla
	tay
	txa
	ora  #$80
	sta  buf0,y
nk	txa
	and  #15
	sta  jobnum
	ldx  #$00
	stx  sector
	ldx  dirtrk
	stx  track
	jsr  seth
	lda  #seek
	jmp  dojob
	.pend

initdr  jsr  clnbam
	jsr  cldchn
        jsr  itrial
	ldx  drvnum
	lda  #0
	sta  mdirty,x
	txa
	asl  a
	tax
	lda  header
	sta  dskid,x
	lda  header+1
	sta  dskid+1,x
	jsr  doread
	lda  jobnum
        asl  a
        tax
        lda  #2         ; skip link bytes
        sta  buftab,x
        lda  (buftab,x)
        ldx  drvnum
        sta  dskver,x   ; set up disk version #
	lda  #0
	jmp  ptch51
	nop
rtch51
nfcalc  jsr  setbpt
	ldy  #4
	lda  #0
	tax
-	clc
	adc  (bmpnt),y
	bcc +
	inx
+
-	iny
	iny
	iny
	iny
	cpy  #$48
	beq -
	cpy #$90
	bne --
	pha
	txa
	ldx  drvnum
	sta  ndbh,x
	pla
	sta  ndbl,x
	rts

strrd   jsr  sethdr     ; start dbl buf, use
        jsr  rdbuf      ; trk, sec as start block
        jsr  watjob
        jsr  getbyt
        sta  track
        jsr  getbyt
        sta  sector
        rts

strdbl  jsr  strrd
        lda  track
        bne  str1
        rts

str1    jsr  dblbuf
        jsr  sethdr
        jsr  rdbuf
        jmp  dblbuf

rdbuf   lda  #read	; rd job on trk, sec
        bne  strtit

wrtbuf  lda  #write	; wr job on trk, sec
strtit  sta  cmd
        jsr  getact
        tax
        jsr  setljb
        txa
        pha
        asl  a
        tax
        lda  #0
        sta  buftab,x
        jsr  typfil
        cmp  #4
        bcs  wrtc1      ; not sequential type

        inc  nbkl,x
        bne  wrtc1

        inc  nbkh,x
wrtc1   pla
        tax
        rts

fndrch  lda  sa
        cmp  #maxsa+1
        bcc  fndc20

        and  #$f
fndc20  cmp  #cmdsa
        bne  fndc25

        lda  #errsa
fndc25  tax
        sec
        lda  lintab,x
        bmi  fndc30

        and  #$f
        sta  lindx
        tax
        clc
fndc30  rts

fndwch  lda  sa
        cmp  #maxsa+1
        bcc  fndw13

        and  #$f
fndw13  tax
        lda  lintab,x
        tay
        asl  a
        bcc  fndw15

        bmi  fndw20

fndw10  tya
        and  #$0f
        sta  lindx
        tax
        clc
        rts

fndw15  bmi  fndw10

fndw20  sec
        rts
typfil          	; get file type
        ldx  lindx
        lda  filtyp,x
        lsr  a
        and  #7
        cmp  #reltyp
        rts

getpre  jsr  getact
        asl  a
        tax
        ldy  lindx
        rts

; read byte from active buffer
; and set flag if last data byte
; if last then z=1 else z=0 ;

getbyt	jsr  getpre
        lda  lstchr,y
        beq  getb1

        lda  (buftab,x)
        pha
        lda  buftab,x
        cmp  lstchr,y
        bne  getb2

        lda  #$ff
        sta  buftab,x
getb2   pla
        inc  buftab,x
        rts

getb1   lda  (buftab,x)
        inc  buftab,x
        rts
;
; read a char from file and read next
; block of file if needed.
; set chnrdy=eoi if end of file
;
rdbyt   jsr  getbyt
        bne  rd3
        sta  data

rd0     lda  lstchr,y
        beq  rd1
        lda  #eoiout
rd01    sta  chnrdy,y
        lda  data
        rts
rd1     jsr  dblbuf
        lda  #0
        jsr  setpnt
        jsr  getbyt
        cmp  #0
        beq  rd4

        sta  track
        jsr  getbyt
        sta  sector
        jsr  dblbuf
        jsr  setdrn
        jsr  sethdr
        jsr  rdbuf
        jsr  dblbuf
        lda  data
rd3     rts
rd4     jsr  getbyt
        ldy  lindx
        sta  lstchr,y
        lda  data
        rts

; write a char to chanl and write
; buffer out to disk if its full
;
wrtbyt  jsr  putbyt
        beq  wrt0
        rts

wrt0    jsr  setdrn
	jsr  nxtts
        lda  #0
        jsr  setpnt
        lda  track
        jsr  putbyt
        lda  sector
        jsr  putbyt
        jsr  wrtbuf
        jsr  dblbuf
        jsr  sethdr
        lda  #2
        jmp  setpnt
;
; inc pointer of active buffer
; by .a
;
incptr
        sta  temp
        jsr  getpnt
        clc
        adc  temp
        sta  buftab,x
        sta  dirbuf
        rts

setdrn  jsr  getact
        tax
        lda  lstjob,x
        and  #1
        sta  drvnum
        rts
