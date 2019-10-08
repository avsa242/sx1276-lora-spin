{
    --------------------------------------------
    Filename: wireless.transceiver.sx1276.spi.spin
    Author: Jesse Burt
    Description: Driver for the SEMTECH SX1276
        LoRa/FSK/OOK transceiver
    Copyright (c) 2019
    Started Oct 6, 2019
    Updated Oct 6, 2019
    See end of file for terms of use.
    --------------------------------------------
}

CON

    FXOSC                   = 32_000_000
    TWO_19                  = 1 << 19
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

PUB CarrierFreq(freq) | tmp, devmode_tmp
' Set carrier frequency, in Hz
'   Valid values: See case table below
'   Any other value polls the chip and returns the current setting
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
'       $04_05  =   4/5
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

PUB DeviceMode(mode) | tmp
' Set device operating mode
'   Valid values:
'       DEVMODE_SLEEP (%000): Sleep
'       DEVMODE_STDBY (%001): Standby
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

PUB HeaderInfoValid

    result := ((ModemStatus >> 3) & %1) * TRUE

PUB LongRangeMode(mode) | tmp, devmode_tmp
' Set long-range mode
'   Valid values:
'      *LRMODE_FSK_OOK (0): FSK, OOK packet radio mode
'       LRMODE_LORA (1): LoRa radio mode
'   Any other value polls the chip and returns the current setting
'   NOTE: Changing this setting sets the chip to sleep mode while the mode is changed
'       and subsequently changes it to the original state
    tmp := $00
    readReg(core#OPMODE, 1, @tmp)
    case mode
        LRMODE_FSK_OOK, LRMODE_LORA:
            mode := mode << core#FLD_LONGRANGEMODE
        OTHER:
            return (tmp >> core#FLD_LONGRANGEMODE) & %1

    devmode_tmp := DeviceMode(-2)
    DeviceMode(DEVMODE_SLEEP)
    tmp &= core#MASK_LONGRANGEMODE
    tmp := (tmp | mode) & core#OPMODE_MASK
    writeReg(core#OPMODE, 1, @tmp)
    DeviceMode(devmode_tmp)

PUB ModemClear
' Return modem clear status
    result := ((ModemStatus >> 4) & %1) * TRUE

PUB ModemStatus
' Return modem status bitmask
    readReg(core#MODEMSTAT, 1, @result)
    result &= core#BITS_MODEMSTATUS

PUB RXOngoing
' Return receive on-going status
    result := ((ModemStatus >> 2) & %1) * TRUE

PUB SignalDetected
' Return signal detected
    result := (ModemStatus & %1) * TRUE

PUB SignalSynchronized
' Return signal synchronized
    result := ((ModemStatus >> 1) & %1) * TRUE

PUB PacketRSSI
' RSSI of last packet received, in dBm
    readReg(core#PKTRSSIVALUE, 1, @result)
    result := -137 + result

PUB PacketSNR
' Signal to noise ratio of last packet received, in dB (estimated)
    readReg(core#PKTSNRVALUE, 1, @result)
    result := ~result / 4

PUB RSSI
' Current RSSI, in dBm
    result := $00
    readReg(core#LORA_RSSIVALUE, 1, @result)
    result := -157 + result

PUB RxBW(Hz) | tmp
' Set receive bandwidth, in Hz
'   Valid values: 7800, 10_400, 15_600, 20_800, 31_250, 41_700, 62_500, 125_000, 250_000, 500_000
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
