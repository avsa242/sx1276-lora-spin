{
    --------------------------------------------
    Filename: SX1276-LoRa-TXRXDemo.spin
    Author: Jesse Burt
    Description: Demo of the SX1276 driver
    Copyright (c) 2019
    Started Oct 6, 2019
    Updated Oct 22, 2019
    See end of file for terms of use.
    --------------------------------------------
}

CON

    _clkmode        = cfg#_clkmode
    _xinfreq        = cfg#_xinfreq

    LED             = cfg#LED1
    CS_PIN          = 0
    SCK_PIN         = 1
    MOSI_PIN        = 2
    MISO_PIN        = 3
    RST_PIN         = 4
    DIO0            = 5

    DISP_HELP       = 1
    DO_RX           = 2
    DO_TX           = 3
    SET_DEFAULTS    = 4
    DISP_SETTINGS   = 5
    SET_FREQ        = 6
    DO_MONITOR      = 7
    WAITING         = 100

    TERM_START_X    = 0
    TERM_START_Y    = 0
    TERM_MAX_X      = 85
    TERM_MAX_Y      = 43
    FIELDWIDTH      = 18
    MSG_X           = 0
    MSG_Y           = 40
    HELP_X          = 0
    HELP_Y          = 30
    DEVMODE_X       = 0
    DEVMODE_Y       = 0
    LORAMODE_X      = DEVMODE_X+FIELDWIDTH
    LORAMODE_Y      = DEVMODE_Y
    FREQ_X          = LORAMODE_X+FIELDWIDTH
    FREQ_Y          = DEVMODE_Y
    SYNCW_X         = FREQ_X+FIELDWIDTH
    SYNCW_Y         = DEVMODE_Y
    BANDW_X         = 0
    BANDW_Y         = DEVMODE_Y+1
    SPREAD_X        = BANDW_X+18
    SPREAD_Y        = BANDW_Y
    IRQFLAGS_X      = 0
    IRQFLAGS_Y      = DEVMODE_Y+3
    MDMSTAT_X       = 0
    MDMSTAT_Y       = IRQFLAGS_Y+1
    RXSTATS_X       = 0
    RXSTATS_Y       = MDMSTAT_Y+3
    CHAN_X          = 0
    CHAN_Y          = MDMSTAT_Y+3
    FIFO_X          = 0
    FIFO_Y          = RXSTATS_Y+10
    FIFO_WIDTH      = TERM_MAX_X-2

    QUERY           = -255

OBJ

    cfg     : "core.con.boardcfg.flip"
    ser     : "com.serial.terminal"
    time    : "time"
    lora    : "wireless.transceiver.sx1276.spi"
    int     : "string.integer"

VAR

    long _isr_stack[50], _keydaemon_stack[50]
    long _fifo[64]
    byte _ser_cog
    byte _keydaemon_cog, _prev_state, _curr_state
    byte _irq_flags, _irq_flags_mask, _last_pkt_bytes

PUB Main | tmp

    Setup
    lora.Channel (0)
    lora.LowFreqMode (FALSE)
    lora.DeviceMode (lora#DEVMODE_SLEEP)
    lora.LongRangeMode (lora#LRMODE_LORA)
    lora.DeviceMode (lora#DEVMODE_STDBY)
    lora.RXBandwidth (125_000)
    lora.SpreadingFactor (128)
    lora.PreambleLength (8)
    lora.CodeRate ($04_05)
    lora.ImplicitHeaderMode (TRUE)
    lora.RXPayloadCRC (TRUE)
    lora.PayloadLength (8)
    lora.PayloadMaxLength (8)
    lora.SyncWord ($12)
    lora.RXTimeout (50)
    ser.Clear

    ser.Position (0, TERM_START_Y+2)    'Rule
    ser.Chars ("-", TERM_MAX_X)

    repeat
        case _curr_state
            DISP_HELP:          Help
            DO_MONITOR:         Monitor
            DO_RX:              Receive
            DO_TX:              Transmit
            SET_DEFAULTS:       SetDefaults
            DISP_SETTINGS:      DisplaySettings
            SET_FREQ:           SetFrequency
            WAITING:            waitkey
            OTHER:
                _curr_state := DISP_HELP

PUB DisplayFIFO | i, col

    ser.Position (FIFO_X, FIFO_Y)
    ser.Str (string("FIFO:[", ser#NL))

    col := FIFO_X
    i := 0
    repeat
        repeat col from FIFO_X to FIFO_WIDTH
            ser.PositionX (col)
            if _fifo.byte[i] => 32 AND _fifo.byte[i] =< 127
                ser.Char (_fifo.byte[i])
            else
                ser.Char (".")
            i++
            if i > 255
                quit
        ser.NewLine
    until i > 255
    ser.Char ("]")

PUB DisplayIRQFlags | i

    ser.Position (IRQFLAGS_X, IRQFLAGS_Y)
'    _irq_flags := %1111_0011    'TESTING
    ser.Str (string("IRQFLAGS: "))
'    ser.Bin (_irq_flags, 8)
'    ser.Str (string("  IRQMASK: "))
'    ser.Bin (_irq_flags_mask, 8)
    repeat i from 7 to 0
        ser.Position ((IRQFLAGS_X + 9 + 1) + ((7-i) * 9), IRQFLAGS_Y)
        ser.Char ("|")
        if _irq_flags & (1 << i)
            case i
                0: ser.Str (string("CADDET  "))
                1: ser.Str (string("FHSSCHG "))
                2: ser.Str (string("CADDONE "))
                3: ser.Str (string("TXDONE  "))
                4: ser.Str (string("VALIDHDR"))
                5: ser.Str (string("PAYLDCRC"))
                6: ser.Str (string("RXDONE  "))
                7: ser.Str (string("RXTMOUT "))
        else
            ser.Str (string("        "))

PUB DisplayModemFlags | mdm_stat, i

    ser.Position (MDMSTAT_X, MDMSTAT_Y)
    mdm_stat := lora.ModemStatus
    ser.Str (string("MDMSTATUS: "))
    repeat i from 4 to 0
        ser.Position ((MDMSTAT_X + 9 + 1) + ((7-i) * 9), MDMSTAT_Y)
        ser.Char ("|")
        if mdm_stat & (1 << i)
            case i
                0: ser.Str (string("SIGNDET "))
                1: ser.Str (string("SIGSYNCH"))
                2: ser.Str (string("RXONGOIN"))
                3: ser.Str (string("HDRVALID"))
                4: ser.Str (string("MDMCLEAR"))
        else
            ser.Str (string("        "))

PUB DisplayRXStats | last_pkt_rssi, last_pkt_snr, last_pkt_crc, last_pkt_bytes, cnt_valid_hdr, cnt_valid_pkt

    last_pkt_rssi := lora.PacketRSSI
    last_pkt_snr := lora.PacketSNR
    last_pkt_crc := lora.LastHeaderCRC
    cnt_valid_hdr := lora.ValidHeadersReceived
    cnt_valid_pkt := lora.ValidPacketsReceived
    last_pkt_bytes := lora.LastPacketBytes

    ser.Position (RXSTATS_X, RXSTATS_Y)
    ser.Str (string("Last packet RSSI: "))
    ser.Str (int.DecPadded (last_pkt_rssi, 4))

    ser.Str (string("  SNR: "))
    ser.Str (int.DecPadded (last_pkt_snr, 4))

    ser.Str (string("  CRC Enabled: "))
    ser.Str (int.DecPadded (last_pkt_crc, 4))
    ser.NewLine

    ser.Str (string("Valid headers received: "))
    ser.Str (int.DecPadded (cnt_valid_hdr, 4))
    ser.NewLine
    ser.Str (string("Valid packets received: "))
    ser.Str (int.DecPadded (cnt_valid_pkt, 4))
    ser.NewLine
    ser.Str (string("Number of bytes last packet: "))
    ser.Str (int.DecPadded (last_pkt_bytes, 4))

PUB DisplaySettings | i, mdm_stat

    ser.Position (DEVMODE_X, DEVMODE_Y)
    case lora.DeviceMode (QUERY)
        0: ser.Str (string("SLEEP       "))
        1: ser.Str (string("STANDBY     "))
        2: ser.Str (string("FSTX        "))
        3: ser.Str (string("TX          "))
        4: ser.Str (string("FSRX        "))
        5: ser.Str (string("RXCONTINUOUS"))
        6: ser.Str (string("RXSINGLE    "))
        7: ser.Str (string("CAD         "))

    ser.Position (LORAMODE_X, LORAMODE_Y)
    case lora.LongRangeMode (QUERY)
        0: ser.Str (string("FSK/OOK     "))
        1: ser.Str (string("LoRa        "))

    ser.Position (FREQ_X, FREQ_Y)
    ser.Str (string("Freq: "))
    ser.Str (int.DecPadded (lora.CarrierFreq (QUERY), 10))

    ser.Position (SYNCW_X, SYNCW_Y)
    ser.Str (string("Syncword: $"))
    ser.Hex (lora.SyncWord (QUERY), 2)

    ser.Position (BANDW_X, BANDW_Y)
    ser.Str (string("Bandwidth: "))
    ser.Dec (lora.RXBandwidth (QUERY))

    ser.Position (SPREAD_X, SPREAD_Y)
    ser.Str (string("SF: "))
    ser.Dec (lora.SpreadingFactor (-2))

'    repeat until _curr_state <> DISP_SETTINGS

PUB Monitor | curr_chan
' XXX non-functional
    curr_chan := 0
    ser.Position (MSG_X, MSG_Y)
    ser.Str (string("Monitor mode"))
    lora.IntMask (%1111_1010)
    lora.DeviceMode (lora#DEVMODE_CAD)
    repeat until _curr_state <> DO_MONITOR
        ser.Position (CHAN_X, CHAN_Y)
        ser.Str (string("Channel "))
        ser.Str (int.DecPadded (curr_chan, 2))
        lora.Channel (curr_chan)
        repeat until lora.Interrupt (0) & %0000_0100    'Wait until CAD done
        lora.Interrupt (%0000_0100)                     'Clear the int
        if lora.Interrupt (0) & %0000_0001
            ser.Position (CHAN_X + (curr_chan*3), CHAN_Y+1)
            ser.Dec (curr_chan)
            lora.Interrupt (%0000_0001)
        curr_chan++
        if curr_chan > 63
            curr_chan := 0

PUB Receive | curr_rssi, min_rssi, max_rssi, len, tmp

    ser.Position (MSG_X, MSG_Y)
    ser.Str (string("Receive mode"))
    lora.IntMask (%1011_1111)
    lora.LNA (0)
    lora.AGC (FALSE)
    lora.DeviceMode (lora#DEVMODE_RXCONTINUOUS)
    min_rssi := lora.RSSI
    max_rssi := min_rssi
    _irq_flags_mask := lora.IntMask (QUERY)
    lora.FIFORXBasePtr ($00)
    repeat until _curr_state <> DO_RX
        _irq_flags := lora.Interrupt (0)
        curr_rssi := lora.RSSI
        DisplayIRQFlags
        DisplayModemFlags
        ser.Position (0, MDMSTAT_Y+2)
        ser.Str (string("Live RSSI (curr/min/max): "))
        min_rssi := curr_rssi <# min_rssi
        max_rssi := curr_rssi #> max_rssi
        ser.Str ( int.DecPadded (curr_rssi, 4))
        ser.Char ("/")
        ser.Str ( int.DecPadded (min_rssi, 4))
        ser.Char ("/")
        ser.Str ( int.DecPadded (max_rssi, 4))

        DisplaySettings
        if _irq_flags & %0100_0000
            len := lora.LastPacketBytes
            lora.FIFOAddrPointer (lora.FIFORXCurrentAddr)
            lora.RXData (len, @_fifo)
            lora.Interrupt (%0100_0000)

            DisplayRXStats
            DisplayFIFO
        if _irq_flags & %0010_0000      ' Payload CRC error
            lora.Interrupt (%0010_0000)

PUB SetDefaults

    ser.Position (MSG_X, MSG_Y)
    ser.Str (string("Set defaults"))
    repeat until _curr_state <> SET_DEFAULTS

PUB SetFrequency

    ser.Position (MSG_X, MSG_Y)
    ser.Str (string("Set frequency"))
    repeat until _curr_state <> SET_FREQ

PUB Transmit | count, tmp

    _fifo.byte[0] := "T"
    _fifo.byte[1] := "E"
    _fifo.byte[2] := "S"
    _fifo.byte[3] := "T"

    lora.RXPayloadCRC (TRUE)
    lora.DIO0 (lora#DIO0_TXDONE)
    lora.IntMask (%1111_0111)       ' Disable all interrupts except TXDONE
    lora.FIFOTXBasePtr ($00)        ' Set the TX FIFO base address to 0
'    tmp := (%1_001 << 4) | 1        ' PA gain - enable PA_BOOST - RFM95W isn't connected to RFO
    tmp := (%0_001 << 4) | 1        ' PA gain - disable PA_BOOST - test anyway
    lora.writeReg ($09, 1, @tmp)    ' |
'    lora.TXMode (lora#TXMODE_NORMAL)

    count := 0
    ser.Position (MSG_X, MSG_Y)
    ser.Str (string("Transmit mode"))
    repeat until _curr_state <> DO_TX
        tmp := int.Hex (count, 4)
        longmove(@_fifo[1], tmp, 1)
        DisplaySettings
        DisplayModemFlags
        DisplayFIFO
        DisplayIRQFlags
        lora.DeviceMode (lora#DEVMODE_STDBY)
        lora.FIFOAddrPointer ($00)  ' Seek to location $00 in the FIFO for subsequent FIFO op
        lora.TXData (8, @_fifo)
        lora.DeviceMode (lora#DEVMODE_TX)
        repeat until lora.Interrupt (0) & %0000_1000        ' Wait until TXDONE asserted
        lora.Interrupt (%0000_1000)                         ' Clear TXDONE
        ser.NewLine
        count++
        ser.Position (0, MDMSTAT_Y+2)
        ser.Str (string("Packets transmitted: "))
        ser.Str (int.DecPadded (count, 5))
        time.MSleep (5000)

PUB Help

    ser.Position (HELP_X, HELP_Y)
    ser.Str (string("Help:", ser#NL))
    ser.Str (string("d  - Set LoRa radio defaults", ser#NL))
    ser.Str (string("h  - This help screen", ser#NL))
    ser.Str (string("m  - Monitor channel activity", ser#NL))
    ser.Str (string("r  - Set role to receiver", ser#NL))
    ser.Str (string("s  - Display settings", ser#NL))
    ser.Str (string("t  - Set role to transmitter", ser#NL))

    repeat until _curr_state <> DISP_HELP

PRI keyDaemon | key_cmd

    repeat
        repeat until key_cmd := ser.CharIn
        case key_cmd
            "d", "D":
                _prev_state := _curr_state
                _curr_state := SET_DEFAULTS

            "h", "H":
                _prev_state := _curr_state
                _curr_state := DISP_HELP

            "m", "M":
                _prev_state := _curr_state
                _curr_state := DO_MONITOR

            "r", "R":
                _prev_state := _curr_state
                _curr_state := DO_RX

            "s", "S":
                _prev_state := _curr_state
                _curr_state := DISP_SETTINGS

            "t", "T":
                _prev_state := _curr_state
                _curr_state := DO_TX

            OTHER:
                if _curr_state == WAITING
                    _curr_state := _prev_state
                else
                    _prev_state := _curr_state
                    _curr_state := DISP_HELP

PRI WaitKey

    _curr_state := WAITING
    ser.Str (string("Press any key to continue", ser#NL))
    repeat until _curr_state <> WAITING
    
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
    _keydaemon_cog := cognew(keyDaemon, @_keydaemon_stack)

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
