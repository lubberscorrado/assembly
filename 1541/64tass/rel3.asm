;********************************
;*
;*
;* rdrel
;*
;*
;********************************
;*
;*

rdrel
        lda  #lrf
        jsr  tstflg
        bne  rd05       ; no record error
;
rd10
        jsr  getpre
        lda  buftab,x
        cmp  lstchr,y
        beq  rd40

        inc  buftab,x
        bne  rd20

        jsr  nrbuf
rd15
        jsr  getpre
rd20
        lda  (buftab,x)
rd25
        sta  chndat,y
        lda  #rndrdy
        sta  chnrdy,y
        lda  buftab,x
        cmp  lstchr,y
        beq  rd30
        rts
rd30
        lda  #rndeoi
        sta  chnrdy,y
        rts
rd40
        jsr  nxtrec
        jsr  getpre
        lda  data
        jmp  rd25

rd05
        ldx  lindx      ; no record char set up
        lda  #cr
        sta  chndat,x
        lda  #rndeoi
        sta  chnrdy,x
;no record error
        lda  #norec
        jsr  cmderr
