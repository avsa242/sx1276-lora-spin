{
----------------------------------------------------------------------------------------------------
    Filename:       wireless.transceiver.sx1276.spin
    Description:    Driver for the SEMTECH SX1276 LoRa/FSK/OOK transceiver (LoRa mode)
    Author:         Jesse Burt
    Started:        Oct 6, 2019
    Updated:        Dec 1, 2025
    Copyright (c) 2025 - See end of file for terms of use.
----------------------------------------------------------------------------------------------------
}

CON

    { default I/O settings; these can be overridden in the parent object }
    CS                      = 0
    SCK                     = 1
    MOSI                    = 2
    MISO                    = 3
    RST                     = 0
    SPI_FREQ                = 1_000_000         ' max 10MHz


    FXOSC                   = 32_000_000
    TWO_19                  = 1 << 19
    TWO_24                  = 1 << 24
    FPSCALE                 = 10_000_000        ' scaling factor used in math
    FSTEP                   = 61_0351562        ' (FXOSC / TWO_19) * FPSCALE

    PAYLD_LEN_MAX           = 255

    ' regions
    USA                     = 0                 ' US 915MHz band
    EU868                   = 1                 ' EU 868MHz band


' Modulation modes
    FSK                     = 0
    OOK                     = 1
    LORA                    = 4

' Device modes
    SLEEPMODE               = %000
    STDBY                   = %001
    FSTX                    = %010
    TX                      = %011
    FSRX                    = %100
    RXCONT                  = %101
    RXSINGLE                = %110
    CAD                     = %111

' Transmit modes
    TXMODE_NORMAL           = 0
    TXMODE_CONT             = 1

' DIO function mapping
    DIO0_RXDONE             = %00
    DIO0_TXDONE             = %01
    DIO0_CADDONE            = %10

    DIO1_RXTIMEOUT          = %00
    DIO1_FHSSCHANGECHANNEL  = %01
    DIO1_CADDETECTED        = %10

    DIO2_FHSSCHANGECHANNEL  = %00
    DIO2_SYNCADDRESS        = %11

    DIO3_CADDONE            = %00
    DIO3_VALIDHDR           = %01
    DIO3_PAYLDCRCERROR      = %10

    DIO4_CADDETECTED        = %00
    DIO4_PLLLOCK            = %01

    DIO5_MODEREADY          = %00
    DIO5_CLKOUT             = %01

' Clock output modes
    CLKOUT_RC               = 6
    CLKOUT_OFF              = 7

' Power Amplifier output pin selection
    RFO                     = 0
    PABOOST                 = 1 << core.PASELECT

' Interrupt flags
    INT_RX_TIMEOUT          = 1 << 7            ' receive timeout
    INT_RX_DONE             = 1 << 6            ' receive done
    INT_PYLD_CRCERR         = 1 << 5            ' payload CRC error
    INT_VALID_HDR           = 1 << 4            ' valid header
    INT_TX_DONE             = 1 << 3            ' transmit done
    INT_CAD_DONE            = 1 << 2            ' channel activity detect done
    INT_FHSS_CHG            = 1 << 1            ' FHSS change channel
    INT_CAD_DETECT          = 1                 ' channel activity detected
    INT_ALL                 = $FF

' Payload length mode
    PKTLEN_VAR              = 0
    PKTLEN_FIXED            = 1


VAR

    long _CS, _RESET
    long _txsig_routing
    byte _region


OBJ

    spi:    "com.spi.1mhz"
    core:   "core.con.sx1276"
    time:   "time"
    u64:    "math.unsigned64"


PUB null()
' This is not a top-level object


PUB start(): status
' Start the driver using default I/O settings
    return startx(CS, SCK, MOSI, MISO, RST)


PUB startx(CS_PIN, SCK_PIN, MOSI_PIN, MISO_PIN, RESET_PIN): status
' Start the driver with custom I/O settings
'   CS_PIN:     0..31
'   SCK_PIN:    0..31
'   MOSI_PIN:   0..31
'   MISO_PIN:   0..31
'   RESET_PIN:  0..31

'   Returns: cog ID of SPI engine+1

    if (    lookdown(CS_PIN: 0..31) and lookdown(SCK_PIN: 0..31) and lookdown(MOSI_PIN: 0..31) ...
            and lookdown(MISO_PIN: 0..31) )
        if ( status := spi.init(SCK_PIN, MOSI_PIN, MISO_PIN, core.SPI_MODE) )
            time.usleep(core.T_POR)
            _CS := CS_PIN
            _RESET := RESET_PIN
            outa[_CS] := 1
            dira[_CS] := 1
            reset()
            _region := USA
            if ( lookdown(dev_id(): $11, $12) )
                return
    ' if this point is reached, something above failed
    ' Double check I/O pin assignments, connections, power
    ' Lastly - make sure you have at least one free core/cog
    return FALSE


PUB stop()
' Stop the driver
    spi.deinit()
    longfill(@_CS, 0, 3)


PUB defaults()
' Set factory defaults
    reset()


PUB preset_lora()
' Switch modem to LoRa mode, then set factory defaults
    modulation(LORA)

    agc_mode(false)
    code_rate($04_05)
    crc_check_ena(false)
    payld_len_cfg(PKTLEN_VAR)
    lna_gain(0)
    low_freq_mode(true)
    preamble_len(8)
    rx_bw(125_000)
    rx_timeout(100)
    spread_fact(7)
    set_syncwd(string($12))                     ' $12 == private networks


PUB preset_dr0()
' Physical bitrate (Rb) 980
    preset_lora()
    spread_fact(10)
'    rx_bw(125_000)


PUB preset_dr1()
' Physical bitrate (Rb) 1760
    preset_lora()
    spread_fact(9)
'    rx_bw(125_000)


PUB preset_dr2()
' Physical bitrate (Rb) 3125
    preset_lora()
    spread_fact(8)
'    rx_bw(125_000)


PUB preset_dr3()
' Physical bitrate (Rb) 5470
    preset_lora()
'    spread_fact(7)
'    rx_bw(125_000)


PUB preset_dr4()
' Physical bitrate (Rb) 12500
    preset_lora()
    spread_fact(8)
'    rx_bw(125_000)


PUB preset_dr8()
' Physical bitrate (Rb) 980
    preset_lora()
    spread_fact(12)
    rx_bw(500_000)


PUB preset_dr9()
' Physical bitrate (Rb) 1760
    preset_lora()
    spread_fact(11)
    rx_bw(500_000)


PUB preset_dr10()
' Physical bitrate (Rb) 3900
    preset_lora()
    spread_fact(10)
    rx_bw(500_000)


PUB preset_dr11()
' Physical bitrate (Rb) 7000
    preset_lora()
    spread_fact(9)
    rx_bw(500_000)


PUB preset_dr12()
'  Physical bitrate (Rb) 12500
    preset_lora()
    spread_fact(8)
    rx_bw(500_000)


PUB preset_dr13()
' Physical bitrate (Rb) 21900
    preset_lora()
'    spread_fact(7)
    rx_bw(500_000)


PUB agc_mode(md=-2): c
' Enable AGC
'   Valid values:
'       TRUE(-1 or 1), FALSE (0) (default)
'   Any other value polls the chip and returns the current setting
    c := readreg(core.MDMCFG3)
    case abs(md)
        0, 1:
            md := (md & 1) << core.AGCAUTOON
            md := ( (c & core.AGCAUTOON_MASK) | md)
            writereg(core.MDMCFG3, md)
        other:
            return ( (c >> core.AGCAUTOON) & 1) == 1


PUB carrier_freq(frq=-2): c | opmode_orig
' Set carrier frequency, in Hz
'   Valid values: See case table below
'   Any other value polls the chip and returns the current setting
'   NOTE: The default is 434_000_000
    opmode_orig := 0
    case frq
        137_000_000..175_000_000, 410_000_000..525_000_000, 862_000_000..1_020_000_000:
            frq := u64.multdiv(frq, FPSCALE, FSTEP)
            opmode_orig := opmode()
            opmode(STDBY)                       ' must be in standby to change freqs
            writereg(core.FRFMSB, frq, 3)
            opmode(opmode_orig)                 ' change back to previous opmode
        other:
            return u64.multdiv(FSTEP, readreg(core.FRFMSB, 3), FPSCALE)


PUB channel(ch=-2): c
' Set LoRa uplink channel
'   Valid values: 0..63
'   Any other value polls the chip and returns the current setting
'   NOTE: Actual effective frequency depends on currently set band plan/region
    case _region
        USA:
            case ch
                0..63:
                    ch := 902_300_000 + (200_000 * ch)
                    carrier_freq(ch)
                other:
                    c := carrier_freq()
                    return (c - 902_300_000) / 200_000
        EU868:
            case ch
                0..9:
                    ch := lookupz(ch:   868_100_000, 868_300_000, 868_500_000, ...
                                                867_100_000, 867_300_000, 867_500_000, ...
                                                867_700_000, 867_900_000, 868_800_000, ...
                                                869_525_000)
                other:
                    c := carrier_freq()
                    return lookdownz(c: 868_100_000, 868_300_000, 868_500_000, ...
                                                867_100_000, 867_300_000, 867_500_000, ...
                                                867_700_000, 867_900_000, 868_800_000, ...
                                                869_525_000)


PUB clk_out(d=-2): c
' Set clkout frequency, as a divisor of FXOSC
'   Valid values:
'       1, 2, 4, 8, 16, 32, CLKOUT_RC (6), CLKOUT_OFF (7)
'   Any other value polls the chip and returns the current setting
'   NOTE: For optimal efficiency, it is recommended to disable the clock output (CLKOUT_OFF)
'       unless needed
    c := readreg(core.OSC)
    case d
        1, 2, 4, 8, 16, 32, CLKOUT_RC, CLKOUT_OFF:
            d := lookdownz(d: 1, 2, 4, 8, 16, 32, CLKOUT_RC, CLKOUT_OFF)
            d := ((c & core.CLKOUT_MASK) | d)
            writereg(core.OSC, d)
        other:
            c &= core.CLKOUT_BITS
            return lookupz(c: 1, 2, 4, 8, 16, 32, CLKOUT_RC, CLKOUT_OFF)


PUB code_rate(r=-2): c
' Set Error code rate
'   Valid values:
'                   k/n
'       $04_05  =   4/5 (default)
'       $04_06  =   4/6
'       $04_07  =   4/7
'       $04_08  =   4/8
'   Any other value polls the chip and returns the current setting
    c := readreg(core.MDMCFG1)
    case r
        $04_05..$04_08:
            r := lookdown(r: $04_05, $04_06, $04_07, $04_08) << core.CODERATE
            r := ((c & core.CODERATE_MASK) | r)
            writereg(core.MDMCFG1, r)
        other:
            c := (c >> core.CODERATE) & core.CODERATE_BITS
            return lookup(c: $04_05, $04_06, $04_07, $04_08)


PUB crc_check_ena(e=-2): c
' Enable CRC generation and check on payload
'   Valid values: TRUE (-1 or 1), FALSE (0)
'   Any other value polls the chip and returns the current setting
    c := readreg(core.MDMCFG2)
    case abs(e)
        0, 1:
            e := abs(e) << core.RXPAYLDCRCON
            e := ((c & core.RXPAYLDCRCON_MASK) | e)
            writereg(core.MDMCFG2, e)
        other:
            return ((c >> core.RXPAYLDCRCON) & 1) == 1


PUB data_rate_offset(o=-2): c
' Set data rate offset value used in conjunction with AFC, in ppm
'   Valid values: 0..255
'   Any other value polls the chip and returns the current setting
    case o
        0..255:
            writereg(core.PPMCORRECTION, o)
        other:
            return readreg(core.PPMCORRECTION)


PUB dev_id(): id
' Version code of the chip
'   Returns:
'       Bits 7..4: full revision number
'       Bits 3..0: metal mask revision number
'   Known values: $11, $12
    return readreg(core.VERSION)


PUB fifo_addr_ptr(ptr=-2): c 'XXX needs clarification
' Set SPI interface address pointer in FIFO data buffer
'   Valid values: $00..$FF
'   Any other value polls the chip and returns the current setting
    case ptr
        $00..$FF:
            writereg(core.FIFOADDRPTR, ptr)
        other:
            return readreg(core.FIFOADDRPTR)


PUB fifo_rx_base_ptr(ptr=-2): c
' Set start address within FIFO for received data
'   Valid values: $00..$FF
'   Any other value polls the chip and returns the current setting
    case ptr
        $00..$FF:
            writereg(core.FIFORXBASEADDR, ptr)
        other:
            return readreg(core.FIFORXBASEADDR)


PUB fifo_rx_current_addr(): a
' Start address (in FIFO) of last packet received
'   Returns: Starting address of last packet received
    return readreg(core.FIFORXCURRENTADDR)


PUB fifo_rx_ptr(): p
' Current value of receive FIFO pointer
'   Returns: Address of last byte written by LoRa receiver
    return readreg(core.FIFORXBYTEADDR)


PUB fifo_tx_base_ptr(ptr=-2): c
' Set start address within FIFO for transmitted data
'   Valid values: $00..$FF
'   Any other value polls the chip and returns the current setting
    case ptr
        $00..$FF:
            writereg(core.FIFOTXBASEADDR, ptr)
        other:
            return readreg(core.FIFOTXBASEADDR)


PUB gpio0(md=-2): c
' Assert DIO0 pin on set mode
'   Valid values:
'       DIO0_RXDONE (0) - Packet reception complete
'       DIO0_TXDONE (64) - FIFO payload transmission complete
'       DIO0_CADDONE (128) - Channel Activity Detected
    c := readreg(core.DIOMAP1)
    case md
        DIO0_RXDONE, DIO0_TXDONE, DIO0_CADDONE:
            md <<= core.DIO0MAP
            md := ((c & core.DIO0MAP_MASK) | md)
            writereg(core.DIOMAP1, md)
        other:
            return (c >> core.DIO0MAP) & %11


PUB gpio1(md=-2): c
' Assert DIO1 pin on set mode
'   Valid values:
'       DIO1_RXTIMEOUT (0) - Packet reception timed out
'       DIO1_FHSSCHANGECHANNEL (64) - FHSS Changed channel
'       DIO1_CADDETECTED (128) - Channel Activity Detected
    c := readreg(core.DIOMAP1)
    case md
        DIO1_RXTIMEOUT, DIO1_FHSSCHANGECHANNEL, DIO1_CADDETECTED:
            md <<= core.DIO1MAP
            md := ((c & core.DIO1MAP_MASK) | md)
            writereg(core.DIOMAP1, md)
        other:
            return (c >> core.DIO1MAP) & %11


PUB gpio2(md=-2): c
' Assert DIO2 pin on set mode
'   Valid values:
'       DIO2_FHSSCHANGECHANNEL (0) - FHSS Changed channel
'       DIO2_FHSSCHANGECHANNEL (64) - FHSS Changed channel
'       DIO2_FHSSCHANGECHANNEL (128) - FHSS Changed channel
    c := readreg(core.DIOMAP1)
    case md
        DIO2_FHSSCHANGECHANNEL, DIO2_SYNCADDRESS:
            md <<= core.DIO2MAP
            md := ((c & core.DIO2MAP_MASK) | md)
            writereg(core.DIOMAP1, md)
        other:
            return (c >> core.DIO2MAP) & %11


PUB gpio3(md=-2): c
' Assert DIO3 pin on set mode
'   Valid values:
'       DIO3_CADDONE (0) - Channel Activity Detection complete
'       DIO3_VALIDHDR (64) - Valider header received in RX mode
'       DIO3_PAYLDCRCERROR (128) - CRC error in received payload
    c := readreg(core.DIOMAP1)
    case md
        DIO3_CADDONE, DIO3_VALIDHDR, DIO3_PAYLDCRCERROR:
            md <<= core.DIO3MAP
            md := ((c & core.DIO3MAP_MASK) | md)
            writereg(core.DIOMAP1, md)
        other:
            return c & %11


PUB gpio4(md=-2): c
' Assert DIO4 pin on set mode
'   Valid values:
'       DIO4_CADDETECTED (0) - Channel Activity Detected
'       DIO4_PLLLOCK (64) - PLL Locked
'       DIO4_PLLLOCK (128) - PLL Locked
    c := readreg(core.DIOMAP2)
    case md
        DIO4_CADDETECTED, DIO4_PLLLOCK:
            md <<= core.DIO4MAP
            md := ((c & core.DIO4MAP_MASK) | md)
            writereg(core.DIOMAP2, md)
        other:
            return (c >> core.DIO4MAP) & %11


PUB gpio5(md=-2): c
' Assert DIO5 pin on set mode
'   Valid values:
'       DIO5_MODEREADY (0) - Requested operation mode is ready
'       DIO5_CLKOUT (64) - Output system clock
'       DIO5_CLKOUT (128) - Output system clock
    c := readreg(core.DIOMAP2)
    case md
        DIO5_MODEREADY, DIO5_CLKOUT:
            md <<= core.DIO5MAP
            md := ((c & core.DIO5MAP_MASK) | md)
            writereg(core.DIOMAP2, md)
        other:
            return (c >> core.DIO5MAP) & %11


PUB hdr_info_valid(): f
' Flag indicating header in received packet is valid (with correct CRC)
'   Returns: TRUE (-1) if header valid, FALSE (0) otherwise
    return ( ( (modem_status() >> core.HDR_VALID) & 1) == 1)


PUB hop_channel(): c
' Returns current frequency hopping channel
    return ( readreg(core.HOPCHANNEL) & core.FHSSPRES_CHAN_BITS )


PUB hop_period(p=-2): c
' Set symbol periods between frequency hops
'   Valid values: 0..255
'   Any other value polls the chip and returns the current setting
'   NOTE: The first hop always occurs after the first header symbol
'   NOTE: 0 effectively disables hopping
    case p
        0..255:
            writereg(core.HOPPERIOD, p)
        other:
            return readreg(core.HOPPERIOD)


PUB idle()
' Change chip state to idle (standby)
    opmode(STDBY)


PUB int_clear(m)
' Clear interrupt flags
'   Valid values:
'   Bits 7..0 (0: don't clear interrupt, 1: clear interrupt)
'       7: Receive timeout
'       6: Receive done
'       5: Payload CRC error
'       4: Valid header
'       3: Transmit done
'       2: CAD done
'       1: FHSS change channel
'       0: CAD detected
'   Any other value is ignored
    writereg(core.IRQFLAGS, (m & $ff) )


PUB interrupt(): m
' Read interrupt flags
'   Returns: Interrupt flags as a mask
'   Bits 7..0
'       7: Receive timeout
'       6: Receive done
'       5: Payload CRC error
'       4: Valid header
'       3: Transmit done
'       2: CAD done
'       1: FHSS change channel
'       0: CAD detected
    return readreg(core.IRQFLAGS)


PUB int_mask(m=-2): c
' Set interrupt mask
'   Bits: 7..0
'       7: Receive timeout
'       6: Receive done
'       5: Payload CRC error
'       4: Valid header
'       3: Transmit done
'       2: CAD done
'       1: FHSS change channel
'       0: CAD detected
'   Any other value polls the chip and returns the current setting
    case m
        %0000_0000..%1111_1111:
            { flip bits so '1' enables interrupt, '0' clears }
            m := ((m & $ff) ^ $ff)
            writereg(core.IRQFLAGS_MASK, m)
        other:
            return (readreg(core.IRQFLAGS_MASK) ^ $ff)


PUB last_hdr_had_crc(): f
' Flag indicating last header was received with CRC on
'   Returns:
'       FALSE (0): Header indicates CRC is off
'       TRUE (-1): Header indicates CRC is on
    return ( ( (readreg(core.HOPCHANNEL) >> core.CRCONPAYLD) & 1) == 1)


PUB last_hdr_rate(): r
' Coding rate of last header received
'   Returns:
'                   k/n
'       $04_05  =   4/5
'       $04_06  =   4/6
'       $04_07  =   4/7
'       $04_08  =   4/8
    r := readreg(core.MDMSTAT) >> core.RXCODERATE
    return lookup(r: $04_05, $04_06, $04_07, $04_08)


PUB last_pkt_len(): l
' Number of payload bytes of last packet received
    return readreg(core.RXNBBYTES)


PUB lna_gain(g=-255): c
' Set LNA gain, in dB
'   Valid values: *0 (Maximum gain), -6, -12, -24, -36, -48
'   Any other value polls the chip and returns the current setting
'   NOTE: This setting will have no effect if AGC is enabled
'   NOTE: If the AGC is enabled, reading the current setting will return the current LNA gain
'       as determined by the AGC, not necessarily what had been previously set
    c := readreg(core.LNA)
    case g
        0, -6, -12, -24, -36, -48:
            g := lookdown(g: 0, -6, -12, -24, -36, -48) << core.LNAGAIN
            g := ((c & core.LNAGAIN_MASK) | g)
            writereg(core.LNA, c)
        other:
            c := (c >> core.LNAGAIN) & core.LNAGAIN_BITS
            return lookup(c: 0, -6, -12, -24, -36, -48)


PUB low_data_rate_optimize(e=-2): g
' Optimize for low data rates
'   Valid values:
'       TRUE (-1 or 1), FALSE (0)
'   Any other value polls the chip and returns the current setting
'   NOTE: This setting is mandated when the symbol length exceeds 16ms
    g := readreg(core.MDMCFG3)
    case abs(e)
        0, 1:
            e := abs(e) << core.LOWDRATEOPT
            e := ((g & core.LOWDRATEOPT_MASK) | e)
            writereg(core.MDMCFG3, e)
        other:
            return ((g >> core.LOWDRATEOPT) & 1) == 1


PUB low_freq_mode(s=-2): c | lfmask
' Enable Low frequency-specific register access
'   Valid values:
'       TRUE (-1 or 1), FALSE (0)
'   Any other value polls the chip and returns the current setting
    c := readreg(core.OPMODE)
    case abs(s)
        0, 1:
            s := (abs(s) << core.LOWFREQMODEON)
            if (c & core.LORAMODE)
                lfmask := core.LOWFREQMODEONL_MASK'xxx both of these are the same...
            else
                lfmask := core.LOWFREQMODEONL_MASK
            s := ((c & LFMASK) | s)
            writereg(core.OPMODE, s)
        other:
            return ((c >> core.LOWFREQMODEON) & 1) == 1


PUB modem_clear(): f
' Flag indicating modem is clear
    return ( ( (modem_status() >> core.MDM_CLR) & 1) == 1)


PUB modem_status(): s
' Get modem status
'   Bits: 4..0
'       4: modem clear
'       3: header info valid
'       2: RX on-going
'       1: signal synchronized
'       0: signal detected
    return ( readreg(core.MDMSTAT) & core.MDMSTATUS_BITS )


PUB modulation(md=-2): c | lr_mode, opmode_orig
' Set modulation type
'   Valid values:
'       FSK (0): FSK packet radio mode (POR)
'       OOK (1): OOK packet radio mode
'       LORA (4): LoRa radio mode
'   Any other value polls the chip and returns the current setting
    c := readreg(core.OPMODE)
    opmode_orig := (c & core.MODE_BITS) ' cache user's current opmode
    case md
        FSK, OOK, LORA:                         ' b7..5:
            md <<= core.MODTYPE                 ' lora: 100, ook: 001, fsk: 000
            ' special handling required:
            '   set operating mode to SLEEP (required to change the LORAMODE bit)
            '   OPMODE's regmask is different when already in LoRa mode
            '   some register bits meaning differ in the two modes (LoRa vs FSK/OOK)
            if (c & core.LORAMODE)              ' currently in LoRa mode?
                if (md & core.LORAMODE)         ' requested mode is also LoRa
                    return                      '   - no change, so bail out
                lr_mode := (c & core.MODEL_MASK & core.LORAMODEL_MASK)
                md := (c & core.MODE_MASK & core.LORAMODE_MASK) | md
                writereg(core.OPMODE, lr_mode)
                writereg(core.OPMODE, md)
            else
                md := (c & core.MODE_MASK & core.MODTYPE_LORA_MASK) | md
                writereg(core.OPMODE, md)
            time.usleep(core.T_POR)             ' wait for chip to be ready
            opmode(opmode_orig)                 ' restore user's opmode
        other:
            return (c >> core.MODTYPE) & core.MODTYPE_LORA_BITS


PUB opmode(md=-2): c | modemask
' Set device operating mode
'   Valid values:
'       SLEEPMODE (%000): Sleep
'      *STDBY (%001): Standby
'       FSTX (%010): Frequency synthesis TX
'       TX (%011): Transmit
'       FSRX (%100): Frequency synthesis RX
'       RXCONT (%101): Receive continuous
'       RXSINGLE (%110): Receive single
'       CAD (%111): Channel activity detection
'   Any other value polls the chip and returns the current setting
    c := readreg(core.OPMODE)
    case md
        SLEEPMODE..CAD:
            if (c & core.LORAMODE)
                modemask := core.MODEL_MASK
            else
                modemask := core.MODE_MASK
            md := ( (c & modemask) | md)
            writereg(core.OPMODE, md)
        other:
            return (c & core.MODE_BITS)


PUB over_current_prot(e=-2): c
' Enable over-current protection for PA
'   Valid values:
'      *TRUE (-1 or 1), FALSE (0)
'   Any other value polls the chip and returns the current setting
    c := readreg(core.OCP)
    case abs(e)
        0, 1:
            e := abs(e) << core.OCPON
            e := ((c & core.OCPON_MASK) | e)
            writereg(core.OCP, e)
        other:
            return ( ( (c >> core.OCPON) & 1) == 1)


PUB over_current_trim(t=-2): c
' Se over-current protection trim value, in milliamps
'   Valid values: 45..240mA
'   Any other value polls the chip and returns the current setting
    c := readreg(core.OCP)
    case t
        45..120:
            t := ( (t - 45) / 5)
        130..240:
            t := ( (t - -30) / 10)
        other:
            c := c & core.OCPTRIM
            case c
                0..15:
                    return (45 + (5 * c) )
                16..27:
                    return (-30 + (10 * c) )
                28..31:
                    return 240
            return

    t := ( (c & core.OCPTRIM_MASK) | t)
    writereg(core.OCP, t)


PUB pkt_last_rssi(): l
' RSSI of last packet received, in dBm
    return (-157 + readreg(core.PKTRSSIVALUE) )


PUB pkt_last_snr(): s
' Signal to noise ratio of last packet received, in dB (estimated)
    s := readreg(core.PKTSNRVALUE)
    return (~s / 4)


PUB payld_len_cfg(md=-2): c
' Set payload length configuration/mode
'   Valid values:
'       PKTLEN_VAR (0): Variable-length payload
'       PKTLEN_FIXED (1): Fixed-length payload
'   Any other value polls the chip and returns the current setting
'   NOTE: When using PKTLEN_FIXED, PayloadLength(), CodeRate(), and
'       crc_check_ena() must be configured identically on both
'       TX and RX sides of the radio link.
    c := readreg(core.MDMCFG1)
    case md
        0, 1:
            md := ((c & core.IMPL_HDRMODEON_MASK) | md)
            writereg(core.MDMCFG1, md)
        other:
            return (c & 1)


PUB payld_len(l=-2): c
' Set payload length, in bytes
'   Valid values: 1..255 (LoRa), 1..2047 (FSK/OOK)
'   Any other value polls the chip and returns the current setting
    case modulation()
        LORA:
            if ( lookdown(l: 1..255) )
                writereg(core.LORA_PAYLDLENGTH, l)
            else
                return readreg(core.LORA_PAYLDLENGTH)
        FSK, OOK:
            c := readreg(core.PACKETCFG2, 2)
            if ( lookdown(l: 1..2047) )
                l := ( (c & core.PAYLDLEN_MASK) | l)
                writereg(core.PACKETCFG2, l, 2)
            else
                return (c & core.PAYLDLEN_BITS)


PUB payld_max_len(l=-2): c
' Set payload maximum length, in bytes
'   Valid values: 0..255
'   Any other value polls the chip and returns the current setting
'   NOTE: If header payload length exceeds this value, a header CRC error is generated,
'       allowing filtering of packets with a bad size
    case l
        0..255:
            writereg(core.MAXPAYLDLENGTH, l)
        other:
            return readreg(core.MAXPAYLDLENGTH)


PUB pll_locked(): f
' Return PLL lock status, while attempting a TX, RX, or CAD operation
'   Returns:
'       0: PLL didn't lock
'       1: PLL locked
    f := readreg(core.HOPCHANNEL)
    return ( (f >> core.PLLTIMEOUT) & 1) ^ 1    ' wording/logic of this field
                                                ' is reversed in the datasheet,
                                                ' so invert the bit here


PUB preamble_len(l=-2): c
' Set preamble length, in bits
'   Valid values: 0..65535
'   Any other value polls the chip and returns the current setting
    case l
        0..65535:
            writereg(core.LORA_PREAMBLEMSB, l, 2)
        other:
            return readreg(core.LORA_PREAMBLEMSB)


PUB region(): r
' Get the currently set region of operation
    return _region


PUB reset()
' Perform soft-reset
    if ( lookdown(_RESET: 0..31) )              ' if a valid pin is set,
        outa[_RESET] := 0                       ' pull NRESET low for 100uS,
        dira[_RESET] := 1
        time.usleep(core.T_RESACTIVE)
        dira[_RESET] := 0                       '   then let it float
        time.usleep(core.T_RES)                 ' wait for the chip to be ready


PUB rssi(): r
' Current RSSI, in dBm
    if ( modulation() == LORA )
        return (-157 + readreg(core.LORA_RSSIVALUE) )
    else
        return -(readreg(core.RSSIVALUE) / 2)


PUB rssi_int_thresh(t=-255): c
' Set threshold for triggering RSSI interrupt, in dBm
'   Valid values: -127..0
'   Any other value polls the chip and returns the current setting
    case t
        -127..0:
            t := abs(t) * 2
            writereg(core.RSSITHRESH, t)
        other:
            return -(readreg(core.RSSITHRESH) / 2)


PUB rx_bw(b=-2): c
' Set receive bandwidth, in Hz
'   Valid values: 7800, 10_400, 15_600, 20_800, 31_250, 41_700, 62_500, *125_000, 250_000, 500_000
'   Any other value polls the chip and returns the current setting
'   NOTE: This setting also directly affects occupied RF bandwidth
'       when transmitting
'   NOTE: In the 169MHz band, 250_000 and 500_000 are not supported
    c := readreg(core.MDMCFG1)
    case b
        7800, 10_400, 15_600, 20_800, 31_250, 41_700, 62_500, 125_000, 250_000, 500_000:
            b := lookdownz(b: 7800, 10_400, 15_600, 20_800, 31_250, 41_700, 62_500, 125_000, ...
                                250_000, 500_000) << core.BW
            b := ((c & core.BW_MASK) | b)
            writereg(core.MDMCFG1, b)
        other:
            c := (c >> core.BW)
            return lookupz(c: 7800, 10_400, 15_600, 20_800, 31_250, 41_700, 62_500, ...
                                    125_000, 250_000, 500_000)


PUB rx_mode()
' Change chip state to RX (receive)
    opmode(RXCONT)


PUB rx_ongoing(): r
' Flag indicating modem is in ongoing receive mode
    return ( ( (modem_status() >> core.RX_ONGOING) & 1) == 1)


PUB rx_payld(l, p_dest)
' Receive data from RX FIFO
'   l:      length of data to receive in bytes
'   p_dest: pointer to destination buffer to copy data to
    if ( (l => 1) and (l =< 255) )
        outa[_CS] := 0
            spi.wr_byte(core.FIFO)
            spi.rdblock_msbf(p_dest, l)
        outa[_CS] := 1


PUB rx_timeout(t=-2): c | symbtimeout_msb, symbtimeout_lsb
' Set receive timeout, in symbols
'   Valid values: 0..1023
'   Any other value polls the chip and returns the current setting
    c := readreg(core.MDMCFG2, 2)       ' The top 2 bits of SYMBTIMEOUT are in this reg
    case t                                '   the bottom 8 bits are in the next reg
        0..1023:
            symbtimeout_msb := t >> 8
            symbtimeout_lsb := t & $FF
            c >>= 8
            c &= core.SYMBTIMEOUTMSB_MASK
            c := (c | symbtimeout_msb)
            writereg(core.MDMCFG2, c)
            writereg(core.SYMBTIMEOUTLSB, symbtimeout_lsb)
        other:
            return c & core.SYMBTIMEOUT_BITS


PUB set_region(r)
' Set region of operation
'   r:
'       USA (0):    United States
'       EU868 (1):  Europe, 868MHz
    _region := r


PUB signal_detected(): s
' Flag indicating valid LoRa preamble is detected
    return ( (modem_status() & 1) == 1)


PUB signal_syncd(): s
' Flag indicating end of preamble is detected (modem is in lock)
    return ( ( (modem_status() >> core.SIG_SYNCD) & 1) == 1)


PUB sleep()
' Power down chip
    opmode(SLEEPMODE)


PUB spread_fact(sf=-2): c
' Set spreading factor
'   Valid values: 6, *7, 8, 9, 10, 11, 12
'   Any other value polls the chip and returns the current setting
    c := readreg(core.MDMCFG2)
    case sf
        6..12:
            sf <<= core.SPREADFACT
            sf := ((c & core.SPREADFACT_MASK) | sf)
            writereg(core.MDMCFG2, sf)
        other:
            return (c >> core.SPREADFACT)


PUB set_syncwd(p_src)
' Set LoRa Syncword
'   p_src: pointer to copy syncword data from
    writereg(core.SYNCWORD, long[p_src])


PUB syncwd(p_dest)
' Get current syncword
'   p_dest: pointer to buffer to copy syncword data to
    long[p_dest] := readreg(core.SYNCWORD)


PUB tx_cont(md=-2): c
' Set continuous transmit mode
'   Valid values:
'      *TXMODE_NORMAL (0): Normal mode; a single packet is sent
'       TXMODE_CONT (1): Continuous mode; send multiple packets across the FIFO
'   Any other value polls the chip and returns the current setting
'   NOTE: TXMODE_CONT is used for spectral analysis. Typically, TXMODE_NORMAL
'       should be used
    c := readreg(core.MDMCFG2)
    case md
        TXMODE_NORMAL, TXMODE_CONT:
            md <<= core.TXCONTMODE
            md := ((c & core.TXCONTMODE_MASK) | md)
            writereg(core.MDMCFG2, md)
        other:
            return (c >> core.TXCONTMODE) & 1


PUB tx_mode()
' Change chip state to transmit
    opmode(TX)


PUB tx_payld(l, p_src)
' Queue data to be transmitted in the TX FIFO
'   l:      length of data to transmit (1..255)
'   p_src:  pointer to buffer containing data to transmit
    if ( (l => 1) and (l =< 255) )
        outa[_CS] := 0
            spi.wr_byte(core.FIFO | core.SPI_WR)
            spi.wrblock_msbf(p_src, l)
        outa[_CS] := 1


PUB tx_pwr(p=-255): c | pa_dac
' Set transmit power, in dBm
'   Valid values:
'       -1..14 (when tx_sig_routing() == RFO)
'       5..23 (when tx_sig_routing() == PABOOST)
'   Any other value polls the chip and returns the current setting
    c := readreg(core.PACFG)
    pa_dac := readreg(core.PADAC)
    case _txsig_routing
        RFO:
            case p
                -1..14:
                    c := (7 << core.MAXPWR) | (p + 1)
                other:
                    return (c & core.OUTPUTPWR_BITS) - 1
            writereg(core.PACFG, c)
        PABOOST:
            case p
                5..20:
                    pa_dac := core.PADAC_RSVD_DEF | core.PA_DEF ' preserve the
                21..23:                                         ' reserved bits
                    pa_dac := core.PADAC_RSVD_DEF | core.PA_BOOST
                    p -= 3
                other:
                    case pa_dac & core.PA_DAC_BITS
                        core.PA_DEF:
                            return (c & core.OUTPUTPWR_BITS) + 5
                        core.PA_BOOST:
                            return (c & core.OUTPUTPWR_BITS) + 8
                        other:
                            return pa_dac
                    return
            c := (1 << core.PASELECT) | (p - 5)
            writereg(core.PADAC, pa_dac)
            writereg(core.PACFG, c)
        other:
            return (c & core.OUTPUTPWR_BITS) - 1


PUB tx_sig_routing(p=-2): c
' Set transmit signal output routing
'   Valid values:
'      *RFO (0): Signal routed to RFO pin, max power is +14dBm
'       PABOOST (128): Signal routed to PA_BOOST pin, max power is +23dBm
'   NOTE: This has a direct effect on the maximum output power available
'       using the tx_pwr() method
    case p
        RFO, PABOOST:
            _txsig_routing := p
        other:
            return _txsig_routing


PUB valid_hdrs_recvd(): h
' Number of valid headers received since last transition into receive mode
'   NOTE: To reset counter, set device to SLEEPMODE
    return readreg(core.RXHDRCNTVALUEMSB, 2)


PUB valid_pkts_recvd(): p
' Number of valid packets received since last transition into receive mode
'   NOTE: To reset counter, set device to SLEEPMODE
    return readreg(core.RXPACKETCNTVALUEMSB, 2)


PRI readreg(reg_nr, len=1): val
' Read value(s) from register
    case reg_nr
        $00, $01..$2A, $2C, $2F, $31, $32, $39, $40, $42, $44, $4B, $4D, $5B, $5D, $61..$64, $70:
        other:
            return

    outa[_CS] := 0
        spi.wr_byte(reg_nr)
        spi.rdblock_msbf(@val, len)
    outa[_CS] := 1


PRI writereg(reg_nr, val, len=1)
' Write value(s) to register
    case reg_nr
        $00, $01..$0F, $10..$12, $16, $1D..$24, $26, $27, $2F, $31, $32, $39, $40, $44, $4B, ...
        $4D, $5D, $61..$64, $70:
        other:
            return

    outa[_CS] := 0
        spi.wr_byte(reg_nr | core.SPI_WR)
        spi.wrblock_msbf(@val, len)
    outa[_CS] := 1


DAT
{
Copyright 2025 Jesse Burt

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and
associated documentation files (the "Software"), to deal in the Software without restriction,
including without limitation the rights to use, copy, modify, merge, publish, distribute,
sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or
substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT
NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM,
DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT
OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
}

