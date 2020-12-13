{
    --------------------------------------------
    Filename: SX1276-RXDemo.spin
    Author: Jesse Burt
    Description: Receive demo of the SX1276 driver (LoRa mode)
    Copyright (c) 2020
    Started Dec 12, 2020
    Updated Dec 13, 2020
    See end of file for terms of use.
    --------------------------------------------
}

CON

    _clkmode        = cfg#_clkmode
    _xinfreq        = cfg#_xinfreq

' -- User-modifiable constants
    SER_BAUD        = 115_200
    LED             = cfg#LED1

    CS_PIN          = 0
    SCK_PIN         = 1
    MOSI_PIN        = 2
    MISO_PIN        = 3
' --

OBJ

    cfg     : "core.con.boardcfg.flip"
    ser     : "com.serial.terminal.ansi"
    time    : "time"
    lora    : "wireless.transceiver.sx1276.spi"
    int     : "string.integer"

VAR

    byte _buffer[256]

PUB Main{}

    setup{}

    ser.position(0, 3)
    ser.strln(string("Receive mode"))

' -- TX/RX settings
    lora.presetlora{}                           ' factory defaults + LoRa mode
    lora.channel(0)                             ' US 902.3MHz + (chan# * 200kHz)
    lora.intclear(lora#INT_ALL)                 ' clear _all_ interrupts
    lora.fiforxbaseptr($00)                     ' use the whole 256-byte FIFO
                                                '   for RX
    lora.payloadlength(8)                       ' the expected test packets are
' --                                            '   8 bytes

' -- RX-specific settings
    lora.rxmode{}
    lora.intmask(lora#RX_DONE)                  ' interrupt when receive done

    ' change these if having difficulty with reception
    lora.lnagain(0)                             ' 0, -6, -12, -24, -26, -48 dB
    lora.agcmode(false)                         ' true, false (LNAGain() is
                                                ' ignored if true)
' --

    repeat
        ' wait for the radio to finish receiving, then clear the interrupt
        repeat until lora.interrupt{} & lora#RX_DONE
        lora.intclear(lora#RX_DONE)

        lora.fifoaddrpointer(lora.fiforxcurrentaddr{})
        lora.rxpayload(8, @_buffer)             ' get the data from the radio

        ' display the received payload on the terminal
        ser.position(0, 5)
        ser.str(string("Received: "))
        ser.str(@_buffer)
    
PUB Setup{}

    ser.start(SER_BAUD)
    time.msleep(30)
    ser.clear{}
    ser.strln(string("Serial terminal started"))
    if lora.start(CS_PIN, SCK_PIN, MOSI_PIN, MISO_PIN)
        ser.str(string("sx1276 driver started"))
    else
        ser.strln(string("sx1276 driver failed to start - halting"))
        lora.stop{}
        time.msleep(500)
        ser.stop{}
        repeat

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
