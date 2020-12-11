{
    --------------------------------------------
    Filename: wireless.transceiver.sx1276.spi.spin
    Author: Jesse Burt
    Description: Driver for the SEMTECH SX1276
        LoRa/FSK/OOK transceiver
    Copyright (c) 2020
    Started Oct 6, 2019
    Updated Dec 9, 2020
    See end of file for terms of use.
    --------------------------------------------
}

CON

    FXOSC                   = 32_000_000
    TWO_19                  = 1 << 19
    TWO_24                  = 1 << 24
    FPSCALE                 = 10_000_000
    FSTEP                   = 61_0351562  ' (FXOSC / TWO_19) * FPSCALE
' Long-range modes
    LRMODE_FSK_OOK          = 0
    LRMODE_LORA             = 1

' Device modes
    DEVMODE_SLEEP           = %000
    DEVMODE_STDBY           = %001
    DEVMODE_FSTX            = %010
    DEVMODE_TX              = %011
    DEVMODE_FSRX            = %100
    DEVMODE_RXCONT          = %101
    DEVMODE_RXSINGLE        = %110
    DEVMODE_CAD             = %111

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
    PAOUT_RFO               = 0
    PAOUT_PABOOST           = 1 << core#PASELECT

VAR

    long _CS, _SCK, _MOSI, _MISO

OBJ

    spi : "com.spi.4w"
    core: "core.con.sx1276"
    time: "time"
    u64 : "math.unsigned64"
    io  : "io"

PUB Null{}
' This is not a top-level object

PUB Start(CS_PIN, SCK_PIN, MOSI_PIN, MISO_PIN, SCK_DELAY): okay

    if lookdown(CS_PIN: 0..31) and lookdown(SCK_PIN: 0..31) and lookdown(MOSI_PIN: 0..31) and lookdown(MISO_PIN: 0..31)
        if SCK_DELAY => 1
            if okay := spi.start(SCK_DELAY, core#CPOL)
                time.msleep(10)
                longmove(@_CS, @CS_PIN, 4)

                io.high(_CS)
                io.output(_CS)
                if lookdown(deviceid{}: $11, $12)
                    return okay

    return FALSE                                            'If we got here, something went wrong

PUB Stop{}

    spi.stop{}

PUB AGCMode(state): curr_state
' Enable AGC
'   Valid values:
'       TRUE(-1 or 1), *FALSE (0)
'   Any other value polls the chip and returns the current setting
    curr_state := $00
    readreg(core#MDMCFG3, 1, @curr_state)
    case ||(state)
        0, 1:
            state := (||(state) & 1) << core#AGCAUTOON
        other:
            return ((curr_state >> core#AGCAUTOON) & 1) == 1

    state := ((curr_state & core#AGCAUTOON_MASK) | state) & core#MDMCFG3_MASK
    writereg(core#MDMCFG3, 1, @state)

PUB CarrierFreq(freq): curr_freq | opmode_orig
' Set carrier frequency, in Hz
'   Valid values: See case table below
'   Any other value polls the chip and returns the current setting
'   NOTE: The default is 434_000_000
    case freq
        137_000_000..175_000_000, 410_000_000..525_000_000, 862_000_000..1_020_000_000:
            freq := u64.multdiv(freq, FPSCALE, FSTEP)
            opmode_orig := opmode(-2)
            opmode(DEVMODE_STDBY)
            writereg(core#FRFMSB, 3, @freq)
            opmode(opmode_orig)
        other:
            curr_freq := 0
            readreg(core#FRFMSB, 3, @curr_freq)
            return u64.MultDiv (FSTEP, curr_freq, FPSCALE)

PUB Channel(number) | curr_chan
' Set LoRa uplink channel
'   Valid values: 0..63
'   Any other value polls the chip and returns the current setting
'   NOTE: US band plan (915MHz)
    case number
        0..63:
            curr_chan := 902_300_000 + (200_000 * number)
            carrierfreq(curr_chan)
        other:
            curr_chan := carrierfreq(-2)
            return (curr_chan - 902_300_000) / 200_000

PUB ClkOut(divisor): curr_div
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
            result := curr_div & core#CLKOUT_BITS
            return lookupz(result: 1, 2, 4, 8, 16, 32, CLKOUT_RC, CLKOUT_OFF)

    divisor := ((curr_div & core#CLKOUT_MASK) | divisor) & core#OSC_MASK
    writereg(core#OSC, 1, @divisor)

PUB CodeRate(rate): curr_rate
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
            result := (curr_rate >> core#CODERATE) & core#CODERATE_BITS
            return lookup(result: $04_05, $04_06, $04_07, $04_08)

    rate := ((curr_rate & core#CODERATE_MASK) | rate) & core#MDMCFG1_MASK
    writereg(core#MDMCFG1, 1, @rate)

PUB CRCCheckEnabled(state): curr_state
' Enable CRC generation and check on payload
'   Valid values: TRUE (-1 or 1), FALSE (0)
'   Any other value polls the chip and returns the current setting
    curr_state := $00
    readreg(core#MDMCFG2, 1, @curr_state)
    case ||(state)
        0, 1:
            state := ||(state) << core#RXPAYLDCRCON
        other:
            return ((curr_state >> core#RXPAYLDCRCON) & 1) == 1

    state := ((curr_state & core#RXPAYLDCRCON_MASK) | state) & core#MDMCFG2_MASK
    writereg(core#MDMCFG2, 1, @state)

PUB DataRateCorrection(ppm): curr_ppm
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


PUB DeviceID{}: id
' Version code of the chip
'   Returns:
'       Bits 7..4: full revision number
'       Bits 3..0: metal mask revision number
'   Known values: $11, $12
    id := 0
    readreg(core#VERSION, 1, @id)

PUB GPIO0(mode): curr_mode
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

PUB GPIO1(mode): curr_mode
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

PUB GPIO2(mode): curr_mode
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

PUB GPIO3(mode): curr_mode
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

PUB GPIO4(mode): curr_mode
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

PUB GPIO5(mode): curr_mode
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

PUB FreqError{}: ferr | tmp, bw
' Estimated frequency error from modem
    ferr := 0
    readreg(core#FEIMSB, 3, @ferr)
    bw := rxbandwidth(-2)
    ferr := u64.multdiv(ferr, TWO_24, FXOSC)
    return ferr * (bw / 500)

PUB FIFOAddrPointer(ptr): curr_ptr
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

PUB FIFORXBasePtr(addr): curr_addr
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

PUB FIFOTXBasePtr(addr): curr_addr
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

PUB FIFORXCurrentAddr{}: addr
' Start address (in FIFO) of last packet received
'   Returns: Starting address of last packet received
    readreg(core#FIFORXCURRENTADDR, 1, @addr)

PUB FIFORXPointer{}: ptr
' Current value of receive FIFO pointer
'   Returns: Address of last byte written by LoRa receiver
    readreg(core#FIFORXBYTEADDR, 1, @ptr)

PUB FSKRampTime(ramptime): curr_time
' Set Rise/fall time of FSK ramp up/down, in microseconds
'   Valid values: 3400, 2000, 1000, 500, 250, 125, 100, 62, 50, *40, 31, 25, 20, 15, 12, 10
'   Any other value polls the chip and returns the current setting
    case ramptime
        3400, 2000, 1000, 500, 250, 125, 100, 62, 50, 40, 31, 25, 20, 15, 12,{
}       10:
            ramptime := lookdownz(ramptime: 3400, 2000, 1000, 500, 250, 125,{
}           100, 62, 50, 40, 31, 25, 20, 15, 12, 10)
            writereg(core#PARAMP, 1, @ramptime)
        other:
            curr_time := 0
            readreg(core#PARAMP, 1, @curr_time)
            return lookupz(curr_time: 3400, 2000, 1000, 500, 250, 125, 100,{
}           62, 50, 40, 31, 25, 20, 15, 12, 10) & core#PA_RAMP_BITS

PUB HeaderInfoValid{}: flag
' Flag indicating header in received packet is valid (with correct CRC)
'   Returns: TRUE (-1) if header valid, FALSE (0) otherwise
    flag := (((modemstatus{} >> 3) & 1) == 1)

PUB HopChannel{}: curr_chan
' Returns current frequency hopping channel
    readreg(core#HOPCHANNEL, 1, @curr_chan)
    curr_chan &= core#FHSSPRES_CHAN_BITS

PUB HopPeriod(symb_periods): curr_periods
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

PUB Idle{}
' Change chip state to idle (standby)
    opmode(DEVMODE_STDBY)

PUB ImplicitHeaderMode(state): curr_state
' Enable implicit header mode
'   Valid values:
'       TRUE(-1 or 1), *FALSE (0)
'   Any other value polls the chip and returns the current setting
    curr_state := 0
    readreg(core#MDMCFG1, 1, @curr_state)
    case ||(state)
        0, 1:
            state := ||(state) & 1
        other:
            return ((curr_state & 1) == 1)

    state := ((curr_state & core#IMPL_HDRMODEON_MASK) | state) & core#MDMCFG1_MASK
    writereg(core#MDMCFG1, 1, @state)

PUB IntClear(mask)
' Clear interrupt flags
'   Valid values:
'   Bits %76543210
'   Bit 7: Receive timeout
'       6: Receive done
'       5: Payload CRC error
'       4: Valid header
'       3: Transmit done
'       2: CAD done
'       1: FHSS change channel
'       0: CAD detected
'   Any other value is ignored
    case mask
        %0000_0001..%1111_1111:
            writereg(core#IRQFLAGS, 1, @mask)
        other:
            return

PUB Interrupt{}: mask
' Read interrupt flags
'   Returns: Interrupt flags as a mask
'   Bits %76543210
'   Bit 7: Receive timeout
'       6: Receive done
'       5: Payload CRC error
'       4: Valid header
'       3: Transmit done
'       2: CAD done
'       1: FHSS change channel
'       0: CAD detected
    mask := 0
    readreg(core#IRQFLAGS, 1, @mask)

PUB IntMask(mask): curr_mask
' Set interrupt mask
'   Valid values:
'       Set a bit to disable the interrupt flag
'       Bits: 76543210
'       Bit 7: Receive timeout
'           6: Receive done
'           5: Payload CRC error
'           4: Valid header
'           3: Transmit done
'           2: CAD done
'           1: FHSS change channel
'           0: CAD detected
'   Any other value polls the chip and returns the current setting
    case mask
        %0000_0000..%1111_1111:
            writereg(core#IRQFLAGS_MASK, 1, @mask)
        other:
            curr_mask := 0
            readreg(core#IRQFLAGS_MASK, 1, @curr_mask)
            return curr_mask

PUB LastHdrHadCRC{}: flag
' Indicates if last header received with CRC on
'   Returns:
'       FALSE (0): Header indicates CRC is off
'       TRUE (-1): Header indicates CRC is on
    readreg(core#HOPCHANNEL, 1, @flag)
    return (((flag >> core#CRCONPAYLD) & 1) == 1)

PUB LastHdrRate{}: rate
' Coding rate of last header received
'   Returns:
'                   k/n
'       $04_05  =   4/5
'       $04_06  =   4/6
'       $04_07  =   4/7
'       $04_08  =   4/8
    readreg(core#MDMSTAT, 1, @rate)
    rate >>= 5
    return lookup(rate: $04_05, $04_06, $04_07, $04_08)

PUB LastPacketBytes{}: nr_bytes
' Returns number of payload bytes of last packet received
    readreg(core#RXNBBYTES, 1, @nr_bytes)

PUB LNAGain(gain): curr_gain
' Set LNA gain, in dB
'   Valid values: *0 (Maximum gain), -6, -12, -24, -26, -48
'   Any other value polls the chip and returns the current setting
'   NOTE: This setting will have no effect if AGC is enabled
    curr_gain := 0
    readreg(core#LNA, 1, @curr_gain)
    case gain
        0, -6, -12, -24, -26, -48:
            gain := lookdown(gain: 0, -6, -12, -24, -26, -48) << core#LNAGAIN
        other:
            curr_gain := (curr_gain >> core#LNAGAIN) & core#LNAGAIN_BITS
            return lookup(curr_gain: 0, -6, -12, -24, -26, -48)

    gain := ((curr_gain & core#LNAGAIN_MASK) | gain) & core#LNA_MASK
    writereg(core#LNA, 1, @curr_gain)

PUB LongRangeMode(mode): curr_mode
' Set long-range mode
'   Valid values:
'      *LRMODE_FSK_OOK (0): FSK, OOK packet radio mode
'       LRMODE_LORA (1): LoRa radio mode
'   Any other value polls the chip and returns the current setting
'   NOTE: The operating mode will be set to STANDBY (idle) after switching long-range modes
    curr_mode := 0
    readreg(core#OPMODE, 1, @curr_mode)
    case mode
        LRMODE_FSK_OOK, LRMODE_LORA:
            mode := mode << core#LONGRANGEMODE
        other:
            return (curr_mode >> core#LONGRANGEMODE) & 1

    'MODE_MASK: set operating mode to SLEEP (required to change LoRa modes)
    mode := ((curr_mode & core#MODE_MASK & core#LONGRANGEMODE_MASK))
    writereg(core#OPMODE, 1, @mode)

    time.msleep(10)
    opmode(DEVMODE_STDBY)

PUB LowDataRateOptimize(state) | curr_state
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

PUB LowFreqMode(state): curr_state
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

    state := ((curr_state & core#LOWFREQMODEON_MASK) | state) & core#OPMODE_MASK
    writereg(core#OPMODE, 1, @state)

PUB ModemClear{}: flag
' Flag indicating modem clear
    return (((modemstatus{} >> 4) & 1) == 1)

PUB ModemStatus{}: status
' Return modem status bitmask
    readreg(core#MDMSTAT, 1, @status)
    status &= core#MDMSTATUS_BITS

PUB OpMode(mode): curr_mode
' Set device operating mode
'   Valid values:
'       DEVMODE_SLEEP (%000): Sleep
'      *DEVMODE_STDBY (%001): Standby
'       DEVMODE_FSTX (%010): Frequency synthesis TX
'       DEVMODE_TX (%011): Transmit
'       DEVMODE_FSRX (%100): Frequency synthesis RX
'       DEVMODE_RXCONT (%101): Receive continuous
'       DEVMODE_RXSINGLE (%110): Receive single
'       DEVMODE_CAD (%111): Channel activity detection
'   Any other value polls the chip and returns the current setting
    curr_mode := 0
    readreg(core#OPMODE, 1, @curr_mode)
    case mode
        DEVMODE_SLEEP..DEVMODE_CAD:
        other:
            return curr_mode & core#MODE_BITS

    mode := ((curr_mode & core#MODE_MASK) | mode) & core#OPMODE_MASK
    writereg(core#OPMODE, 1, @mode)

PUB OverCurrentProt(state): curr_state
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

PUB OverCurrentTrim(current) | curr_val
' Trim over-current protection, to milliamps
'   Valid values: 45..240mA
'   Any other value polls the chip and returns the current setting
    curr_val := 0
    readreg(core#OCP, 1, @curr_val)
    case current
        45..120:
            current := (current - 45) / 5
        130..240:
            current := (current - -30) / 10
        other:
            curr_val := curr_val & core#OCPTRIM
            case curr_val
                0..15:
                    return 45 + 5 * curr_val
                16..27:
                    return -30 + 10 * curr_val
                28..31:
                    return 240
            return

    current := ((curr_val & core#OCPTRIM_MASK) | current) & core#OCP_MASK
    writereg(core#OCP, 1, @current)

PUB PacketRSSI{}: lrssi
' RSSI of last packet received, in dBm
    readreg(core#PKTRSSIVALUE, 1, @lrssi)
    return (-157 + lrssi)

PUB PacketSNR{}: snr
' Signal to noise ratio of last packet received, in dB (estimated)
    readreg(core#PKTSNRVALUE, 1, @snr)
    if snr & $80
        -snr
    return (snr / 4)

PUB PayloadLength(len): curr_len
' Set payload length, in bytes
'   Valid values: 1..255
'   Any other value polls the chip and returns the current setting
    case len
        1..255:
            writereg(core#LORA_PAYLDLENGTH, 1, @len)
        other:
            curr_len := 0
            readreg(core#LORA_PAYLDLENGTH, 1, @curr_len)
            return curr_len

PUB PayloadMaxLength(len): curr_len
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

PUB PLLLocked{}: flag
' Return PLL lock status, while attempting a TX, RX, or CAD operation
'   Returns:
'       0: PLL didn't lock
'       1: PLL locked
    readreg(core#HOPCHANNEL, 1, @flag)
    return ((flag >> core#PLLTIMEOUT) & 1) ^ 1  ' wording/logic of this field
                                                ' is reversed in the datasheet,
                                                ' so invert the bit here

PUB PreambleLength(length) | curr_len
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

PUB RSSI{}: val
' Current RSSI, in dBm
    val := 0
    readreg(core#LORA_RSSIVALUE, 1, @val)
    return (-157 + val)

PUB RXBandwidth(bw) | curr_bw
' Set receive bandwidth, in Hz
'   Valid values: 7800, 10_400, 15_600, 20_800, 31_250, 41_700, 62_500, *125_000, 250_000, 500_000
'   Any other value polls the chip and returns the current setting
'   NOTE: In the lower band, 250_000 and 500_000 are not supported
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

PUB RXMode{}
' Change chip state to RX (receive)
    opmode(DEVMODE_RXCONT)

PUB RXOngoing{}: flag
' Flag indicating modem is in ongoing receive mode
    return (((modemstatus{} >> 2) & 1) == 1)

PUB RXPayload(nr_bytes, ptr_buff)
' Receive data from RX FIFO into buffer at ptr_buff
'   Valid values: nr_bytes - 1..255
'   Any other value is ignored
    case nr_bytes
        1..255:
            readreg(core#FIFO, nr_bytes, ptr_buff)
        other:
            return

PUB RXTimeout(symbols): curr_symb | symbtimeout_msb, symbtimeout_lsb
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

PUB SignalDetected{}: flag
' Flag indicating signal detected
    return ((modemstatus{} & 1) == 1)

PUB SignalSynchronized{}: flag
' Flag indicating signal synchronized
    return (((modemstatus{} >> 1) & 1) == 1)

PUB Sleep{}
' Power down chip
    opmode(DEVMODE_SLEEP)

PUB SpreadingFactor(cps) | curr_cps
' Set spreading factor rate, in chips per symbol
'   Valid values: 64, *128, 256, 512, 1024, 2048, 4096
'   Any other value polls the chip and returns the current setting
    curr_cps := $00
    readreg(core#MDMCFG2, 1, @curr_cps)
    case cps
        64, 128, 256, 512, 1024, 2048, 4096:
            cps := (lookdown(cps: 64, 128, 256, 512, 1024, 2048, 4096) + 5){
}           << core#SPREADFACT
        other:
            curr_cps := (curr_cps >> core#SPREADFACT)-5
            return lookup(curr_cps: 64, 128, 256, 512, 1024, 2048, 4096)

    cps := ((curr_cps & core#SPREADFACT_MASK) | cps) & core#MDMCFG2_MASK
    writereg(core#MDMCFG2, 1, @cps)

PUB SyncWord(val): curr_val
' Set LoRa Syncword
'   Valid values: $00..$FF
'   Any other value polls the chip and returns the current setting
    case val
        $00..$FF:
            writereg(core#SYNCWORD, 1, @val)
        other:
            curr_val := 0
            readreg(core#SYNCWORD, 1, @curr_val)
            return curr_val

PUB TX{}
' Change chip state to TX (transmit)
    opmode(DEVMODE_TX)

PUB TXMode(mode): curr_mode 'XXX breaks common API - move the mode switch functionality elsewhere
' Set transmit mode
'   Valid values:
'      *TXMODE_NORMAL (0): Normal mode; a single packet is sent
'       TXMODE_CONT (1): Continuous mode; send multiple packets across the FIFO
    curr_mode := 0
    readreg(core#MDMCFG2, 1, @curr_mode)
    case mode
        TXMODE_NORMAL, TXMODE_CONT:
            mode <<= core#TXCONTMODE
        other:
            return (curr_mode >> core#TXCONTMODE) & 1

    mode := ((curr_mode & core#TXCONTMODE_MASK) | mode) & core#MDMCFG2_MASK
    writereg(core#MDMCFG2, 1, @mode)

PUB TXPayload(nr_bytes, ptr_buff)
' Queue data to be transmitted in the TX FIFO
'   nr_bytes Valid values: 1..255
'   Any other value is ignored
    case nr_bytes
        1..255:
            writereg(core#FIFO, nr_bytes, ptr_buff)
        other:
            return

PUB TXPower(pwr, outpin): curr_pwr | pa_dac  'XXX 2nd param breaks common API - move elsewhere
' Set transmit power, in dBm
'   Valid values:
'       outpin:
'           PAOUT_RFO (0): Signal routed to RFO pin, max power is +14dBm
'               pwr: -1..14
'           PAOUT_PABOOST (128): Signal routed to PA_BOOST pin, max power is +23dBm
'               pwr: 5..23
'   Any other value polls the chip and returns the current setting
    curr_pwr := pa_dac := 0
    readreg(core#PACFG, 1, @curr_pwr)
    readreg(core#PADAC, 1, @pa_dac)
    case outpin
        PAOUT_RFO:
            case pwr
                -1..14:
                    curr_pwr := (7 << core#MAXPWR) | (pwr + 1)
                other:
                    return (curr_pwr & core#OUTPUTPWR_BITS) - 1

            writereg(core#PACFG, 1, @curr_pwr)

        PAOUT_PABOOST:
            case pwr
                5..20:
                    pa_dac := ($10 << core#PADAC_RSVD) | %100

                21..23:
                    pa_dac := ($10 << core#PADAC_RSVD) | %111
                    pwr -= 3

                other:
                    case pa_dac & %111
                        %100:
                            return (curr_pwr & core#OUTPUTPWR_BITS) + 5
                        %111:
                            return (curr_pwr & core#OUTPUTPWR_BITS) + 8
                        other:
                            return pa_dac
                    return

            curr_pwr := (1 << core#PASELECT) | (pwr - 5)
            writereg(core#PADAC, 1, @pa_dac)
            writereg(core#PACFG, 1, @curr_pwr)

        other:
            return (curr_pwr & core#OUTPUTPWR_BITS) - 1

PUB ValidHeadersReceived{}: nr_hdrs
' Returns number of valid headers received since last transition into receive mode
'   NOTE: To reset counter, set device to DEVMODE_SLEEP
    readreg(core#RXHDRCNTVALUEMSB, 2, @nr_hdrs)

PUB ValidPacketsReceived{}: nr_pkts
' Returns number of valid packets received since last transition into receive mode
'   NOTE: To reset counter, set device to DEVMODE_SLEEP
    readreg(core#RXPACKETCNTVALUEMSB, 2, @nr_pkts)

PRI readReg(reg, nr_bytes, ptr_buff) | tmp
' Read nr_bytes from device into ptr_buff
    case reg
        $00, $01, $06..$2A, $2C, $2F, $39, $40, $42, $44, $4B, $4D, $5B, $5D,{
}       $61..$64, $70:
        other:
            return

    io.low(_CS)
    spi.shiftout(_MOSI, _SCK, core#MOSI_BITORDER, 8, reg)

    repeat tmp from nr_bytes-1 to 0
        byte[ptr_buff][tmp] := spi.shiftin(_MISO, _SCK, core#MISO_BITORDER, 8)

    io.high(_CS)

PRI writeReg(reg, nr_bytes, ptr_buff) | tmp
' Write nr_bytes from ptr_buff to device
    case reg
        $00, $01, $06..$0F, $11, $12, $16, $1D..$24, $26, $27, $2F, $39, $40,{
}       $44, $4B, $4D, $5D, $61..$64, $70:
        other:
            return

    io.low(_CS)
    spi.shiftout(_MOSI, _SCK, core#MOSI_BITORDER, 8, reg | core#WRITE)

    repeat tmp from nr_bytes-1 to 0
        spi.shiftout(_MOSI, _SCK, core#MOSI_BITORDER, 8, byte[ptr_buff][tmp])

    io.high(_CS)

DAT
{
    --------------------------------------------------------------------------------------------------------
    TERMS OF USE: MIT License

    Permission is hereby granted, free of charge, to any person obtaining a copy of this software and
    associated documentation files (the "Software"), to deal in the Software without restriction, including
    without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
    copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the
    following conditions:

    The above copyright notice and this permission notice shall be included in all copies or substantial
    portions of the Software.

    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT
    LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
    IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
    WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
    SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
    --------------------------------------------------------------------------------------------------------
}
