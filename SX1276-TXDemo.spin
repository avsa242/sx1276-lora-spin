{
    --------------------------------------------
    Filename: SX1276-TXDemo.spin
    Author: Jesse Burt
    Description: Transmit demo of the SX1276 driver (LoRa mode)
    Copyright (c) 2022
    Started Dec 12, 2020
    Updated Nov 13, 2022
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
    RESET_PIN       = 4                         ' optional (-1 to disable)
' --

OBJ

    cfg : "boardcfg.flip"
    ser : "com.serial.terminal.ansi"
    time: "time"
    lora: "wireless.transceiver.sx1276-lora"
    str : "string"

VAR

    byte _buffer[256]

PUB main{} | count

    setup{}

    ser.pos_xy(0, 3)
    ser.strln(string("Transmit mode"))

' -- TX/RX settings
    lora.preset_lora{}                          ' factory defaults + LoRa mode
    lora.channel(0)                             ' US 902.3MHz + (chan# * 200kHz)
    lora.int_clear(lora#INT_ALL)                  ' clear _all_ interrupts
    lora.fifo_tx_base_ptr($00)                  ' use the whole 256-byte FIFO
                                                '   for TX
    lora.payld_len(8)                           ' the test packets are
' --                                            '   8 bytes

' -- TX-specific settings
    lora.tx_sig_routing(lora#PABOOST)           ' RFO, PABOOST (board-dependent)
    lora.tx_pwr(5)                              ' -1..14 (RFO) 5..23 (PABOOST)
    lora.int_mask(lora#INT_TX_DONE)             ' set interrupt on transmit done
    lora.tx_cont(lora#TXMODE_NORMAL)
' --

    count := 0
    repeat
        bytefill(@_buffer, 0, 256)              ' clear temp TX buffer

        { payload is the string 'TEST' with hexadecimal counter after }
        str.sprintf1(@_buffer, string("TEST%04.4x"), count)
        lora.opmode(lora#STDBY)

        { make sure the data is placed at the start of the TX FIFO }
        lora.fifo_addr_ptr($00)
        lora.tx_payld(8, @_buffer)              ' queue the data
        lora.tx_mode{}                          ' finally, transmit it

        { wait until sending is complete, then clear the interrupt }
        repeat until (lora.interrupt{} & lora#INT_TX_DONE)
        lora.int_clear(lora#INT_TX_DONE)

        count++
        ser.pos_xy(0, 5)
        ser.str(string("Sending: "))
        ser.str(@_buffer)
        time.msleep(5000)                       ' wait in between packets
                                                ' (don't abuse the airwaves)

PUB setup{}

    ser.start(SER_BAUD)
    time.msleep(30)
    ser.clear{}
    ser.strln(string("Serial terminal started"))
    if lora.startx(CS_PIN, SCK_PIN, MOSI_PIN, MISO_PIN, RESET_PIN)
        ser.strln(string("SX1276 driver started"))
    else
        ser.strln(string("SX1276 driver failed to start - halting"))
        repeat

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

