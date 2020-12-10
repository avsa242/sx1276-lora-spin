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

PUB AGCMode(enabled) | tmp
' Enable AGC
'   Valid values:
'       TRUE(-1 or 1), *FALSE (0)
'   Any other value polls the chip and returns the current setting
    tmp := $00
    readReg(core#MDMCFG3, 1, @tmp)
    case ||enabled
        0, 1:
            enabled := (||enabled & %1) << core#AGCAUTOON
        OTHER:
            return ((tmp >> core#AGCAUTOON) & %1) * TRUE

    tmp &= core#AGCAUTOON_MASK
    tmp := (tmp | enabled) & core#MDMCFG3_MASK
    writeReg(core#MDMCFG3, 1, @tmp)

PUB CarrierFreq(freq) | tmp, opmode_tmp
' Set carrier frequency, in Hz
'   Valid values: See case table below
'   Any other value polls the chip and returns the current setting
'   NOTE: The default is 434_000_000
    tmp := $00_00_00
    readReg(core#FRFMSB, 3, @tmp)
    case freq
        137_000_000..175_000_000, 410_000_000..525_000_000, 862_000_000..1_020_000_000:
            freq := u64.MultDiv (freq, FPSCALE, FSTEP)
        OTHER:
            return u64.MultDiv (FSTEP, tmp, FPSCALE)

    opmode_tmp := OpMode (-2)
    OpMode (DEVMODE_STDBY)
    writeReg(core#FRFMSB, 3, @freq)
    OpMode (opmode_tmp)

PUB Channel(number) | tmp
' Set LoRa uplink channel
'   Valid values: 0..63
'   Any other value polls the chip and returns the current setting
'   NOTE: US band plan (915MHz)
    case number
        0..63:
            tmp := 902_300_000 + (200_000 * number)
            CarrierFreq(tmp)
        OTHER:
            tmp := CarrierFreq(-2)
            return (tmp - 902_300_000) / 200_000

PUB ClkOut(divisor) | tmp
' Set clkout frequency, as a divisor of FXOSC
'   Valid values:
'       1, 2, 4, 8, 16, 32, CLKOUT_RC (6), CLKOUT_OFF (7)
'   Any other value polls the chip and returns the current setting
'   NOTE: For optimal efficiency, it is recommended to disable the clock output (CLKOUT_OFF)
'       unless needed
    tmp := $00
    readReg(core#OSC, 1, @tmp)
    case divisor
        1, 2, 4, 8, 16, 32, CLKOUT_RC, CLKOUT_OFF:
            divisor := lookdownz(divisor: 1, 2, 4, 8, 16, 32, CLKOUT_RC, CLKOUT_OFF)
        OTHER:
            result := tmp & core#CLKOUT_BITS
            return lookupz(result: 1, 2, 4, 8, 16, 32, CLKOUT_RC, CLKOUT_OFF)

    tmp &= core#CLKOUT_MASK
    tmp := (tmp | divisor) & core#OSC_MASK
    writeReg(core#OSC, 1, @tmp)

PUB CodeRate(rate) | tmp
' Set Error code rate
'   Valid values:
'                   k/n
'      *$04_05  =   4/5
'       $04_06  =   4/6
'       $04_07  =   4/7
'       $04_08  =   4/8
'   Any other value polls the chip and returns the current setting
    tmp := $00
    readReg(core#MDMCFG1, 1, @tmp)
    case rate
        $04_05..$04_08:
            rate := lookdown(rate: $04_05, $04_06, $04_07, $04_08) << core#CODERATE
        OTHER:
            result := (tmp >> core#CODERATE) & core#CODERATE_BITS
            return lookup(result: $04_05, $04_06, $04_07, $04_08)

    tmp &= core#CODERATE_MASK
    tmp := (tmp | rate) & core#MDMCFG1_MASK
    writeReg(core#MDMCFG1, 1, @tmp)

PUB CRCCheckEnabled(enabled) | tmp
' Enable CRC generation and check on payload
'   Valid values: TRUE (-1 or 1), FALSE (0)
'   Any other value polls the chip and returns the current setting
    tmp := $00
    readReg(core#MDMCFG2, 1, @tmp)
    case ||enabled
        0, 1:
            enabled := ||enabled << core#RXPAYLDCRCON
        OTHER:
            return ((tmp >> core#RXPAYLDCRCON) & %1) * TRUE

    tmp &= core#RXPAYLDCRCON_MASK
    tmp := (tmp | enabled) & core#MDMCFG2_MASK
    writeReg(core#MDMCFG2, 1, @tmp)

PUB DataRateCorrection(ppm) | tmp
' Set data rate offset value used in conjunction with AFC, in ppm
'   Valid values: 0..255
'   Any other value polls the chip and returns the current setting
    tmp := $00
    readReg(core#PPMCORRECTION, 1, @tmp)
    case ppm
        0..255:
        OTHER:
            return tmp

    writeReg(core#PPMCORRECTION, 1, @ppm)

PUB DeviceID
' Version code of the chip
'   Returns:
'       Bits 7..4: full revision number
'       Bits 3..0: metal mask revision number
'   Known values: $11, $12
    result := $00
    readReg(core#VERSION, 1, @result)

PUB GPIO0(mode) | tmp
' Assert DIO0 pin on set mode
'   Valid values:
'       DIO0_RXDONE (0) - Packet reception complete
'       DIO0_TXDONE (64) - FIFO payload transmission complete
'       DIO0_CADDONE (128) - Channel Activity Detected
    tmp := $00
    readReg(core#DIOMAP1, 1, @tmp)
    case mode
        DIO0_RXDONE, DIO0_TXDONE, DIO0_CADDONE:
            mode <<= core#DIO0MAP
        OTHER:
            return (tmp >> core#DIO0MAP) & %11

    tmp &= core#DIO0MAP_MASK
    tmp := (tmp | mode) & core#DIOMAP1_MASK
    writeReg(core#DIOMAP1, 1, @tmp)

PUB GPIO1(mode) | tmp
' Assert DIO1 pin on set mode
'   Valid values:
'       DIO1_RXTIMEOUT (0) - Packet reception timed out
'       DIO1_FHSSCHANGECHANNEL (64) - FHSS Changed channel
'       DIO1_CADDETECTED (128) - Channel Activity Detected
    tmp := $00
    readReg(core#DIOMAP1, 1, @tmp)
    case mode
        DIO1_RXTIMEOUT, DIO1_FHSSCHANGECHANNEL, DIO1_CADDETECTED:
            mode <<= core#DIO1MAP
        OTHER:
            return (tmp >> core#DIO1MAP) & %11

    tmp &= core#DIO1MAP_MASK
    tmp := (tmp | mode) & core#DIOMAP1_MASK
    writeReg(core#DIOMAP1, 1, @tmp)

PUB GPIO2(mode) | tmp
' Assert DIO2 pin on set mode
'   Valid values:
'       DIO2_FHSSCHANGECHANNEL (0) - FHSS Changed channel
'       DIO2_FHSSCHANGECHANNEL (64) - FHSS Changed channel
'       DIO2_FHSSCHANGECHANNEL (128) - FHSS Changed channel
    tmp := $00
    readReg(core#DIOMAP1, 1, @tmp)
    case mode
        DIO2_FHSSCHANGECHANNEL, DIO2_SYNCADDRESS:
            mode <<= core#DIO2MAP

        OTHER:
            return (tmp >> core#DIO2MAP) & %11

    tmp &= core#DIO2MAP_MASK
    tmp := (tmp | mode) & core#DIOMAP1_MASK
    writeReg(core#DIOMAP1, 1, @tmp)

PUB GPIO3(mode) | tmp
' Assert DIO3 pin on set mode
'   Valid values:
'       DIO3_CADDONE (0) - Channel Activity Detection complete
'       DIO3_VALIDHDR (64) - Valider header received in RX mode
'       DIO3_PAYLDCRCERROR (128) - CRC error in received payload
    tmp := $00
    readReg(core#DIOMAP1, 1, @tmp)
    case mode
        DIO3_CADDONE, DIO3_VALIDHDR, DIO3_PAYLDCRCERROR:
            mode <<= core#DIO3MAP
        OTHER:
            return tmp & %11

    tmp &= core#DIO3MAP_MASK
    tmp := (tmp | mode) & core#DIOMAP1_MASK
    writeReg(core#DIOMAP1, 1, @tmp)

PUB GPIO4(mode) | tmp
' Assert DIO4 pin on set mode
'   Valid values:
'       DIO4_CADDETECTED (0) - Channel Activity Detected
'       DIO4_PLLLOCK (64) - PLL Locked
'       DIO4_PLLLOCK (128) - PLL Locked
    tmp := $00
    readReg(core#DIOMAP2, 1, @tmp)
    case mode
        DIO4_CADDETECTED, DIO4_PLLLOCK:
            mode <<= core#DIO4MAP
        OTHER:
            return (tmp >> core#DIO4MAP) & %11

    tmp &= core#DIO4MAP_MASK
    tmp := (tmp | mode) & core#DIOMAP2_MASK
    writeReg(core#DIOMAP2, 1, @tmp)

PUB GPIO5(mode) | tmp
' Assert DIO5 pin on set mode
'   Valid values:
'       DIO5_MODEREADY (0) - Requested operation mode is ready
'       DIO5_CLKOUT (64) - Output system clock
'       DIO5_CLKOUT (128) - Output system clock
    readReg(core#DIOMAP2, 1, @tmp)
    case mode
        DIO5_MODEREADY, DIO5_CLKOUT:
            mode <<= core#DIO5MAP
        OTHER:
            return (tmp >> core#DIO5MAP) & %11

    tmp &= core#DIO5MAP_MASK
    tmp := (tmp | mode) & core#DIOMAP2_MASK
    writeReg(core#DIOMAP2, 1, @tmp)

PUB FreqError | tmp, bw
' Estimated frequency error from modem
    tmp := $0_00_00
    readReg(core#FEIMSB, 3, @tmp)
    bw := RXBandwidth (-2)
    result := u64.MultDiv (tmp, TWO_24, FXOSC)
    return result * (bw / 500)

PUB FIFOAddrPointer(fifo_ptr) | tmp
' Set SPI interface address pointer in FIFO data buffer
'   Valid values: $00..$FF
'   Any other value polls the chip and returns the current setting
    tmp := $00
    readReg(core#FIFOADDRPTR, 1, @tmp)
    case fifo_ptr
        $00..$FF:
        OTHER:
            return tmp

    writeReg(core#FIFOADDRPTR, 1, @fifo_ptr)

PUB FIFORXBasePtr(addr) | tmp
' Set start address within FIFO for received data
'   Valid values: $00..$FF
'   Any other value polls the chip and returns the current setting
    tmp := $00
    readReg(core#FIFORXBASEADDR, 1, @tmp)
    case addr
        $00..$FF:
        OTHER:
            return tmp

    writeReg(core#FIFORXBASEADDR, 1, @addr)

PUB FIFOTXBasePtr(addr) | tmp
' Set start address within FIFO for transmitted data
'   Valid values: $00..$FF
'   Any other value polls the chip and returns the current setting
    tmp := $00
    readReg(core#FIFOTXBASEADDR, 1, @tmp)
    case addr
        $00..$FF:
        OTHER:
            return tmp

    writeReg(core#FIFOTXBASEADDR, 1, @addr)

PUB FIFORXCurrentAddr
' Start address (in FIFO) of last packet received
'   Returns: Starting address of last packet received
    readReg(core#FIFORXCURRENTADDR, 1, @result)

PUB FIFORXPointer
' Current value of receive FIFO pointer
'   Returns: Address of last byte written by LoRa receiver
    readReg(core#FIFORXBYTEADDR, 1, @result)

PUB FSKRampTime(uSec) | tmp
' Set Rise/fall time of FSK ramp up/down, in microseconds
'   Valid values: 3400, 2000, 1000, 500, 250, 125, 100, 62, 50, *40, 31, 25, 20, 15, 12, 10
'   Any other value polls the chip and returns the current setting
    tmp := $00
    readReg(core#PARAMP, 1, @tmp)
    case uSec
        3400, 2000, 1000, 500, 250, 125, 100, 62, 50, 40, 31, 25, 20, 15, 12, 10:
            uSec := lookdownz(uSec: 3400, 2000, 1000, 500, 250, 125, 100, 62, 50, 40, 31, 25, 20, 15, 12, 10)
        OTHER:
            return lookupz(tmp: 3400, 2000, 1000, 500, 250, 125, 100, 62, 50, 40, 31, 25, 20, 15, 12, 10) & core#PA_RAMP_BITS

    writeReg(core#PARAMP, 1, @uSec)

PUB HeaderInfoValid

    result := ((ModemStatus >> 3) & %1) * TRUE

PUB HopChannel
' Returns current frequency hopping channel
    readReg(core#HOPCHANNEL, 1, @result)
    result &= core#FHSSPRES_CHAN_BITS

PUB HopPeriod(symb_periods) | tmp
' Set symbol periods between frequency hops
'   Valid values: 0..255
'   Any other value polls the chip and returns the current setting
'   NOTE: The first hop always occurs after the first header symbol
'   NOTE: 0 effectively disables hopping
    tmp := $00
    readReg(core#HOPPERIOD, 1, @tmp)
    case symb_periods
        0..255:
        OTHER:
            return tmp

    writeReg(core#HOPPERIOD, 1, @symb_periods)

PUB Idle
' Change chip state to idle (standby)
    OpMode(DEVMODE_STDBY)

PUB ImplicitHeaderMode(enabled) | tmp
' Enable implicit header mode
'   Valid values:
'       TRUE(-1 or 1), *FALSE (0)
'   Any other value polls the chip and returns the current setting
    tmp := $00
    readReg(core#MDMCFG1, 1, @tmp)
    case ||enabled
        0, 1:
            enabled := ||enabled & %1
        OTHER:
            return (tmp & %1) * TRUE

    tmp &= core#IMPL_HDRMODEON_MASK
    tmp := (tmp | enabled) & core#MDMCFG1_MASK
    writeReg(core#MDMCFG1, 1, @tmp)

PUB Interrupt(clear_mask)
' Read or clear interrupt flags
'   Returns: Interrupt flags as a mask
'   Bits set are asserted
'   Set bits to clear the corresponding interrupt flags
'   Bits %76543210
'   Bit 7: Receive timeout
'       6: Receive done
'       5: Payload CRC error
'       4: Valid header
'       3: Transmit done
'       2: CAD done
'       1: FHSS change channel
'       0: CAD detected
    result := $00
    readReg(core#IRQFLAGS, 1, @result)
    case clear_mask
        %0000_0001..%1111_1111:
            writeReg(core#IRQFLAGS, 1, @clear_mask)
        OTHER:
            return

PUB IntMask(mask) | tmp
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
    tmp := $00
    readReg(core#IRQFLAGS_MASK, 1, @tmp)
    case mask
        0..255:
        OTHER:
            return tmp

    writeReg(core#IRQFLAGS_MASK, 1, @mask)

PUB LastHeaderCodingRate
' Returns coding rate of last header received
    readReg(core#MDMSTAT, 1, @result)
    result >>= 5
    result := lookup(result: $0405, $0406, $0407, $0408)

PUB LastHeaderCRC
' Indicates if last header received with CRC on
'   Returns:
'       0: Header indicates CRC is off
'       1: Header indicates CRC is on
    readReg(core#HOPCHANNEL, 1, @result)
    result := (result >> core#CRCONPAYLD) & %1

PUB LastPacketBytes
' Returns number of payload bytes of last packet received
    readReg(core#RXNBBYTES, 1, @result)

PUB LNAGain(dB) | tmp
' Set LNA gain, in dB
'   Valid values: *0 (Maximum gain), -6, -12, -24, -26, -48
'   Any other value polls the chip and returns the current setting
'   NOTE: This setting will have no effect if AGC is enabled
    tmp := $00
    readReg(core#LNA, 1, @tmp)
    case dB
        0, -6, -12, -24, -26, -48:
            dB := lookdown(dB: 0, -6, -12, -24, -26, -48) << core#LNAGAIN
        OTHER:
            result := (tmp >> core#LNAGAIN) & core#LNAGAIN_BITS
            return lookup(result: 0, -6, -12, -24, -26, -48)

    tmp &= core#LNAGAIN_MASK
    tmp := (tmp | dB) & core#LNA_MASK
    writeReg(core#LNA, 1, @tmp)

PUB LongRangeMode(mode) | tmp
' Set long-range mode
'   Valid values:
'      *LRMODE_FSK_OOK (0): FSK, OOK packet radio mode
'       LRMODE_LORA (1): LoRa radio mode
'   Any other value polls the chip and returns the current setting
'   NOTE: The operating mode will be set to STANDBY (idle) after switching long-range modes
    tmp := $00
    readReg(core#OPMODE, 1, @tmp)
    case mode
        LRMODE_FSK_OOK, LRMODE_LORA:
            mode := mode << core#LONGRANGEMODE
        OTHER:
            return (tmp >> core#LONGRANGEMODE) & %1

    tmp &= core#MODE_MASK                   ' Set operating mode to SLEEP
    tmp &= core#LONGRANGEMODE_MASK
    tmp := (tmp | mode) & core#OPMODE_MASK
    writeReg(core#OPMODE, 1, @tmp)

    time.MSleep(10)
    OpMode(DEVMODE_STDBY)

PUB LowDataRateOptimize(enabled) | tmp
' Optimize for low data rates
'   Valid values:
'       TRUE (-1 or 1), FALSE (0)
'   Any other value polls the chip and returns the current setting
'   NOTE: This setting is mandated when the symbol length exceeds 16ms
    tmp := $00
    readReg(core#MDMCFG3, 1, @tmp)
    case ||enabled
        0, 1:
            enabled := ||enabled << core#LOWDRATEOPT
        OTHER:
            return ((tmp >> core#LOWDRATEOPT) & %1) * TRUE

    tmp &= core#LOWDRATEOPT_MASK
    tmp := (tmp | enabled) & core#MDMCFG3_MASK
    writeReg(core#MDMCFG3, 1, @tmp)

PUB LowFreqMode(enabled) | tmp
' Enable Low frequency-specific register access
'   Valid values:
'       TRUE (-1 or 1), FALSE (0)
'   Any other value polls the chip and returns the current setting
    tmp := $00
    readReg(core#OPMODE, 1, @tmp)
    case ||enabled
        0, 1:
            enabled := (||enabled << core#LOWFREQMODEON)
        OTHER:
            return ((tmp >> core#LOWFREQMODEON) & %1) * TRUE

    tmp &= core#LOWFREQMODEON_MASK
    tmp := (tmp | enabled) & core#OPMODE_MASK
    writeReg(core#OPMODE, 1, @tmp)

PUB ModemClear
' Return modem clear status
    result := ((ModemStatus >> 4) & %1) * TRUE

PUB ModemStatus
' Return modem status bitmask
    readReg(core#MDMSTAT, 1, @result)
    result &= core#MDMSTATUS_BITS

PUB OpMode(mode) | tmp
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
    tmp := $00
    readReg(core#OPMODE, 1, @tmp)
    case mode
        DEVMODE_SLEEP..DEVMODE_CAD:
        OTHER:
            return tmp & core#MODE_BITS

    tmp &= core#MODE_MASK
    tmp := (tmp | mode) & core#OPMODE_MASK
    writeReg(core#OPMODE, 1, @tmp)

PUB OverCurrentProt(enabled) | tmp
' Enable over-current protection for PA
'   Valid values:
'      *TRUE (-1 or 1), FALSE (0)
'   Any other value polls the chip and returns the current setting
    tmp := $00
    readReg(core#OCP, 1, @tmp)
    case ||enabled
        0, 1:
            enabled := ||enabled << core#OCPON
        OTHER:
            return ((tmp >> core#OCPON) & %1) * TRUE

    tmp &= core#OCPON_MASK
    tmp := (tmp | enabled) & core#OCP_MASK
    writeReg(core#OCP, 1, @tmp)

PUB OverCurrentTrim(mA) | tmp
' Trim over-current protection, to milliamps
'   Valid values: 45..240mA
'   Any other value polls the chip and returns the current setting
    tmp := $00
    readReg(core#OCP, 1, @tmp)
    case mA
        45..120:
            mA := (mA - 45) / 5
        130..240:
            mA := (mA - -30) / 10
        OTHER:
            result := tmp & core#OCPTRIM
            case result
                0..15:
                    return 45 + 5 * result
                16..27:
                    return -30 + 10 * result
                28..31:
                    return 240
            return

    tmp &= core#OCPTRIM_MASK
    tmp := (tmp | mA) & core#OCP_MASK
    writeReg(core#OCP, 1, @tmp)

PUB PacketRSSI
' RSSI of last packet received, in dBm
    readReg(core#PKTRSSIVALUE, 1, @result)
    result := -157 + result

PUB PacketSNR
' Signal to noise ratio of last packet received, in dB (estimated)
    readReg(core#PKTSNRVALUE, 1, @result)
    if result & $80
        -result
    result := result / 4

PUB PayloadLength(len) | tmp
' Set payload length, in bytes
'   Valid values: 1..255
'   Any other value polls the chip and returns the current setting
    tmp := $00
    readReg(core#LORA_PAYLDLENGTH, 1, @tmp)
    case len
        1..255:
        OTHER:
            return tmp

    writeReg(core#LORA_PAYLDLENGTH, 1, @len)

PUB PayloadMaxLength(len) | tmp
' Set payload maximum length, in bytes
'   Valid values: 0..255
'   Any other value polls the chip and returns the current setting
'   NOTE: If header payload length exceeds this value, a header CRC error is generated,
'       allowing filtering of packets with a bad size
    tmp := $00
    readReg(core#MAXPAYLDLENGTH, 1, @tmp)
    case len
        0..255:
        OTHER:
            return tmp

    writeReg(core#MAXPAYLDLENGTH, 1, @len)

PUB PLLLocked
' Return PLL lock status, while attempting a TX, RX, or CAD operation
'   Returns:
'       0: PLL didn't lock
'       1: PLL locked
    readReg(core#HOPCHANNEL, 1, @result)
    result := result >> core#PLLTIMEOUT
    result &= %1
    result ^= %1

PUB PreambleLength(bits) | tmp
' Set preamble length, in bits
'   Valid values: 0..65535
'   Any other value polls the chip and returns the current setting
    tmp := $00
    readReg(core#LORA_PREAMBLEMSB, 2, @tmp)
    case bits
        0..65535:
        OTHER:
            return tmp

    writeReg(core#LORA_PREAMBLEMSB, 2, @bits)

PUB RSSI
' Current RSSI, in dBm
    result := $00
    readReg(core#LORA_RSSIVALUE, 1, @result)
    result := -157 + result

PUB RXBandwidth(Hz) | tmp
' Set receive bandwidth, in Hz
'   Valid values: 7800, 10_400, 15_600, 20_800, 31_250, 41_700, 62_500, *125_000, 250_000, 500_000
'   Any other value polls the chip and returns the current setting
'   NOTE: In the lower band, 250_000 and 500_000 are not supported
    tmp := $00
    readReg(core#MDMCFG1, 1, @tmp)
    case Hz
        7800, 10_400, 15_600, 20_800, 31_250, 41_700, 62_500, 125_000, 250_000, 500_000:
            Hz := lookdownz(Hz: 7800, 10_400, 15_600, 20_800, 31_250, 41_700, 62_500, 125_000, 250_000, 500_000) << core#BW
        OTHER:
            result := (tmp >> core#BW)
            return lookupz(result: 7800, 10_400, 15_600, 20_800, 31_250, 41_700, 62_500, 125_000, 250_000, 500_000)
    tmp &= core#BW_MASK
    tmp := (tmp | Hz) & core#MDMCFG1_MASK
    writeReg(core#MDMCFG1, 1, @tmp)

PUB RXMode
' Change chip state to RX (receive)
    OpMode(DEVMODE_RXCONT)

PUB RXOngoing
' Return receive on-going status
    result := ((ModemStatus >> 2) & %1) * TRUE

PUB RXPayload(nr_bytes, buff_addr)
' Receive data from RX FIFO into buffer at buff_addr
'   Valid values: nr_bytes - 1..255
'   Any other value is ignored
    case nr_bytes
        1..255:
            readReg(core#FIFO, nr_bytes, buff_addr)
        OTHER:
            return FALSE

PUB RXTimeout(symbols) | tmp, symbtimeout_msb, symbtimeout_lsb
' Set receive timeout, in symbols
'   Valid values: 0..1023
'   Any other value polls the chip and returns the current setting
    tmp := $00
    readReg(core#MDMCFG2, 2, @tmp) ' The top 2 bits of SYMBTIMEOUT are in this reg
    case symbols                        '   the bottom 8 bits are in the next reg
        0..1023:
            symbtimeout_msb := symbols >> 8
            symbtimeout_lsb := symbols & $FF
        OTHER:
            return tmp & core#SYMBTIMEOUT_BITS

    tmp >>= 8
    tmp &= core#SYMBTIMEOUTMSB_MASK
    tmp := (tmp | symbtimeout_msb) & core#MDMCFG2_MASK
    writeReg(core#MDMCFG2, 1, @tmp)
    writeReg(core#SYMBTIMEOUTLSB, 1, @symbtimeout_lsb)

PUB SignalDetected
' Return signal detected
    result := (ModemStatus & %1) * TRUE

PUB SignalSynchronized
' Return signal synchronized
    result := ((ModemStatus >> 1) & %1) * TRUE

PUB Sleep
' Power down chip
    OpMode(DEVMODE_SLEEP)

PUB SpreadingFactor(chips_sym) | tmp
' Set spreading factor rate, in chips per symbol
'   Valid values: 64, *128, 256, 512, 1024, 2048, 4096
'   Any other value polls the chip and returns the current setting
    tmp := $00
    readReg(core#MDMCFG2, 1, @tmp)
    case chips_sym
        64, 128, 256, 512, 1024, 2048, 4096:
            chips_sym := (lookdown(chips_sym: 64, 128, 256, 512, 1024, 2048, 4096) + 5) << core#SPREADFACT
        OTHER:
            result := (tmp >> core#SPREADFACT)-5
            return lookup(result: 64, 128, 256, 512, 1024, 2048, 4096)

    tmp &= core#SPREADFACT_MASK
    tmp := (tmp | chips_sym) & core#MDMCFG2_MASK
    writeReg(core#MDMCFG2, 1, @tmp)

PUB SyncWord(val) | tmp
' Set LoRa Syncword
'   Valid values: $00..$FF
'   Any other value polls the chip and returns the current setting
    tmp := $00
    readReg(core#SYNCWORD, 1, @tmp)
    case val
        $00..$FF:
        OTHER:
            return tmp

    writeReg(core#SYNCWORD, 1, @val)

PUB TX
' Change chip state to TX (transmit)
    OpMode(DEVMODE_TX)

PUB TXMode(mode) | tmp
' Set transmit mode
'   Valid values:
'      *TXMODE_NORMAL (0): Normal mode; a single packet is sent
'       TXMODE_CONT (1): Continuous mode; send multiple packets across the FIFO
    tmp := $00
    readReg(core#MDMCFG2, 1, @tmp)
    case mode
        TXMODE_NORMAL, TXMODE_CONT:
            mode <<= core#TXCONTMODE
        OTHER:
            return (tmp >> core#TXCONTMODE) & %1

    tmp &= core#TXCONTMODE_MASK
    tmp := (tmp | mode) & core#MDMCFG2_MASK
    writeReg(core#MDMCFG2, 1, @tmp)

PUB TXPayload(nr_bytes, buff_addr) | tmp
' Queue data to be transmitted in the TX FIFO
'   nr_bytes Valid values: 1..255
'   Any other value is ignored
    case nr_bytes
        1..255:
            writeReg (core#FIFO, nr_bytes, buff_addr)
        OTHER:
            return FALSE

PUB TXPower(dBm, outpin) | tmp, pa_dac
' Set transmit power, in dBm
'   Valid values:
'       outpin:
'           PAOUT_RFO (0): Signal routed to RFO pin, max power is +14dBm
'               dBm: -1..14
'           PAOUT_PABOOST (128): Signal routed to PA_BOOST pin, max power is +20dBm
'               dBm: 5..23
'   Any other value polls the chip and returns the current setting
    tmp := pa_dac := $00
    readReg(core#PACFG, 1, @tmp)
    readReg(core#PADAC, 1, @pa_dac)
    case outpin
        PAOUT_RFO:
            case dBm
                -1..14:
                    tmp := (7 << core#MAXPWR) | (dBm + 1)
                OTHER:
                    return (tmp & core#OUTPUTPWR_BITS) - 1

            writeReg(core#PACFG, 1, @tmp)

        PAOUT_PABOOST:
            case dBm
                5..20:
                    pa_dac := ($10 << core#PADAC_RSVD) | %100

                21..23:
                    pa_dac := ($10 << core#PADAC_RSVD) | %111
                    dBm -= 3

                OTHER:
                    case pa_dac & %111
                        %100:
                            return (tmp & core#OUTPUTPWR_BITS) + 5
                        %111:
                            return (tmp & core#OUTPUTPWR_BITS) + 8
                        OTHER:
                            return pa_dac
                    return

            tmp := (1 << core#PASELECT) | (dBm - 5)
            writeReg(core#PADAC, 1, @pa_dac)
            writeReg(core#PACFG, 1, @tmp)

        OTHER:
            return (tmp & core#OUTPUTPWR_BITS) - 1

PUB ValidHeadersReceived
' Returns number of valid headers received since last transition into receive mode
'   NOTE: To reset counter, set device to DEVMODE_SLEEP
    readReg(core#RXHDRCNTVALUEMSB, 2, @result)

PUB ValidPacketsReceived
' Returns number of valid packets received since last transition into receive mode
'   NOTE: To reset counter, set device to DEVMODE_SLEEP
    readReg(core#RXPACKETCNTVALUEMSB, 2, @result)

PRI readReg(reg, nr_bytes, buff_addr) | i
' Read nr_bytes from register 'reg' to address 'buff_addr'

    case reg
        $00, $01, $06..$2A, $2C, $2F, $39, $40, $42, $44, $4B, $4D, $5B, $5D, $61..$64, $70:
        OTHER:
            return FALSE

    io.Low(_CS)
    spi.SHIFTOUT(_MOSI, _SCK, core#MOSI_BITORDER, 8, reg)

    repeat i from nr_bytes-1 to 0
        byte[buff_addr][i] := spi.SHIFTIN(_MISO, _SCK, core#MISO_BITORDER, 8)
    io.High(_CS)

PRI writeReg(reg, nr_bytes, buff_addr) | i
' Write nr_bytes to register 'reg' stored at buff_addr
    case reg
        $00, $01, $06..$0F, $11, $12, $16, $1D..$24, $26, $27, $2F, $39, $40, $44, $4B, $4D, $5D, $61..$64, $70:
        OTHER:
            return FALSE

    io.Low(_CS)
    spi.SHIFTOUT(_MOSI, _SCK, core#MOSI_BITORDER, 8, reg | core#WRITE)

    repeat i from nr_bytes-1 to 0
        spi.SHIFTOUT(_MOSI, _SCK, core#MOSI_BITORDER, 8, byte[buff_addr][i])

    io.High(_CS)

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
