{
    --------------------------------------------
    Filename: core.con.sx1276.spin
    Author: Jesse Burt
    Description: Low-level constants
    Copyright (c) 2019
    Started Oct 6, 2019
    Updated Oct 7, 2019
    See end of file for terms of use.
    --------------------------------------------
}

CON

' SPI Configuration
    CPOL                        = 0
    CLK_DELAY                   = 10
    MOSI_BITORDER               = 5             'MSBFIRST
    MISO_BITORDER               = 0             'MSBPRE

    WRITE                       = 1 << 7

' General/shared functionality
    FIFO                        = $00
    OPMODE                      = $01
    OPMODE_MASK                 = $CF
        FLD_LONGRANGEMODE       = 7
        FLD_ACCESSSHAREDREG     = 6
        FLD_LOWFREQUENCYMODEON  = 3
        FLD_MODE                = 0
        BITS_MODE               = %111
        MASK_LONGRANGEMODE      = OPMODE_MASK ^ (1 << FLD_LONGRANGEMODE)
        MASK_ACCESSSHAREDREG    = OPMODE_MASK ^ (1 << FLD_ACCESSSHAREDREG)
        MASK_LOWFREQUENCYMODEON = OPMODE_MASK ^ (1 << FLD_LOWFREQUENCYMODEON)
        MASK_MODE               = OPMODE_MASK ^ (BITS_MODE << FLD_MODE)

    FRFMSB                      = $06
    FRFMID                      = $07
    FRFLSB                      = $08
    PACONFIG                    = $09
    PARAMP                      = $0A
    OCP                         = $0B
    LNA                         = $0C
    DIOMAPPING1                 = $40
    DIOMAPPING2                 = $41
    VERSION                     = $42
    TCXO                        = $4B
    PADAC                       = $4D
    FORMERTEMP                  = $5B
    AGCREF                      = $61
    AGCTHRESH1                  = $62
    AGCTHRESH2                  = $63
    AGCTHRESH3                  = $64

' FSK/OOK-specific functionality
    BITRATEMSB                  = $02
    BITRATELSB                  = $03
    FDEVMSB                     = $04
    FDEVLSB                     = $05
    RXCONFIG                    = $0D
    RSSICONFIG                  = $0E
    RSSICOLLISION               = $0F
    RSSITHRESH                  = $10
    RSSIVALUE                   = $11
    RXBW                        = $12
    AFCBW                       = $13
    OOKPEAK                     = $14
    OOKFIX                      = $15
    OOKAVG                      = $16
' $17..$19 - RESERVED
    AFCFEI                      = $1A
    AFCMSB                      = $1B
    AFCLSB                      = $1C
    FEIMSB                      = $1D
    FEILSB                      = $1E
    PREAMBLEDETECT              = $1F
    RXTIMEOUT1                  = $20
    RXTIMEOUT2                  = $21
    RXTIMEOUT3                  = $22
    RXDELAY                     = $23
    OSC                         = $24
    PREAMBLEMSB                 = $25
    PREAMBLELSB                 = $26
    SYNCCONFIG                  = $27
    SYNCVALUE1                  = $28
    SYNCVALUE2                  = $29
    SYNCVALUE3                  = $2A
    SYNCVALUE4                  = $2B
    SYNCVALUE5                  = $2C
    SYNCVALUE6                  = $2D
    SYNCVALUE7                  = $2E
    SYNCVALUE8                  = $2F
    PACKETCONFIG1               = $30
    PACKETCONFIG2               = $31
    PAYLOADLENGTH               = $32
    NODEADRS                    = $33
    BROADCASTADRS               = $34
    FIFOTHRESH                  = $35
    SEQCONFIG1                  = $36
    SEQCONFIG2                  = $37
    TIMERRESOL                  = $38
    TIMER1COEF                  = $39
    TIMER2COEF                  = $3A
    IMAGECAL                    = $3B
    TEMP                        = $3C
    LOWBAT                      = $3D
    IRQFLAGS1                   = $3E
    IRQFLAGS2                   = $3F
    PLLHOP                      = $44
    BITRATEFRAC                 = $5D

' LoRa-specific functionality
    FIFOADDRPTR                 = $0D   'LORA
    FIFOTXBASEADDR              = $0E   'LORA
    FIFORXBASEADDR              = $0F   'LORA
    FIFORXCURRENTADDR           = $10   'LORA
    IRQFLAGS_MASK               = $11   'LORA
    IRQFLAGS                    = $12   'LORA
    RXNBBYTES                   = $13   'LORA
    RXHEADERCNTVALUEMSB         = $14   'LORA
    RXHEADERCNTVALUELSB         = $15   'LORA
    RXPACKETCNTVALUEMSB         = $16   'LORA
    RXPACKETCNTVALUELSB         = $17   'LORA
    MODEMSTAT                   = $18   'LORA
    PKTSNRVALUE                 = $19   'LORA
    PKTRSSIVALUE                = $1A   'LORA
    LORA_RSSIVALUE              = $1B   'LORA
    HOPCHANNEL                  = $1C   'LORA
    MODEMCONFIG1                = $1D   'LORA
    MODEMCONFIG2                = $1E   'LORA
    SYMBTIMEOUT                 = $1F   'LORA
    LORA_PREAMBLEMSB            = $20   'LORA
    LORA_PREAMBLELSB            = $21   'LORA
    LORA_PAYLOADLENGTH          = $22   'LORA
    MAXPAYLOADLENGTH            = $23   'LORA
    HOPPERIOD                   = $24   'LORA
    FIFORXBYTEADDR              = $25   'LORA
    MODEMCONFIG3                = $26   'LORA
' $27 - RESERVED
    LORA_FEIMSB                 = $28   'LORA
    LORA_FEIMID                 = $29   'LORA
    LORA_FEILSB                 = $2A   'LORA
' $2B - RESERVED
    RSSIWIDEBAND                = $2C   'LORA
' $2D..2E - RESERVED
    IFFREQ1                     = $2F   'LORA
    IFFREQ2                     = $30   'LORA
    DETECTOPTIMIZE              = $31   'LORA
' $32 - RESERVED
    INVERTIQ                    = $33   'LORA
' $34..$35 - RESERVED
    HIGHBWOPTIMIZE1             = $36   'LORA
    DETECTIONTHRESHOLD          = $37   'LORA
' $38 - RESERVED
    SYNCWORD                    = $39   'LORA
    HIGHBWOPTIMIZE2             = $3A   'LORA
    INVERTIQ2                   = $3B
' $3C..$3F - RESERVED

PUB Null
' This is not a top-level object
