{
    --------------------------------------------
    Filename: wireless.transceiver.sx1276.spi.spin
    Author: Jesse Burt
    Description: Driver for the SEMTECH SX1276
        LoRa/FSK/OOK transceiver
    Copyright (c) 2019
    Started Oct 6, 2019
    Updated Oct 10, 2019
    See end of file for terms of use.
    --------------------------------------------
}

CON

    FXOSC                   = 32_000_000
    TWO_19                  = 1 << 19
    TWO_24                  = 1 << 24
    FPSCALE                 = 1_000_000
    FSTEP                   = 61035156  ' (FXOSC / TWO_19) * FPSCALE
' Long-range modes
    LRMODE_FSK_OOK          = 0
    LRMODE_LORA             = 1

' Device modes
    DEVMODE_SLEEP           = %000
    DEVMODE_STDBY           = %001
    DEVMODE_FSTX            = %010
    DEVMODE_TX              = %011
    DEVMODE_FSRX            = %100
    DEVMODE_RXCONTINUOUS    = %101
    DEVMODE_RXSINGLE        = %110
    DEVMODE_CAD             = %111

' Transmit modes
    TXMODE_NORMAL           = 0
    TXMODE_CONT             = 1

VAR

    byte _CS, _MOSI, _MISO, _SCK

OBJ

    spi : "com.spi.4w"                                             'PASM SPI Driver
    core: "core.con.sx1276"                       'File containing your device's register set
    time: "time"                                                'Basic timing functions
    u64 : "math.unsigned64"

PUB Null
''This is not a top-level object

PUB Start(CS_PIN, SCK_PIN, MOSI_PIN, MISO_PIN) : okay

    okay := Startx(CS_PIN, SCK_PIN, MOSI_PIN, MISO_PIN, core#CLK_DELAY, core#CPOL)

PUB Startx(CS_PIN, SCK_PIN, MOSI_PIN, MISO_PIN, SCK_DELAY, SCK_CPOL): okay
    if SCK_DELAY => 1 and lookdown(SCK_CPOL: 0, 1)
        if okay := spi.start (SCK_DELAY, SCK_CPOL)              'SPI Object Started?
            time.MSleep (10)
            _CS := CS_PIN
            _MOSI := MOSI_PIN
            _MISO := MISO_PIN
            _SCK := SCK_PIN

            outa[_CS] := 1
            dira[_CS] := 1
            if lookdown(Version: $11, $12)
                return okay

    return FALSE                                                'If we got here, something went wrong

PUB Stop

    spi.stop

PUB AGC(enabled) | tmp
' Enable AGC
'   Valid values:
'       TRUE(-1 or 1), *FALSE (0)
'   Any other value polls the chip and returns the current setting
    tmp := $00
    readReg(core#MODEMCONFIG3, 1, @tmp)
    case ||enabled
        0, 1:
            enabled := (||enabled & %1) << core#FLD_AGCAUTOON
        OTHER:
            return ((tmp >> core#FLD_AGCAUTOON) & %1) * TRUE

    tmp &= core#MASK_AGCAUTOON
    tmp := (tmp | enabled) & core#MODEMCONFIG3_MASK
    writeReg(core#MODEMCONFIG3, 1, @tmp)

PUB CarrierFreq(freq) | tmp, devmode_tmp
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

    devmode_tmp := DeviceMode (-2)
    DeviceMode (DEVMODE_STDBY)
    writeReg(core#FRFMSB, 3, @freq)
    DeviceMode (devmode_tmp)

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
    readReg(core#MODEMCONFIG1, 1, @tmp)
    case rate
        $04_05..$04_08:
            rate := lookdown(rate: $04_05, $04_06, $04_07, $04_08)
        OTHER:
            result := (tmp >> core#FLD_CODINGRATE) & core#BITS_CODINGRATE
            return lookup(result: $04_05, $04_06, $04_07, $04_08)

    tmp &= core#MASK_CODINGRATE
    tmp := (tmp | rate) & core#MODEMCONFIG1_MASK
    writeReg(core#MODEMCONFIG1, 1, @tmp)

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

PUB DeviceMode(mode) | tmp
' Set device operating mode
'   Valid values:
'       DEVMODE_SLEEP (%000): Sleep
'      *DEVMODE_STDBY (%001): Standby
'       DEVMODE_FSTX (%010): Frequency synthesis TX
'       DEVMODE_TX (%011): Transmit
'       DEVMODE_FSRX (%100): Frequency synthesis RX
'       DEVMODE_RXCONTINUOUS (%101): Receive continuous
'       DEVMODE_RXSINGLE (%110): Receive single
'       DEVMODE_CAD (%111): Channel activity detection
'   Any other value polls the chip and returns the current setting
    tmp := $00
    readReg(core#OPMODE, 1, @tmp)
    case mode
        DEVMODE_SLEEP..DEVMODE_CAD:
        OTHER:
            return tmp & core#BITS_MODE

    tmp &= core#MASK_MODE
    tmp := (tmp | mode) & core#OPMODE_MASK
    writeReg(core#OPMODE, 1, @tmp)

PUB FreqError | tmp, bw
' Estimated frequency error from modem
    tmp := $0_00_00
    readReg(core#FEIMSB, 3, @tmp)
    bw := RXBandwidth (-2)
    result := u64.MultDiv (tmp, TWO_24, FXOSC)
    return result * (bw / 500)

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
            uSec := lookdownz(uSec: 3400, 2000, 1000, 500, 250, 125, 100, 62, 50, 40, 31, 25, 20, 15, 12, 10) & core#BITS_PARAMP
        OTHER:
            return lookupz(tmp: 3400, 2000, 1000, 500, 250, 125, 100, 62, 50, 40, 31, 25, 20, 15, 12, 10) & core#BITS_PARAMP

    writeReg(core#PARAMP, 1, @uSec)

PUB HeaderInfoValid

    result := ((ModemStatus >> 3) & %1) * TRUE

PUB HopChannel
' Returns current frequency hopping channel
    readReg(core#HOPCHANNEL, 1, @result)
    result &= core#BITS_FHSSPRESENTCHANNEL

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

PUB ImplicitHeaderMode(enabled) | tmp
' Enable implicit header mode
'   Valid values:
'       TRUE(-1 or 1), *FALSE (0)
'   Any other value polls the chip and returns the current setting
    tmp := $00
    readReg(core#MODEMCONFIG1, 1, @tmp)
    case ||enabled
        0, 1:
            enabled := ||enabled & %1
        OTHER:
            return (tmp & %1) * TRUE

    tmp &= core#MASK_IMPL_HEADERMODEON
    tmp := (tmp | enabled) & core#MODEMCONFIG1_MASK
    writeReg(core#MODEMCONFIG1, 1, @tmp)

PUB Interrupt
' Read interrupt flags
'   Returns: Interrupt flags as a mask
'   Bits set are asserted
'   Bits %76543210
'   Bit 7: Receive timeout
'       6: Receive done
'       5: Payload CRC error
'       4: Valid header
'       3: Transmit done
'       2: CAD done
'       1: FHSS change channel
'       0: CAD detected
    readReg(core#IRQFLAGS, 1, @result)

PUB IntMask(mask) | tmp
' Set interrupt mask
'   Valid values:
'       Bits %76543210
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

    writeReg(core#IRQFLAGS_MASK, 1, @tmp)

PUB LastHeaderCodingRate
' Returns coding rate of last header received
    readReg(core#MODEMSTAT, 1, @result)
    result >>= 5

PUB LastPacketBytes
' Returns number of payload bytes of last packet received
    readReg(core#RXNBBYTES, 1, @result)

PUB LongRangeMode(mode) | tmp
' Set long-range mode
'   Valid values:
'      *LRMODE_FSK_OOK (0): FSK, OOK packet radio mode
'       LRMODE_LORA (1): LoRa radio mode
'   Any other value polls the chip and returns the current setting
'   NOTE: You must set the DeviceMode to DEVMODE_SLEEP before changing this setting
    tmp := $00
    readReg(core#OPMODE, 1, @tmp)
    case mode
        LRMODE_FSK_OOK, LRMODE_LORA:
            mode := mode << core#FLD_LONGRANGEMODE
        OTHER:
            return (tmp >> core#FLD_LONGRANGEMODE) & %1

    tmp &= core#MASK_LONGRANGEMODE
    tmp := (tmp | mode) & core#OPMODE_MASK
    writeReg(core#OPMODE, 1, @tmp)

PUB LowDataRateOptimize(enabled) | tmp
' Optimize for low data rates
'   Valid values:
'       TRUE (-1 or 1), FALSE (0)
'   Any other value polls the chip and returns the current setting
'   NOTE: This setting is mandated when the symbol length exceeds 16ms
    tmp := $00
    readReg(core#MODEMCONFIG3, 1, @tmp)
    case ||enabled
        0, 1:
            enabled := ||enabled << core#FLD_LOWDATARATEOPTIMIZE
        OTHER:
            return ((tmp >> core#FLD_LOWDATARATEOPTIMIZE) & %1) * TRUE

    tmp &= core#MASK_LOWDATARATEOPTIMIZE
    tmp := (tmp | enabled) & core#MODEMCONFIG3_MASK
    writeReg(core#MODEMCONFIG3, 1, @tmp)

PUB ModemClear
' Return modem clear status
    result := ((ModemStatus >> 4) & %1) * TRUE

PUB ModemStatus
' Return modem status bitmask
    readReg(core#MODEMSTAT, 1, @result)
    result &= core#BITS_MODEMSTATUS

PUB OverCurrentProt(enabled) | tmp
' Enable over-current protection for PA
'   Valid values:
'      *TRUE (-1 or 1), FALSE (0)
'   Any other value polls the chip and returns the current setting
    tmp := $00
    readReg(core#OCP, 1, @tmp)
    case ||enabled
        0, 1:
            enabled := ||enabled << core#FLD_OCPON
        OTHER:
            return ((tmp >> core#FLD_OCPON) & %1) * TRUE

    tmp &= core#MASK_OCPON
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
            result := tmp & core#BITS_OCPTRIM
            case result
                0..15:
                    return 45 + 5 * result
                16..27:
                    return -30 + 10 * result
                28..31:
                    return 240

    tmp &= core#MASK_OCPTRIM
    tmp := (tmp | mA) & core#OCP_MASK
    writeReg(core#OCP, 1, @tmp)

PUB PacketRSSI
' RSSI of last packet received, in dBm
    readReg(core#PKTRSSIVALUE, 1, @result)
    result := -137 + result

PUB PacketSNR
' Signal to noise ratio of last packet received, in dB (estimated)
    readReg(core#PKTSNRVALUE, 1, @result)
    result := ~result / 4

PUB PayloadLength(len) | tmp
' Set payload length, in bytes
'   Valid values: 1..255
'   Any other value polls the chip and returns the current setting
    tmp := $00
    readReg(core#PAYLOADLENGTH, 1, @tmp)
    case len
        1..255:
        OTHER:
            return tmp

    writeReg(core#PAYLOADLENGTH, 1, @len)

PUB PayloadMaxLength(len) | tmp
' Set payload maximum length, in bytes
'   Valid values: 0..255
'   Any other value polls the chip and returns the current setting
'   NOTE: If header payload length exceeds this value, a header CRC error is generated,
'       allowing filtering of packets with a bad size
    tmp := $00
    readReg(core#MAXPAYLOADLENGTH, 1, @tmp)
    case len
        0..255:
        OTHER:
            return tmp

    writeReg(core#MAXPAYLOADLENGTH, 1, @len)

PUB PreambleLength(len) | tmp
' Set preamble length, in bits
'   Valid values: 0..65535
'   Any other value polls the chip and returns the current setting
    tmp := $00
    readReg(core#PREAMBLEMSB, 2, @tmp)
    case len
        0..65535:
        OTHER:
            return tmp

    writeReg(core#PREAMBLEMSB, 2, @len)

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
    readReg(core#MODEMCONFIG1, 1, @tmp)
    case Hz
        7800, 10_400, 15_600, 20_800, 31_250, 41_700, 62_500, 125_000, 250_000, 500_000:
            Hz := lookdownz(Hz: 7800, 10_400, 15_600, 20_800, 31_250, 41_700, 62_500, 125_000, 250_000, 500_000) << core#FLD_BW
        OTHER:
            result := (tmp >> core#FLD_BW)
            return lookupz(result: 7800, 10_400, 15_600, 20_800, 31_250, 41_700, 62_500, 125_000, 250_000, 500_000)
    tmp &= core#MASK_BW
    tmp := (tmp | Hz) & core#MODEMCONFIG1_MASK
    writeReg(core#MODEMCONFIG1, 1, @tmp)

PUB RXOngoing
' Return receive on-going status
    result := ((ModemStatus >> 2) & %1) * TRUE

PUB RXPayloadCRC(enabled) | tmp
' Enable CRC generation and check on payload
'   Valid values: TRUE (-1 or 1), FALSE (0)
'   Any other value polls the chip and returns the current setting
    tmp := $00
    readReg(core#MODEMCONFIG2, 1, @tmp)
    case ||enabled
        0, 1:
            enabled := ||enabled << core#FLD_RXPAYLOADCRCON
        OTHER:
            return ((tmp >> core#FLD_RXPAYLOADCRCON) & %1) * TRUE

    tmp &= core#MASK_RXPAYLOADCRCON
    tmp := (tmp | enabled) & core#MODEMCONFIG2_MASK
    writeReg(core#MODEMCONFIG2, 1, @tmp)

PUB RXTimeout(symbols) | tmp, symbtimeout_msb, symbtimeout_lsb
' Set receive timeout, in symbols
'   Valid values: 0..1023
'   Any other value polls the chip and returns the current setting
    tmp := $00
    readReg(core#MODEMCONFIG2, 2, @tmp) ' The top 2 bits of SYMBTIMEOUT are in this reg
    case symbols                        '   the bottom 8 bits are in the next reg
        0..1023:
            symbtimeout_msb := symbols >> 8
            symbtimeout_lsb := symbols & $FF
        OTHER:
            result := tmp & core#BITS_SYMBTIMEOUT

    tmp &= core#MASK_SYMBTIMEOUTMSB
    tmp := (tmp | symbtimeout_msb) & core#MODEMCONFIG2_MASK
    writeReg(core#MODEMCONFIG2, 1, @tmp)
    writeReg(core#SYMBTIMEOUTLSB, 1, @symbtimeout_lsb)

PUB SignalDetected
' Return signal detected
    result := (ModemStatus & %1) * TRUE

PUB SignalSynchronized
' Return signal synchronized
    result := ((ModemStatus >> 1) & %1) * TRUE

PUB SpreadingFactor(chips_sym) | tmp
' Set spreading factor rate, in chips per symbol
'   Valid values: 64, *128, 256, 512, 1024, 2048, 4096
'   Any other value polls the chip and returns the current setting
    tmp := $00
    readReg(core#MODEMCONFIG2, 1, @tmp)
    case chips_sym
        64, 128, 256, 512, 1024, 2048, 4096:
            chips_sym := lookdown(chips_sym: 64, 128, 256, 512, 1024, 2048, 4096)
        OTHER:
            result := (tmp >> core#FLD_SPREADINGFACTOR)-5
            return lookup(result: 64, 128, 256, 512, 1024, 2048, 4096)

    tmp &= core#MASK_SPREADINGFACTOR
    tmp := (tmp | chips_sym) & core#MODEMCONFIG2_MASK
    writeReg(core#MODEMCONFIG2, 1, @tmp)

PUB TXMode(mode) | tmp
' Set transmit mode
'   Valid values:
'      *TXMODE_NORMAL (0): Normal mode; a single packet is sent
'       TXMODE_CONT (1): Continuous mode; send multiple packets across the FIFO
    tmp := $00
    readReg(core#MODEMCONFIG2, 1, @tmp)
    case mode
        TXMODE_NORMAL, TXMODE_CONT:
            mode <<= core#FLD_TXCONTINUOUSMODE
        OTHER:
            return (tmp >> core#FLD_TXCONTINUOUSMODE) & %1

    tmp &= core#MASK_TXCONTINUOUSMODE
    tmp := (tmp | mode) & core#MODEMCONFIG2_MASK
    writeReg(core#MODEMCONFIG2, 1, @tmp)

PUB ValidHeadersReceived
' Returns number of valid headers received since last transition into receive mode
'   NOTE: To reset counter, set device to DEVMODE_SLEEP
    readReg(core#RXHEADERCNTVALUEMSB, 2, @result)

PUB ValidPacketsReceived
' Returns number of valid packets received since last transition into receive mode
'   NOTE: To reset counter, set device to DEVMODE_SLEEP
    readReg(core#RXPACKETCNTVALUEMSB, 2, @result)

PUB Version
' Version code of the chip
'   Returns:
'       Bits 7..4: full revision number
'       Bits 3..0: metal mask revision number
'   Known values: $11, $12
    result := $00
    readReg(core#VERSION, 1, @result)

PUB readReg(reg, nr_bytes, buf_addr) | i
' Read nr_bytes from register 'reg' to address 'buf_addr'

    case reg
        $00..$16, $1A..$42, $44, $4B, $4D, $5B, $5D, $61..$64:
        OTHER:
            return FALSE

    outa[_CS] := 0
    spi.SHIFTOUT(_MOSI, _SCK, core#MOSI_BITORDER, 8, reg)

    repeat i from nr_bytes-1 to 0
        byte[buf_addr][i] := spi.SHIFTIN(_MISO, _SCK, core#MISO_BITORDER, 8)
    outa[_CS] := 1

PUB writeReg(reg, nr_bytes, buf_addr) | i
' Write nr_bytes to register 'reg' stored at buf_addr
    case reg
        $00..$16, $1A..$42, $44, $4B, $4D, $5B, $5D, $61..$64:
        OTHER:
            return FALSE

    outa[_CS] := 0
    spi.SHIFTOUT(_MOSI, _SCK, core#MOSI_BITORDER, 8, reg | core#WRITE)

    repeat i from nr_bytes-1 to 0
        spi.SHIFTOUT(_MOSI, _SCK, core#MOSI_BITORDER, 8, byte[buf_addr][i])

    outa[_CS] := 1

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
