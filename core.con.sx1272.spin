{
    --------------------------------------------
    Filename: core.con.sx1272.spin
    Author:
    Description:
    Copyright (c) 2019
    Started Sep 18, 2019
    Updated Sep 18, 2019
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

' General functionality
    FIFO                        = $00
    OPMODE                      = $01
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
    OOKAVG                      = $15
    SYMBTIMEOUTLSB              = $15
    AFCFEI                      = $1A
    AFCMSB                      = $1B
    AFCLSB                      = $1C
    FEIMSB                      = $1D
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
    IRQFLAGS                    = $10   'LORA
    IRQFLAGS_MASK               = $11   'LORA
    FREQIFMSB                   = $12   'LORA
    FREQIFLSB                   = $13   'LORA
    SYMBTIMEOUTMSB              = $14   'LORA
    TXCFG                       = $16   'LORA
    LORA_PAYLOADLENGTH          = $17   'LORA
    LORA_PREAMBLEMSB            = $18   'LORA
    LORA_PREAMBLELSB            = $19   'LORA
    MODULATIONCFG               = $1A   'LORA
    RFMODE                      = $1B   'LORA
    HOPPERIOD                   = $1C   'LORA
    NBRXBYTES                   = $1D   'LORA
    RXHEADERCNTVALUE            = $1F   'LORA
    RXPACKETCNTVALUE            = $20   'LORA
    MODEMSTAT                   = $21   'LORA
    PKTSNRVALUE                 = $22   'LORA
    LORA_RSSIVALUE              = $23   'LORA
    PKTRSSIVALUE                = $24   'LORA
    HOPCHANNEL                  = $25   'LORA
    RXDATAADDR                  = $26   'LORA

PUB Null
' This is not a top-level object
