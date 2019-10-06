{
    --------------------------------------------
    Filename: SX1276-Test.spin
    Author: Jesse Burt
    Description: Test of the SX1276 driver
    Copyright (c) 2019
    Started Oct 6, 2019
    Updated Oct 6, 2019
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

OBJ

    cfg     : "core.con.boardcfg.flip"
    ser     : "com.serial.terminal"
    time    : "time"
    lora    : "wireless.transceiver.sx1276.spi"

VAR

    byte _ser_cog

PUB Main

    Setup
    ser.NewLine
    ser.Hex ( lora.Version, 8)
    Flash (LED, 100)

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
