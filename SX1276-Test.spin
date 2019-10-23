{
    --------------------------------------------
    Filename: SX1276-Test.spin
    Author: Jesse Burt
    Description: Test of the SX1276 driver
    Copyright (c) 2019
    Started Oct 6, 2019
    Updated Oct 23, 2019
    See end of file for terms of use.
    --------------------------------------------
}

CON

    _clkmode    = cfg#_clkmode
    _xinfreq    = cfg#_xinfreq

    LED         = cfg#LED1
    CS_PIN      = 0
    SCK_PIN     = 1
    MOSI_PIN    = 2
    MISO_PIN    = 3
    RST_PIN     = 4

    COL_REG     = 0
    COL_SET     = COL_REG+25
    COL_READ    = COL_SET+17
    COL_PF      = COL_READ+18


OBJ

    cfg     : "core.con.boardcfg.flip"
    ser     : "com.serial.terminal"
    time    : "time"
    lora    : "wireless.transceiver.sx1276.spi"

VAR

    long _fails, _expanded
    byte _ser_cog, _row

PUB Main | i

    Setup
    lora.DeviceMode (lora#DEVMODE_SLEEP)
    lora.LongRangeMode (lora#LRMODE_LORA)
    time.MSleep (10)
    lora.DeviceMode (lora#DEVMODE_STDBY)
    ser.NewLine
    _row := 3

    LNA (1)
    AGCAUTOON (1)
    FRF (1)
'    CLKOUT (1)
    CODINGRATE (1)
    PPMCORRECTION (1)
    DEVMODE (1)
    DIO0 (1)
    DIO1 (1)
    DIO2 (1)
    DIO3 (1)
    DIO4 (1)
    DIO5 (1)
    FIFOADDRPTR (1)
    FIFORXBASE (1)
    FIFOTXBASE (1)
    FSKRAMPTIME (1)
    HOPPERIOD (1)
    IMPLICITHDR (1)
    IRQFLAGSMASK (1)
    LOWDATAOPT (1)
    LOWFREQMODE (1)
    OCPON (1)
    OCPTRIM (1)
    PAYLOADLEN (1)
    PAYLOADMAXLEN (1)
    PREAMBLELEN (1)
    RXBANDWIDTH (1)
    RXPAYLOADCRC (1)
    RXTIMEOUT (1)
    SPREADFACTOR (1)
    SYNCWORD (1)
    TXMODE (1)
    Flash (LED, 100)

PUB AGCAUTOON(reps) | tmp, read

'    _expanded := TRUE
    _row++
    repeat reps
        repeat tmp from -1 to 0
            lora.AGC (tmp)
            read := lora.AGC (-2)
            Message (string("AGCAUTOON"), tmp, read)

PUB FRF(reps) | tmp, read

'    _expanded := TRUE
    _row++
    repeat reps
        repeat tmp from 137_000_000 to 175_000_000 step 1_000_000
            lora.CarrierFreq (tmp)
            read := lora.CarrierFreq (-2)
            Message (string("FRF"), tmp, read)
        repeat tmp from 410_000_000 to 525_000_000 step 10_000_000
            lora.CarrierFreq (tmp)
            read := lora.CarrierFreq (-2)
            Message (string("FRF"), tmp, read)
        repeat tmp from 862_000_000 to 1_020_000_000 step 10_000_000
            lora.CarrierFreq (tmp)
            read := lora.CarrierFreq (-2)
            Message (string("FRF"), tmp, read)

PUB CLKOUT(reps) | tmp, read

'    _expanded := TRUE
    _row++
    repeat reps
        repeat tmp from 1 to 8
            lora.ClkOut (lookup(tmp: 1, 2, 4, 8, 16, 32, lora#CLKOUT_RC, lora#CLKOUT_OFF))
            read := lora.ClkOut (-2)
            Message (string("CLKOUT"), lookup(tmp: 1, 2, 4, 8, 16, 32, lora#CLKOUT_RC, lora#CLKOUT_OFF), read)

PUB CODINGRATE(reps) | tmp, read

'    _expanded := TRUE
    _row++
    repeat reps
        repeat tmp from 1 to 4
            lora.CodeRate (lookup(tmp: $04_05, $04_06, $04_07, $04_08))
            read := lora.CodeRate (-2)
            Message (string("CODINGRATE"), lookup(tmp: $04_05, $04_06, $04_07, $04_08), read)

PUB PPMCORRECTION(reps) | tmp, read

'    _expanded := TRUE
    _row++
    repeat reps
        repeat tmp from 0 to 255
            lora.DataRateCorrection (tmp)
            read := lora.DataRateCorrection (-2)
            Message (string("PPMCORRECTION"), tmp, read)

PUB DEVMODE(reps) | tmp, read

'    _expanded := TRUE
    _row++
    repeat reps
        repeat tmp from 0 to 7
            lora.DeviceMode (tmp)
            read := lora.DeviceMode (-2)
            time.MSleep (50)                        'Delay needed to give the radio time to switch from TX to RX
            Message (string("DEVMODE"), tmp, read)

PUB DIO0(reps) | tmp, read

'    _expanded := TRUE
    _row++
    repeat reps
        repeat tmp from 0 to 2
            lora.DIO0 (tmp)
            read := lora.DIO0 (-2)
            Message (string("DIO0"), tmp, read)

PUB DIO1(reps) | tmp, read

'    _expanded := TRUE
    _row++
    repeat reps
        repeat tmp from 0 to 1
            lora.DIO1 (tmp)
            read := lora.DIO1 (-2)
            Message (string("DIO1"), tmp, read)

PUB DIO2(reps) | tmp, read

'    _expanded := TRUE
    _row++
    repeat reps
        repeat tmp from 0 to 3
            if tmp == 1 or tmp == 2
                next
            lora.DIO2 (tmp)
            read := lora.DIO2 (-2)
            Message (string("DIO2"), tmp, read)

PUB DIO3(reps) | tmp, read

'    _expanded := TRUE
    _row++
    repeat reps
        repeat tmp from 0 to 2
            lora.DIO3 (tmp)
            read := lora.DIO3 (-2)
            Message (string("DIO3"), tmp, read)

PUB DIO4(reps) | tmp, read

'    _expanded := TRUE
    _row++
    repeat reps
        repeat tmp from 0 to 1
            lora.DIO4 (tmp)
            read := lora.DIO4 (-2)
            Message (string("DIO4"), tmp, read)

PUB DIO5(reps) | tmp, read

'    _expanded := TRUE
    _row++
    repeat reps
        repeat tmp from 0 to 1
            lora.DIO5 (tmp)
            read := lora.DIO5 (-2)
            Message (string("DIO5"), tmp, read)

PUB FIFOADDRPTR(reps) | tmp, read

'    _expanded := TRUE
    _row++
    repeat reps
        repeat tmp from 0 to 255
            lora.FIFOAddrPointer (tmp)
            read := lora.FIFOAddrPointer (-2)
            Message (string("FIFOADDRPTR"), tmp, read)

PUB FIFORXBASE(reps) | tmp, read

'    _expanded := TRUE
    _row++
    repeat reps
        repeat tmp from 0 to 255
            lora.FIFORXBasePtr (tmp)
            read := lora.FIFORXBasePtr (-2)
            Message (string("FIFORXBASEADDR"), tmp, read)

PUB FIFOTXBASE(reps) | tmp, read

'    _expanded := TRUE
    _row++
    repeat reps
        repeat tmp from 0 to 255
            lora.FIFOTXBasePtr (tmp)
            read := lora.FIFOTXBasePtr (-2)
            Message (string("FIFOTXBASEADDR"), tmp, read)

PUB FSKRAMPTIME(reps) | tmp, read

'    _expanded := TRUE
    _row++
    repeat reps
        repeat tmp from 1 to 16
            lora.FSKRampTime (lookup(tmp: 3400, 2000, 1000, 500, 250, 125, 100, 62, 50, 40, 31, 25, 20, 15, 12, 10))
            read := lora.FSKRampTime (-2)
            Message (string("FSKRAMPTIME"), lookup(tmp: 3400, 2000, 1000, 500, 250, 125, 100, 62, 50, 40, 31, 25, 20, 15, 12, 10), read)

PUB HOPPERIOD(reps) | tmp, read

'    _expanded := TRUE
    _row++
    repeat reps
        repeat tmp from 0 to 255
            lora.HopPeriod (tmp)
            read := lora.HopPeriod (-2)
            Message (string("HOPPERIOD"), tmp, read)

PUB IMPLICITHDR(reps) | tmp, read

'    _expanded := TRUE
    _row++
    repeat reps
        repeat tmp from -1 to 0
            lora.ImplicitHeaderMode (tmp)
            read := lora.ImplicitHeaderMode (-2)
            Message (string("IMPLICITHDR"), tmp, read)

PUB IRQFLAGSMASK(reps) | tmp, read

'    _expanded := TRUE
    _row++
    repeat reps
        repeat tmp from %00000000 to %11111111
            lora.IntMask (tmp)
            read := lora.IntMask (-2)
            Message (string("IRQFLAGSMASK"), tmp, read)

PUB LNA(reps) | tmp, read

'    _expanded := TRUE
    lora.AGC (FALSE)
    _row++
    repeat reps
        repeat tmp from 1 to 6
            lora.LNA (lookup(tmp: 0, -6, -12, -24, -26, -48))
            read := lora.LNA (-2)
            Message (string("LNAGAIN"), lookup(tmp: 0, -6, -12, -24, -26, -48), read)
    lora.AGC (TRUE)

PUB LOWDATAOPT(reps) | tmp, read

'    _expanded := TRUE
    _row++
    repeat reps
        repeat tmp from -1 to 0
            lora.LowDataRateOptimize (tmp)
            read := lora.LowDataRateOptimize (-2)
            Message (string("LOWDATAOPT"), tmp, read)

PUB LOWFREQMODE(reps) | tmp, read

'    _expanded := TRUE
    _row++
    repeat reps
        repeat tmp from -1 to 0
            lora.LowFreqMode (tmp)
            read := lora.LowFreqMode (-2)
            Message (string("LOWFREQMODEON"), tmp, read)

PUB OCPON(reps) | tmp, read

'    _expanded := TRUE
    _row++
    repeat reps
        repeat tmp from -1 to 0
            lora.OverCurrentProt (tmp)
            read := lora.OverCurrentProt (-2)
            Message (string("OCPON"), tmp, read)

PUB OCPTRIM(reps) | tmp, read

'    _expanded := TRUE
    _row++
    repeat reps
        repeat tmp from 1 to 28
            lora.OverCurrentTrim (lookup(tmp: 45, 50, 55, 60, 65, 70, 75, 80, 85, 90, 95, 100, 105, 110, 115, 120, 130, 140, 150, 160, 170, 180, 190, 200, 210, 220, 230, 240))
            read := lora.OverCurrentTrim (-2)
            Message (string("OCPTRIM"), lookup(tmp: 45, 50, 55, 60, 65, 70, 75, 80, 85, 90, 95, 100, 105, 110, 115, 120, 130, 140, 150, 160, 170, 180, 190, 200, 210, 220, 230, 240), read)

PUB PAYLOADLEN(reps) | tmp, read

'    _expanded := TRUE
    _row++
    repeat reps
        repeat tmp from 0 to 255
            lora.PayloadLength (tmp)
            read := lora.PayloadLength (-2)
            Message (string("PAYLOADLEN"), tmp, read)

PUB PAYLOADMAXLEN(reps) | tmp, read

'    _expanded := TRUE
    _row++
    repeat reps
        repeat tmp from 0 to 255
            lora.PayloadMaxLength (tmp)
            read := lora.PayloadMaxLength (-2)
            Message (string("PAYLOADMAXLEN"), tmp, read)

PUB PREAMBLELEN(reps) | tmp, read

'    _expanded := TRUE
    _row++
    repeat reps
        repeat tmp from 0 to 65535
            lora.PreambleLength (tmp)
            read := lora.PreambleLength (-2)
            Message (string("PREAMBLELEN"), tmp, read)

PUB RXBANDWIDTH(reps) | tmp, read

'    _expanded := TRUE
    _row++
    repeat reps
        repeat tmp from 1 to 10
            lora.RXBandwidth (lookup(tmp: 7800, 10_400, 15_600, 20_800, 31_250, 41_700, 62_500, 125_000, 250_000, 500_000))
            read := lora.RXBandwidth (-2)
            Message (string("RXBANDWIDTH"), lookup(tmp: 7800, 10_400, 15_600, 20_800, 31_250, 41_700, 62_500, 125_000, 250_000, 500_000), read)

PUB RXPAYLOADCRC(reps) | tmp, read

'    _expanded := TRUE
    _row++
    repeat reps
        repeat tmp from -1 to 0
            lora.RXPayloadCRC (tmp)
            read := lora.RXPayloadCRC (-2)
            Message (string("RXPAYLOADCRC"), tmp, read)

PUB RXTIMEOUT(reps) | tmp, read

'    _expanded := TRUE
    _row++
    repeat reps
        repeat tmp from 0 to 1023
            lora.RXTimeout (tmp)
            read := lora.RXTimeout (-2)
            Message (string("RXTIMEOUT"), tmp, read)

PUB SPREADFACTOR(reps) | tmp, read

'    _expanded := TRUE
    _row++
    repeat reps
        repeat tmp from 1 to 7
            lora.SpreadingFactor (lookup(tmp: 64, 128, 256, 512, 1024, 2048, 4096))
            read := lora.SpreadingFactor (-2)
            Message (string("SPREADFACTOR"), lookup(tmp: 64, 128, 256, 512, 1024, 2048, 4096), read)

PUB SYNCWORD(reps) | tmp, read

'    _expanded := TRUE
    _row++
    repeat reps
        repeat tmp from $00 to $FF
            lora.SyncWord (tmp)
            read := lora.SyncWord (-2)
            Message (string("SYNCWORD"), tmp, read)

PUB TXMODE(reps) | tmp, read

'    _expanded := TRUE
    _row++
    repeat reps
        repeat tmp from 1 to 0
            lora.TXMode (tmp)
            read := lora.TXMode (-2)
            Message (string("TXMODE"), tmp, read)

PUB Message(field, arg1, arg2)

    case _expanded
        TRUE:
            ser.PositionX (COL_REG)
            ser.Str (field)

            ser.PositionX (COL_SET)
            ser.Str (string("SET: "))
            ser.Dec (arg1)

            ser.PositionX (COL_READ)
            ser.Str (string("READ: "))
            ser.Dec (arg2)
            ser.Chars (32, 3)
            ser.PositionX (COL_PF)
            PassFail (arg1 == arg2)
            ser.NewLine

        FALSE:
            ser.Position (COL_REG, _row)
            ser.Str (field)

            ser.Position (COL_SET, _row)
            ser.Str (string("SET: "))
            ser.Dec (arg1)

            ser.Position (COL_READ, _row)
            ser.Str (string("READ: "))
            ser.Dec (arg2)

            ser.Position (COL_PF, _row)
            PassFail (arg1 == arg2)
            ser.NewLine
        OTHER:
            ser.Str (string("DEADBEEF"))

PUB PassFail(num)

    case num
        0:
            ser.Str (string("FAIL"))
            _fails++

        -1:
            ser.Str (string("PASS"))

        OTHER:
            ser.Str (string("???"))

PUB Setup

    repeat until _ser_cog := ser.Start (115_200)
    ser.Clear
    ser.Str(string("Serial terminal started", ser#NL))
    if lora.Start (CS_PIN, SCK_PIN, MOSI_PIN, MISO_PIN)
        ser.Str(string("sx1276 driver started", ser#NL))
    else
        ser.Str(string("sx1276 driver failed to start - halting", ser#NL))
        lora.Stop
        time.MSleep (500)
        ser.Stop
        Flash (LED, 500)

PUB Flash(led_pin, delay_ms)

    dira[led_pin] := 1
    repeat
        !outa[led_pin]
        time.MSleep (delay_ms)


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
