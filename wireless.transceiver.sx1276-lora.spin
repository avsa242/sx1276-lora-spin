{
    --------------------------------------------
    Filename: wireless.transceiver.sx1276.spin
    Author: Jesse Burt
    Description: Driver for the SEMTECH SX1276 LoRa/FSK/OOK transceiver (LoRa mode)
    Copyright (c) 2022
    Started Oct 6, 2019
    Updated Dec 17, 2022
    See end of file for terms of use.
    --------------------------------------------
}

CON

    FXOSC                   = 32_000_000
    TWO_19                  = 1 << 19
    TWO_24                  = 1 << 24
    FPSCALE                 = 10_000_000        ' scaling factor used in math
    FSTEP                   = 61_0351562        ' (FXOSC / TWO_19) * FPSCALE

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
    PABOOST                 = 1 << core#PASELECT

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

OBJ

    spi : "com.spi.1mhz"
    core: "core.con.sx1276"
    time: "time"
    u64 : "math.unsigned64"

PUB null{}
' This is not a top-level object

PUB startx(CS_PIN, SCK_PIN, MOSI_PIN, MISO_PIN, RESET_PIN): status
' Start using custom I/O settings
    if (lookdown(CS_PIN: 0..31) and lookdown(SCK_PIN: 0..31) and lookdown(MOSI_PIN: 0..31) {
}      and lookdown(MISO_PIN: 0..31))
        if (status := spi.init(SCK_PIN, MOSI_PIN, MISO_PIN, core#SPI_MODE))
            time.usleep(core#T_POR)
            _CS := CS_PIN
            _RESET := RESET_PIN
            outa[_CS] := 1
            dira[_CS] := 1
            reset{}
            if (lookdown(dev_id{}: $11, $12))
                return
    ' if this point is reached, something above failed
    ' Double check I/O pin assignments, connections, power
    ' Lastly - make sure you have at least one free core/cog
    return FALSE

PUB stop{}
' Stop the driver
    spi.deinit{}
    longfill(@_CS, 0, 3)

PUB defaults{}
' Set factory defaults
    reset{}

PUB preset_lora{}
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

PUB preset_dr0{}
' Physical bitrate (Rb) 980
    preset_lora{}
    spread_fact(10)
'    rx_bw(125_000)

PUB preset_dr1{}
' Physical bitrate (Rb) 1760
    preset_lora{}
    spread_fact(9)
'    rx_bw(125_000)

PUB preset_dr2{}
' Physical bitrate (Rb) 3125
    preset_lora{}
    spread_fact(8)
'    rx_bw(125_000)

PUB preset_dr3{}
' Physical bitrate (Rb) 5470
    preset_lora{}
'    spread_fact(7)
'    rx_bw(125_000)

PUB preset_dr4{}
' Physical bitrate (Rb) 12500
    preset_lora{}
    spread_fact(8)
'    rx_bw(125_000)

PUB preset_dr8{}
' Physical bitrate (Rb) 980
    preset_lora{}
    spread_fact(12)
    rx_bw(500_000)

PUB preset_dr9{}
' Physical bitrate (Rb) 1760
    preset_lora{}
    spread_fact(11)
    rx_bw(500_000)

PUB preset_dr10{}
' Physical bitrate (Rb) 3900
    preset_lora{}
    spread_fact(10)
    rx_bw(500_000)

PUB preset_dr11{}
' Physical bitrate (Rb) 7000
    preset_lora{}
    spread_fact(9)
    rx_bw(500_000)

PUB preset_dr12{}
'  Physical bitrate (Rb) 12500
    preset_lora{}
    spread_fact(8)
    rx_bw(500_000)

PUB preset_dr13{}
' Physical bitrate (Rb) 21900
    preset_lora{}
'    spread_fact(7)
    rx_bw(500_000)

PUB agc_mode(state): curr_state
' Enable AGC
'   Valid values:
'       TRUE(-1 or 1), *FALSE (0)
'   Any other value polls the chip and returns the current setting
    curr_state := 0
    readreg(core#MDMCFG3, 1, @curr_state)
    case ||(state)
        0, 1:
            state := (||(state) & 1) << core#AGCAUTOON
        other:
            return ((curr_state >> core#AGCAUTOON) & 1) == 1

    state := ((curr_state & core#AGCAUTOON_MASK) | state) & core#MDMCFG3_MASK
    writereg(core#MDMCFG3, 1, @state)

PUB carrier_freq(freq): curr_freq | opmode_orig
' Set carrier frequency, in Hz
'   Valid values: See case table below
'   Any other value polls the chip and returns the current setting
'   NOTE: The default is 434_000_000
    opmode_orig := 0
    case freq
        137_000_000..175_000_000, 410_000_000..525_000_000, 862_000_000..1_020_000_000:
            freq := u64.multdiv(freq, FPSCALE, FSTEP)
            opmode_orig := opmode(-2)
            opmode(STDBY)
            writereg(core#FRFMSB, 3, @freq)
            opmode(opmode_orig)
        other:
            curr_freq := 0
            readreg(core#FRFMSB, 3, @curr_freq)
            return u64.multdiv(FSTEP, curr_freq, FPSCALE)

PUB channel(number): curr_chan
' Set LoRa uplink channel
'   Valid values: 0..63
'   Any other value polls the chip and returns the current setting
'   NOTE: US band plan (915MHz)
    case number
        0..63:
            number := 902_300_000 + (200_000 * number)
            carrier_freq(number)
        other:
            curr_chan := carrier_freq(-2)
            return (curr_chan - 902_300_000) / 200_000

PUB clk_out(divisor): curr_div
' Set clkout frequency, as a divisor of FXOSC
'   Valid values:
'       1, 2, 4, 8, 16, 32, CLKOUT_RC (6), CLKOUT_OFF (7)
'   Any other value polls the chip and returns the current setting
'   NOTE: For optimal efficiency, it is recommended to disable the clock output (CLKOUT_OFF)
'       unless needed
    curr_div := 0
    readreg(core#OSC, 1, @curr_div)
    case divisor
        1, 2, 4, 8, 16, 32, CLKOUT_RC, CLKOUT_OFF:
            divisor := lookdownz(divisor: 1, 2, 4, 8, 16, 32, CLKOUT_RC, CLKOUT_OFF)
        other:
            curr_div &= core#CLKOUT_BITS
            return lookupz(curr_div: 1, 2, 4, 8, 16, 32, CLKOUT_RC, CLKOUT_OFF)

    divisor := ((curr_div & core#CLKOUT_MASK) | divisor) & core#OSC_MASK
    writereg(core#OSC, 1, @divisor)

PUB code_rate(rate): curr_rate
' Set Error code rate
'   Valid values:
'                   k/n
'      *$04_05  =   4/5
'       $04_06  =   4/6
'       $04_07  =   4/7
'       $04_08  =   4/8
'   Any other value polls the chip and returns the current setting
    curr_rate := 0
    readreg(core#MDMCFG1, 1, @curr_rate)
    case rate
        $04_05..$04_08:
            rate := lookdown(rate: $04_05, $04_06, $04_07, $04_08) << core#CODERATE
        other:
            curr_rate := (curr_rate >> core#CODERATE) & core#CODERATE_BITS
            return lookup(curr_rate: $04_05, $04_06, $04_07, $04_08)

    rate := ((curr_rate & core#CODERATE_MASK) | rate) & core#MDMCFG1_MASK
    writereg(core#MDMCFG1, 1, @rate)

PUB crc_check_ena(state): curr_state
' Enable CRC generation and check on payload
'   Valid values: TRUE (-1 or 1), FALSE (0)
'   Any other value polls the chip and returns the current setting
    curr_state := 0
    readreg(core#MDMCFG2, 1, @curr_state)
    case ||(state)
        0, 1:
            state := ||(state) << core#RXPAYLDCRCON
        other:
            return ((curr_state >> core#RXPAYLDCRCON) & 1) == 1

    state := ((curr_state & core#RXPAYLDCRCON_MASK) | state) & core#MDMCFG2_MASK
    writereg(core#MDMCFG2, 1, @state)

PUB data_rate_offset(ppm): curr_ppm
' Set data rate offset value used in conjunction with AFC, in ppm
'   Valid values: 0..255
'   Any other value polls the chip and returns the current setting
    case ppm
        0..255:
            writereg(core#PPMCORRECTION, 1, @ppm)
        other:
            curr_ppm := 0
            readreg(core#PPMCORRECTION, 1, @curr_ppm)
            return curr_ppm

PUB dev_id{}: id
' Version code of the chip
'   Returns:
'       Bits 7..4: full revision number
'       Bits 3..0: metal mask revision number
'   Known values: $11, $12
    id := 0
    readreg(core#VERSION, 1, @id)

PUB fifo_addr_ptr(ptr): curr_ptr    'XXX needs clarification
' Set SPI interface address pointer in FIFO data buffer
'   Valid values: $00..$FF
'   Any other value polls the chip and returns the current setting
    case ptr
        $00..$FF:
            writereg(core#FIFOADDRPTR, 1, @ptr)
        other:
            curr_ptr := 0
            readreg(core#FIFOADDRPTR, 1, @curr_ptr)
            return

PUB fifo_rx_base_ptr(addr): curr_addr
' Set start address within FIFO for received data
'   Valid values: $00..$FF
'   Any other value polls the chip and returns the current setting
    case addr
        $00..$FF:
            writereg(core#FIFORXBASEADDR, 1, @addr)
        other:
            curr_addr := 0
            readreg(core#FIFORXBASEADDR, 1, @curr_addr)
            return

PUB fifo_rx_current_addr{}: addr
' Start address (in FIFO) of last packet received
'   Returns: Starting address of last packet received
    addr := 0
    readreg(core#FIFORXCURRENTADDR, 1, @addr)

PUB fifo_rx_ptr{}: ptr
' Current value of receive FIFO pointer
'   Returns: Address of last byte written by LoRa receiver
    ptr := 0
    readreg(core#FIFORXBYTEADDR, 1, @ptr)

PUB fifo_tx_base_ptr(addr): curr_addr
' Set start address within FIFO for transmitted data
'   Valid values: $00..$FF
'   Any other value polls the chip and returns the current setting
    case addr
        $00..$FF:
            writereg(core#FIFOTXBASEADDR, 1, @addr)
        other:
            curr_addr := 0
            readreg(core#FIFOTXBASEADDR, 1, @curr_addr)
            return

PUB gpio0(mode): curr_mode
' Assert DIO0 pin on set mode
'   Valid values:
'       DIO0_RXDONE (0) - Packet reception complete
'       DIO0_TXDONE (64) - FIFO payload transmission complete
'       DIO0_CADDONE (128) - Channel Activity Detected
    curr_mode := 0
    readreg(core#DIOMAP1, 1, @curr_mode)
    case mode
        DIO0_RXDONE, DIO0_TXDONE, DIO0_CADDONE:
            mode <<= core#DIO0MAP
        other:
            return (curr_mode >> core#DIO0MAP) & %11

    mode := ((curr_mode & core#DIO0MAP_MASK) | mode) & core#DIOMAP1_MASK
    writereg(core#DIOMAP1, 1, @mode)

PUB gpio1(mode): curr_mode
' Assert DIO1 pin on set mode
'   Valid values:
'       DIO1_RXTIMEOUT (0) - Packet reception timed out
'       DIO1_FHSSCHANGECHANNEL (64) - FHSS Changed channel
'       DIO1_CADDETECTED (128) - Channel Activity Detected
    curr_mode := 0
    readreg(core#DIOMAP1, 1, @curr_mode)
    case mode
        DIO1_RXTIMEOUT, DIO1_FHSSCHANGECHANNEL, DIO1_CADDETECTED:
            mode <<= core#DIO1MAP
        other:
            return (curr_mode >> core#DIO1MAP) & %11

    mode := ((curr_mode & core#DIO1MAP_MASK) | mode) & core#DIOMAP1_MASK
    writereg(core#DIOMAP1, 1, @mode)

PUB gpio2(mode): curr_mode
' Assert DIO2 pin on set mode
'   Valid values:
'       DIO2_FHSSCHANGECHANNEL (0) - FHSS Changed channel
'       DIO2_FHSSCHANGECHANNEL (64) - FHSS Changed channel
'       DIO2_FHSSCHANGECHANNEL (128) - FHSS Changed channel
    curr_mode := 0
    readreg(core#DIOMAP1, 1, @curr_mode)
    case mode
        DIO2_FHSSCHANGECHANNEL, DIO2_SYNCADDRESS:
            mode <<= core#DIO2MAP

        other:
            return (curr_mode >> core#DIO2MAP) & %11

    mode := ((curr_mode & core#DIO2MAP_MASK) | mode) & core#DIOMAP1_MASK
    writereg(core#DIOMAP1, 1, @mode)

PUB gpio3(mode): curr_mode
' Assert DIO3 pin on set mode
'   Valid values:
'       DIO3_CADDONE (0) - Channel Activity Detection complete
'       DIO3_VALIDHDR (64) - Valider header received in RX mode
'       DIO3_PAYLDCRCERROR (128) - CRC error in received payload
    curr_mode := 0
    readreg(core#DIOMAP1, 1, @curr_mode)
    case mode
        DIO3_CADDONE, DIO3_VALIDHDR, DIO3_PAYLDCRCERROR:
            mode <<= core#DIO3MAP
        other:
            return curr_mode & %11

    mode := ((curr_mode & core#DIO3MAP_MASK) | mode) & core#DIOMAP1_MASK
    writereg(core#DIOMAP1, 1, @mode)

PUB gpio4(mode): curr_mode
' Assert DIO4 pin on set mode
'   Valid values:
'       DIO4_CADDETECTED (0) - Channel Activity Detected
'       DIO4_PLLLOCK (64) - PLL Locked
'       DIO4_PLLLOCK (128) - PLL Locked
    curr_mode := 0
    readreg(core#DIOMAP2, 1, @curr_mode)
    case mode
        DIO4_CADDETECTED, DIO4_PLLLOCK:
            mode <<= core#DIO4MAP
        other:
            return (curr_mode >> core#DIO4MAP) & %11

    mode := ((curr_mode & core#DIO4MAP_MASK) | mode) & core#DIOMAP2_MASK
    writereg(core#DIOMAP2, 1, @mode)

PUB gpio5(mode): curr_mode
' Assert DIO5 pin on set mode
'   Valid values:
'       DIO5_MODEREADY (0) - Requested operation mode is ready
'       DIO5_CLKOUT (64) - Output system clock
'       DIO5_CLKOUT (128) - Output system clock
    curr_mode := 0
    readreg(core#DIOMAP2, 1, @curr_mode)
    case mode
        DIO5_MODEREADY, DIO5_CLKOUT:
            mode <<= core#DIO5MAP
        other:
            return (curr_mode >> core#DIO5MAP) & %11

    mode := ((curr_mode & core#DIO5MAP_MASK) | mode) & core#DIOMAP2_MASK
    writereg(core#DIOMAP2, 1, @mode)

PUB hdr_info_valid{}: flag
' Flag indicating header in received packet is valid (with correct CRC)
'   Returns: TRUE (-1) if header valid, FALSE (0) otherwise
    return (((modem_status{} >> core#HDR_VALID) & 1) == 1)

PUB hop_channel{}: curr_chan
' Returns current frequency hopping channel
    readreg(core#HOPCHANNEL, 1, @curr_chan)
    curr_chan &= core#FHSSPRES_CHAN_BITS

PUB hop_period(symb_periods): curr_periods
' Set symbol periods between frequency hops
'   Valid values: 0..255
'   Any other value polls the chip and returns the current setting
'   NOTE: The first hop always occurs after the first header symbol
'   NOTE: 0 effectively disables hopping
    case symb_periods
        0..255:
            writereg(core#HOPPERIOD, 1, @symb_periods)
        other:
            curr_periods := 0
            readreg(core#HOPPERIOD, 1, @curr_periods)
            return curr_periods

PUB idle{}
' Change chip state to idle (standby)
    opmode(STDBY)

PUB int_clear(mask)
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
    mask &= $ff
    writereg(core#IRQFLAGS, 1, @mask)

PUB interrupt{}: mask
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
    mask := 0
    readreg(core#IRQFLAGS, 1, @mask)

PUB int_mask(mask): curr_mask
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
    case mask
        %0000_0000..%1111_1111:
            { flip bits so '1' enables interrupt, '0' clears }
            mask := ((mask & $ff) ^ $ff)
            writereg(core#IRQFLAGS_MASK, 1, @mask)
        other:
            curr_mask := 0
            readreg(core#IRQFLAGS_MASK, 1, @curr_mask)
            return (curr_mask ^ $FF)

PUB last_hdr_had_crc{}: flag
' Flag indicating last header was received with CRC on
'   Returns:
'       FALSE (0): Header indicates CRC is off
'       TRUE (-1): Header indicates CRC is on
    readreg(core#HOPCHANNEL, 1, @flag)
    return (((flag >> core#CRCONPAYLD) & 1) == 1)

PUB last_hdr_rate{}: rate
' Coding rate of last header received
'   Returns:
'                   k/n
'       $04_05  =   4/5
'       $04_06  =   4/6
'       $04_07  =   4/7
'       $04_08  =   4/8
    readreg(core#MDMSTAT, 1, @rate)
    rate >>= core#RXCODERATE
    return lookup(rate: $04_05, $04_06, $04_07, $04_08)

PUB last_pkt_len{}: nr_bytes
' Number of payload bytes of last packet received
    nr_bytes := 0
    readreg(core#RXNBBYTES, 1, @nr_bytes)

PUB lna_gain(gain): curr_gain
' Set LNA gain, in dB
'   Valid values: *0 (Maximum gain), -6, -12, -24, -36, -48
'   Any other value polls the chip and returns the current setting
'   NOTE: This setting will have no effect if AGC is enabled
'   NOTE: If the AGC is enabled, reading the current setting will return the current LNA gain
'       as determined by the AGC, not necessarily what had been previously set
    curr_gain := 0
    readreg(core#LNA, 1, @curr_gain)
    case gain
        0, -6, -12, -24, -36, -48:
            gain := lookdown(gain: 0, -6, -12, -24, -36, -48) << core#LNAGAIN
        other:
            curr_gain := (curr_gain >> core#LNAGAIN) & core#LNAGAIN_BITS
            return lookup(curr_gain: 0, -6, -12, -24, -36, -48)

    gain := ((curr_gain & core#LNAGAIN_MASK) | gain) & core#LNA_MASK
    writereg(core#LNA, 1, @curr_gain)

PUB low_data_rate_optimize(state): curr_state
' Optimize for low data rates
'   Valid values:
'       TRUE (-1 or 1), FALSE (0)
'   Any other value polls the chip and returns the current setting
'   NOTE: This setting is mandated when the symbol length exceeds 16ms
    curr_state := 0
    readreg(core#MDMCFG3, 1, @curr_state)
    case ||(state)
        0, 1:
            state := ||(state) << core#LOWDRATEOPT
        other:
            return ((curr_state >> core#LOWDRATEOPT) & 1) == 1

    state := ((curr_state & core#LOWDRATEOPT_MASK) | state) & core#MDMCFG3_MASK
    writereg(core#MDMCFG3, 1, @state)

PUB low_freq_mode(state): curr_state | lfmask
' Enable Low frequency-specific register access
'   Valid values:
'       TRUE (-1 or 1), FALSE (0)
'   Any other value polls the chip and returns the current setting
    curr_state := 0
    readreg(core#OPMODE, 1, @curr_state)
    case ||(state)
        0, 1:
            state := (||(state) << core#LOWFREQMODEON)
        other:
            return ((curr_state >> core#LOWFREQMODEON) & 1) == 1

    if (curr_state & core#LORAMODE)
        lfmask := core#LOWFREQMODEONL_MASK
    else
        lfmask := core#LOWFREQMODEONL_MASK
    state := ((curr_state & LFMASK) | state)
    writereg(core#OPMODE, 1, @state)

PUB modem_clear{}: flag
' Flag indicating modem is clear
    return (((modem_status{} >> core#MDM_CLR) & 1) == 1)

PUB modem_status{}: status
' Get modem status
'   Bits: 4..0
'       4: modem clear
'       3: header info valid
'       2: RX on-going
'       1: signal synchronized
'       0: signal detected
    readreg(core#MDMSTAT, 1, @status)
    status &= core#MDMSTATUS_BITS

PUB modulation(mode): curr_mode | lr_mode, opmode_orig
' Set modulation type
'   Valid values:
'       FSK (0): FSK packet radio mode (POR)
'       OOK (1): OOK packet radio mode
'       LORA (4): LoRa radio mode
'   Any other value polls the chip and returns the current setting
    curr_mode := 0
    readreg(core#OPMODE, 1, @curr_mode)
    opmode_orig := (curr_mode & core#MODE_BITS) ' cache user's current opmode
    case mode
        FSK, OOK, LORA:                         ' b7..5:
            mode <<= core#MODTYPE               ' lora: 100, ook: 001, fsk: 000
        other:
            return (curr_mode >> core#MODTYPE) & core#MODTYPE_LORA_BITS

    ' special handling required:
    '   set operating mode to SLEEP (required to change the LORAMODE bit)
    '   OPMODE's regmask is different when already in LoRa mode
    '   some register bits meaning differ in the two modes (LoRa vs FSK/OOK)
    if (curr_mode & core#LORAMODE)              ' currently in LoRa mode?
        if (mode & core#LORAMODE)               ' requested mode is also LoRa
            return                              '   - no change, so bail out
        lr_mode := (curr_mode & core#MODEL_MASK & core#LORAMODEL_MASK)
        mode := (curr_mode & core#MODE_MASK & core#LORAMODE_MASK) | mode
        writereg(core#OPMODE, 1, @lr_mode)
        writereg(core#OPMODE, 1, @mode)
    else
        mode := (curr_mode & core#MODE_MASK & core#MODTYPE_LORA_MASK) | mode
        writereg(core#OPMODE, 1, @mode)

    time.usleep(core#T_POR)                     ' wait for chip to be ready
    opmode(opmode_orig)                         ' restore user's opmode

PUB opmode(mode): curr_mode | modemask
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
    curr_mode := 0
    readreg(core#OPMODE, 1, @curr_mode)
    case mode
        SLEEPMODE..CAD:
        other:
            return curr_mode & core#MODE_BITS

    if (curr_mode & core#LORAMODE)
        modemask := core#MODEL_MASK
    else
        modemask := core#MODE_MASK
    mode := ((curr_mode & modemask) | mode)
    writereg(core#OPMODE, 1, @mode)

PUB over_current_prot(state): curr_state
' Enable over-current protection for PA
'   Valid values:
'      *TRUE (-1 or 1), FALSE (0)
'   Any other value polls the chip and returns the current setting
    curr_state := 0
    readreg(core#OCP, 1, @curr_state)
    case ||(state)
        0, 1:
            state := ||(state) << core#OCPON
        other:
            return (((curr_state >> core#OCPON) & 1) == 1)

    state := ((curr_state & core#OCPON_MASK) | state) & core#OCP_MASK
    writereg(core#OCP, 1, @state)

PUB over_current_trim(current): curr_val
' Se over-current protection trim value, in milliamps
'   Valid values: 45..240mA
'   Any other value polls the chip and returns the current setting
    curr_val := 0
    readreg(core#OCP, 1, @curr_val)
    case current
        45..120:
            current := ((current - 45) / 5)
        130..240:
            current := ((current - -30) / 10)
        other:
            curr_val := curr_val & core#OCPTRIM
            case curr_val
                0..15:
                    return (45 + (5 * curr_val))
                16..27:
                    return (-30 + (10 * curr_val))
                28..31:
                    return 240
            return

    current := ((curr_val & core#OCPTRIM_MASK) | current) & core#OCP_MASK
    writereg(core#OCP, 1, @current)

PUB pkt_last_rssi{}: lrssi
' RSSI of last packet received, in dBm
    readreg(core#PKTRSSIVALUE, 1, @lrssi)
    return (-157 + lrssi)

PUB pkt_last_snr{}: snr
' Signal to noise ratio of last packet received, in dB (estimated)
    readreg(core#PKTSNRVALUE, 1, @snr)
    return (~snr / 4)

PUB payld_len_cfg(mode): curr_mode
' Set payload length configuration/mode
'   Valid values:
'       PKTLEN_VAR (0): Variable-length payload
'       PKTLEN_FIXED (1): Fixed-length payload
'   Any other value polls the chip and returns the current setting
'   NOTE: When using PKTLEN_FIXED, PayloadLength(), CodeRate(), and
'       CRCCheckEnabled() must be configured identically on both
'       TX and RX sides of the radio link.
    curr_mode := 0
    readreg(core#MDMCFG1, 1, @curr_mode)
    case mode
        0, 1:
        other:
            return (curr_mode & 1)

    mode := ((curr_mode & core#IMPL_HDRMODEON_MASK) | mode) & core#MDMCFG1_MASK
    writereg(core#MDMCFG1, 1, @mode)

PUB payld_len(len): curr_len
' Set payload length, in bytes
'   Valid values: 1..255 (LoRa), 1..2047 (FSK/OOK)
'   Any other value polls the chip and returns the current setting
    case modulation(-2)
        LORA:
            if lookdown(len: 1..255)
                writereg(core#LORA_PAYLDLENGTH, 1, @len)
            else
                curr_len := 0
                readreg(core#LORA_PAYLDLENGTH, 1, @curr_len)
                return
        FSK, OOK:
            curr_len := 0
            readreg(core#PACKETCFG2, 2, @curr_len)
            if lookdown(len: 1..2047)
                len := ((curr_len & core#PAYLDLEN_MASK) | len)
                writereg(core#PACKETCFG2, 2, @len)
            else
                return (curr_len & core#PAYLDLEN_BITS)

PUB payld_max_len(len): curr_len
' Set payload maximum length, in bytes
'   Valid values: 0..255
'   Any other value polls the chip and returns the current setting
'   NOTE: If header payload length exceeds this value, a header CRC error is generated,
'       allowing filtering of packets with a bad size
    case len
        0..255:
            writereg(core#MAXPAYLDLENGTH, 1, @len)
        other:
            curr_len := 0
            readreg(core#MAXPAYLDLENGTH, 1, @curr_len)
            return curr_len

PUB pll_locked{}: flag
' Return PLL lock status, while attempting a TX, RX, or CAD operation
'   Returns:
'       0: PLL didn't lock
'       1: PLL locked
    readreg(core#HOPCHANNEL, 1, @flag)
    return ((flag >> core#PLLTIMEOUT) & 1) ^ 1  ' wording/logic of this field
                                                ' is reversed in the datasheet,
                                                ' so invert the bit here

PUB preamble_len(length):  curr_len
' Set preamble length, in bits
'   Valid values: 0..65535
'   Any other value polls the chip and returns the current setting
    case length
        0..65535:
            writereg(core#LORA_PREAMBLEMSB, 2, @length)
        other:
            curr_len := 0
            readreg(core#LORA_PREAMBLEMSB, 2, @curr_len)
            return curr_len

PUB reset{}
' Perform soft-reset
    if lookdown(_RESET: 0..31)                  ' if a valid pin is set,
        outa[_RESET] := 0                       ' pull NRESET low for 100uS,
        dira[_RESET] := 1
        time.usleep(core#T_RESACTIVE)
        dira[_RESET] := 0                       '   then let it float
        time.usleep(core#T_RES)                 ' wait for the chip to be ready

PUB rssi{}: val
' Current RSSI, in dBm
    val := 0
    if modulation(-2) == LORA
        readreg(core#LORA_RSSIVALUE, 1, @val)
        return (-157 + val)
    else
        readreg(core#RSSIVALUE, 1, @val)
        return -(val / 2)

PUB rssi_int_thresh(thresh): curr_thr
' Set threshold for triggering RSSI interrupt, in dBm
'   Valid values: -127..0
'   Any other value polls the chip and returns the current setting
    case thresh
        -127..0:
            thresh := ||(thresh) * 2
            writereg(core#RSSITHRESH, 1, @thresh)
        other:
            curr_thr := 0
            readreg(core#RSSITHRESH, 1, @curr_thr)
            return -(curr_thr / 2)

PUB rx_bw(bw): curr_bw
' Set receive bandwidth, in Hz
'   Valid values: 7800, 10_400, 15_600, 20_800, 31_250, 41_700, 62_500, *125_000, 250_000, 500_000
'   Any other value polls the chip and returns the current setting
'   NOTE: This setting also directly affects occupied RF bandwidth
'       when transmitting
'   NOTE: In the 169MHz band, 250_000 and 500_000 are not supported
    curr_bw := 0
    readreg(core#MDMCFG1, 1, @curr_bw)
    case bw
        7800, 10_400, 15_600, 20_800, 31_250, 41_700, 62_500, 125_000,{
}       250_000, 500_000:
            bw := lookdownz(bw: 7800, 10_400, 15_600, 20_800, 31_250, {
}           41_700, 62_500, 125_000, 250_000, 500_000) << core#BW
        other:
            curr_bw := (curr_bw >> core#BW)
            return lookupz(curr_bw: 7800, 10_400, 15_600, 20_800, 31_250,{
}           41_700, 62_500, 125_000, 250_000, 500_000)

    bw := ((curr_bw & core#BW_MASK) | bw) & core#MDMCFG1_MASK
    writereg(core#MDMCFG1, 1, @bw)

PUB rx_mode{}
' Change chip state to RX (receive)
    opmode(RXCONT)

PUB rx_ongoing{}: flag
' Flag indicating modem is in ongoing receive mode
    return (((modem_status{} >> core#RX_ONGOING) & 1) == 1)

PUB rx_payld(nr_bytes, ptr_buff)
' Receive data from RX FIFO into buffer at ptr_buff
'   Valid values: nr_bytes - 1..255
'   Any other value is ignored
    case nr_bytes
        1..255:
            readreg(core#FIFO, nr_bytes, ptr_buff)
        other:
            return

PUB rx_timeout(symbols): curr_symb | symbtimeout_msb, symbtimeout_lsb
' Set receive timeout, in symbols
'   Valid values: 0..1023
'   Any other value polls the chip and returns the current setting
    curr_symb := 0
    readreg(core#MDMCFG2, 2, @curr_symb) ' The top 2 bits of SYMBTIMEOUT are in this reg
    case symbols                        '   the bottom 8 bits are in the next reg
        0..1023:
            symbtimeout_msb := symbols >> 8
            symbtimeout_lsb := symbols & $FF
        other:
            return curr_symb & core#SYMBTIMEOUT_BITS

    curr_symb >>= 8
    curr_symb &= core#SYMBTIMEOUTMSB_MASK
    curr_symb := (curr_symb | symbtimeout_msb) & core#MDMCFG2_MASK
    writereg(core#MDMCFG2, 1, @curr_symb)
    writereg(core#SYMBTIMEOUTLSB, 1, @symbtimeout_lsb)

PUB signal_detected{}: flag
' Flag indicating valid LoRa preamble is detected
    return ((modem_status{} & 1) == 1)

PUB signal_syncd{}: flag
' Flag indicating end of preamble is detected (modem is in lock)
    return (((modem_status{} >> core#SIG_SYNCD) & 1) == 1)

PUB sleep{}
' Power down chip
    opmode(SLEEPMODE)

PUB spread_fact(sf): curr_sf
' Set spreading factor
'   Valid values: 6, *7, 8, 9, 10, 11, 12
'   Any other value polls the chip and returns the current setting
    curr_sf := 0
    readreg(core#MDMCFG2, 1, @curr_sf)
    case sf
        6..12:
            sf <<= core#SPREADFACT
        other:
            return (curr_sf >> core#SPREADFACT)

    sf := ((curr_sf & core#SPREADFACT_MASK) | sf) & core#MDMCFG2_MASK
    writereg(core#MDMCFG2, 1, @sf)

PUB set_syncwd(ptr_syncwd)
' Set LoRa Syncword
'   ptr_syncwd: pointer to copy syncword data from
    writereg(core#SYNCWORD, 1, ptr_syncwd)

PUB syncwd(val): ptr_syncwd
' Get current syncword
'   ptr_syncwd: pointer to copy syncword data to
    readreg(core#SYNCWORD, 1, ptr_syncwd)

PUB tx_cont(state): curr_state
' Set continuous transmit mode
'   Valid values:
'      *TXMODE_NORMAL (0): Normal mode; a single packet is sent
'       TXMODE_CONT (1): Continuous mode; send multiple packets across the FIFO
'   Any other value polls the chip and returns the current setting
'   NOTE: TXMODE_CONT is used for spectral analysis. Typically, TXMODE_NORMAL
'       should be used
    curr_state := 0
    readreg(core#MDMCFG2, 1, @curr_state)
    case state
        TXMODE_NORMAL, TXMODE_CONT:
            state <<= core#TXCONTMODE
        other:
            return (curr_state >> core#TXCONTMODE) & 1

    state := ((curr_state & core#TXCONTMODE_MASK) | state) & core#MDMCFG2_MASK
    writereg(core#MDMCFG2, 1, @state)

PUB tx_mode{}
' Change chip state to transmit
    opmode(TX)

PUB tx_payld(nr_bytes, ptr_buff)
' Queue data to be transmitted in the TX FIFO
'   nr_bytes Valid values: 1..255
'   Any other value is ignored
    case nr_bytes
        1..255:
            writereg(core#FIFO, nr_bytes, ptr_buff)
        other:
            return

PUB tx_pwr(pwr): curr_pwr | pa_dac
' Set transmit power, in dBm
'   Valid values:
'       -1..14 (when TXSigRouting() == RFO)
'       5..23 (when TXSigRouting() == PABOOST)
'   Any other value polls the chip and returns the current setting
    curr_pwr := pa_dac := 0
    readreg(core#PACFG, 1, @curr_pwr)
    readreg(core#PADAC, 1, @pa_dac)
    case _txsig_routing
        RFO:
            case pwr
                -1..14:
                    curr_pwr := (7 << core#MAXPWR) | (pwr + 1)
                other:
                    return (curr_pwr & core#OUTPUTPWR_BITS) - 1
            writereg(core#PACFG, 1, @curr_pwr)
        PABOOST:
            case pwr
                5..20:
                    pa_dac := core#PADAC_RSVD_DEF | core#PA_DEF ' preserve the
                21..23:                                         ' reserved bits
                    pa_dac := core#PADAC_RSVD_DEF | core#PA_BOOST
                    pwr -= 3
                other:
                    case pa_dac & core#PA_DAC_BITS
                        core#PA_DEF:
                            return (curr_pwr & core#OUTPUTPWR_BITS) + 5
                        core#PA_BOOST:
                            return (curr_pwr & core#OUTPUTPWR_BITS) + 8
                        other:
                            return pa_dac
                    return
            curr_pwr := (1 << core#PASELECT) | (pwr - 5)
            writereg(core#PADAC, 1, @pa_dac)
            writereg(core#PACFG, 1, @curr_pwr)
        other:
            return (curr_pwr & core#OUTPUTPWR_BITS) - 1

PUB tx_sig_routing(pin): curr_pin
' Set transmit signal output routing
'   Valid values:
'      *RFO (0): Signal routed to RFO pin, max power is +14dBm
'       PABOOST (128): Signal routed to PA_BOOST pin, max power is +23dBm
'   NOTE: This has a direct effect on the maximum output power available
'       using the TXPower() method
    case pin
        RFO, PABOOST:
            _txsig_routing := pin
        other:
            return _txsig_routing

PUB valid_hdrs_recvd{}: nr_hdrs
' Number of valid headers received since last transition into receive mode
'   NOTE: To reset counter, set device to SLEEPMODE
    readreg(core#RXHDRCNTVALUEMSB, 2, @nr_hdrs)

PUB valid_pkts_recvd{}: nr_pkts
' Number of valid packets received since last transition into receive mode
'   NOTE: To reset counter, set device to SLEEPMODE
    readreg(core#RXPACKETCNTVALUEMSB, 2, @nr_pkts)

PRI readreg(reg_nr, nr_bytes, ptr_buff) | tmp
' Read nr_bytes from device into ptr_buff
    case reg_nr
        $00, $01..$2A, $2C, $2F, $31, $32, $39, $40, $42, $44, $4B, {
}       $4D, $5B, $5D, $61..$64, $70:
        other:
            return

    outa[_CS] := 0
    spi.wr_byte(reg_nr)
    spi.rdblock_msbf(ptr_buff, nr_bytes)
    outa[_CS] := 1

PRI writereg(reg_nr, nr_bytes, ptr_buff) | tmp
' Write nr_bytes from ptr_buff to device
    case reg_nr
        $00, $01..$0F, $10, $12, $16, $1D..$24, $26, $27, $2F, $31, {
}       $32, $39, $40, $44, $4B, $4D, $5D, $61..$64, $70:
        other:
            return

    outa[_CS] := 0
    spi.wr_byte(reg_nr | core#SPI_WR)
    spi.wrblock_msbf(ptr_buff, nr_bytes)
    outa[_CS] := 1

DAT
{
Copyright 2022 Jesse Burt

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

