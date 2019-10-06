{
    --------------------------------------------
    Filename: wireless.transceiver.sx1272.spi.spin
    Author:
    Description:
    Copyright (c) 2019
    Started Sep 18, 2019
    Updated Sep 18, 2019
    See end of file for terms of use.
    --------------------------------------------
}

CON


VAR

    byte _CS, _MOSI, _MISO, _SCK

OBJ

    spi : "com.spi.4w"                                             'PASM SPI Driver
    core: "core.con.sx1272"                       'File containing your device's register set
    time: "time"                                                'Basic timing functions

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

    repeat i from 0 to nr_bytes-1
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

    repeat i from 0 to nr_bytes-1
        spi.SHIFTOUT(_MOSI, _SCK, core#MISO_BITORDER, 8, byte[buf_addr][i])

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
