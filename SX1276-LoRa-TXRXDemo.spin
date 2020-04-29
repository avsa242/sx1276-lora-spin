{
    --------------------------------------------
    Filename: SX1276-LoRa-TXRXDemo.spin
    Author: Jesse Burt
    Description: Demo of the SX1276 driver
    Copyright (c) 2020
    Started Oct 6, 2019
    Updated Apr 29, 2020
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
    CYCLE_BW        = 7
    CYCLE_SPREAD    = 8
    CHANGE_SYNCW    = 9
    DEC_TXPWR       = 10
    INC_TXPWR       = 11
    CYCLE_RFOUT     = 12
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
    TXPOWER_X       = SPREAD_X+10
    TXPOWER_Y       = BANDW_Y
    RFOUTPIN_X      = TXPOWER_X+17
    RFOUTPIN_Y      = TXPOWER_Y
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
    byte _rf_outpin

PUB Main | tmp

    Setup
    lora.LongRangeMode (lora#LRMODE_LORA)

'    _rf_outpin := lora#PAOUT_RFO        '       -1..14 with PAOUT_RFO
'    lora.TXPower (-1, _rf_outpin)

    _rf_outpin := lora#PAOUT_PABOOST   '       5..20, 21..23 with PAOUT_PABOOST
    lora.TXPower (5, _rf_outpin)

    lora.Channel (0)
    lora.LowFreqMode (FALSE)
    lora.RXBandwidth (125000)
    lora.SpreadingFactor (128)
    lora.PreambleLength (8)
    lora.CodeRate ($04_05)
    lora.ImplicitHeaderMode (FALSE)
    lora.PayloadLength (8)
    lora.PayloadMaxLength (8)
    lora.SyncWord ($12)
    lora.RXTimeout (100)
    ser.Clear

    ser.Position (0, TERM_START_Y+2)    'Rule
    ser.Chars ("-", TERM_MAX_X)

    repeat
        case _curr_state
            DISP_HELP:          Help
            DO_RX:              Receive
            DO_TX:              Transmit
            SET_DEFAULTS:       SetDefaults
            DISP_SETTINGS:      DisplaySettings
            SET_FREQ:           SetFrequency
            CYCLE_BW:           CycleBandwidth
            CYCLE_SPREAD:       CycleSpreadFactor
            CHANGE_SYNCW:       ChangeSyncWord
            DEC_TXPWR:          DecreaseTXPwr
            INC_TXPWR:          IncreaseTXPwr
            CYCLE_RFOUT:        CycleRFOut
            WAITING:            waitkey
            OTHER:
                _curr_state := DISP_HELP

PUB ChangeSyncWord | tmp

    ser.Position (SYNCW_X+11, SYNCW_Y)
    ser.Flush
    tmp := ser.HexIn
    if tmp => $00 and tmp =< $FF
        lora.SyncWord (tmp)
    _curr_state := _prev_state
    return

PUB CycleBandwidth | tmp

    tmp := lora.RXBandwidth (QUERY)
    case tmp
        7800:
            lora.RXBandwidth (10_400)
        10_400:
            lora.RXBandwidth (15_600)
        15_600:
            lora.RXBandwidth (20_800)
        20_800:
            lora.RXBandwidth (31_250)
        31_250:
            lora.RXBandwidth (41_700)
        41_700:
            lora.RXBandwidth (62_500)
        62_500:
            lora.RXBandwidth (125_000)
        125_000:
            lora.RXBandwidth (250_000)
        250_000:
            lora.RXBandwidth (500_000)
        500_000:
            lora.RXBandwidth (7_800)
        OTHER:
            lora.RXBandwidth (125_000)

    _curr_state := _prev_state
    return

PUB CycleRFOut | tmp

    case _rf_outpin
        lora#PAOUT_RFO:
            _rf_outpin := lora#PAOUT_PABOOST
        lora#PAOUT_PABOOST:
            _rf_outpin := lora#PAOUT_RFO
        OTHER:
            _rf_outpin := lora#PAOUT_RFO
    lora.TXPower (5, _rf_outpin)
    _curr_state := _prev_state
    return

PUB CycleSpreadFactor | tmp

    tmp := lora.SpreadingFactor (QUERY)
    case tmp
        64:
            lora.SpreadingFactor (128)
        128:
            lora.SpreadingFactor (256)
        256:
            lora.SpreadingFactor (512)
        512:
            lora.SpreadingFactor (1024)
        1024:
            lora.SpreadingFactor (2048)
        2048:
            lora.SpreadingFactor (4096)
        4096:
            lora.SpreadingFactor (64)
        OTHER:
            lora.SpreadingFactor (128)

    _curr_state := _prev_state
    return

PUB DecreaseTXPwr | tmp

    tmp := $00
    tmp := lora.TXPower (QUERY, _rf_outpin)
    case _rf_outpin
        lora#PAOUT_RFO:
            if tmp > -1
                tmp--
                lora.TXPower (tmp, _rf_outpin)
            else
                lora.TXPower (14, _rf_outpin)

        lora#PAOUT_PABOOST:
            if tmp > 5
                tmp--
                lora.TXPower (tmp, _rf_outpin)
            else
                lora.TXPower (23, _rf_outpin)
    _curr_state := _prev_state
    return

PUB IncreaseTXPwr | tmp

    tmp := $00
    tmp := lora.TXPower (QUERY, _rf_outpin)
    case _rf_outpin
        lora#PAOUT_RFO:
            if tmp < 14
                tmp++
                lora.TXPower (tmp, _rf_outpin)
            else
                lora.TXPower (-1, _rf_outpin)

        lora#PAOUT_PABOOST:
            if tmp < 23
                tmp++
                lora.TXPower (tmp, _rf_outpin)
            else
                lora.TXPower (5, _rf_outpin)
    _curr_state := _prev_state
    return

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

PUB DisplayRXStats | last_pkt_rssi, last_pkt_snr, last_pkt_crc, last_pkt_bytes, last_coderate, cnt_valid_hdr, cnt_valid_pkt

    last_pkt_rssi := lora.PacketRSSI
    last_pkt_snr := lora.PacketSNR
    last_pkt_crc := lora.LastHeaderCRC
    last_coderate := lora.LastHeaderCodingRate
    cnt_valid_hdr := lora.ValidHeadersReceived
    cnt_valid_pkt := lora.ValidPacketsReceived
    last_pkt_bytes := lora.LastPacketBytes

    ser.Position (RXSTATS_X, RXSTATS_Y)
    ser.Str (string("Last packet RSSI: "))
    ser.Str (int.DecPadded (last_pkt_rssi, 4))

    ser.Str (string("  SNR: "))
    ser.Str (int.DecPadded (last_pkt_snr, 4))

    ser.Str (string("  Code Rate: "))
    ser.Str (int.Hex (last_coderate, 4))

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
    case lora.OpMode (QUERY)
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
    ser.Str (int.DecPadded (lora.RXBandwidth (QUERY), 6))

    ser.Position (SPREAD_X, SPREAD_Y)
    ser.Str (string("SF: "))
    ser.Str (int.DecPadded (lora.SpreadingFactor (QUERY), 4))

    if _curr_state == DO_TX
        ser.Position (TXPOWER_X, TXPOWER_Y)
        ser.Str (string("TXPower: "))
        ser.Str (int.DecPadded (lora.TXPower (QUERY, _rf_outpin), 3))
        ser.Str (string("dBm"))
        ser.Position (RFOUTPIN_X, RFOUTPIN_Y)
        ser.Str (string("RFOutpin: "))
        case _rf_outpin
            lora#PAOUT_RFO:
                ser.Str (string("RFO    "))
            lora#PAOUT_PABOOST:
                ser.Str (string("PABOOST"))

PUB Receive | curr_rssi, min_rssi, max_rssi, len, tmp

    ser.Position (MSG_X, MSG_Y)
    ser.Str (string("Receive mode"))
    lora.IntMask (%1011_1111)
    lora.LNAGain (0)
    lora.AGCMode (FALSE)
    lora.OpMode (lora#DEVMODE_RXCONTINUOUS)
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
            lora.RXPayload (len, @_fifo)
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

    lora.CRCCheckEnabled (TRUE)
    lora.GPIO0 (lora#DIO0_TXDONE)
    lora.IntMask (%1111_0111)       ' Disable all interrupts except TXDONE
    lora.FIFOTXBasePtr ($00)        ' Set the TX FIFO base address to 0

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
        lora.OpMode (lora#DEVMODE_STDBY)
        lora.FIFOAddrPointer ($00)  ' Seek to location $00 in the FIFO for subsequent FIFO op
        lora.TXPayload (8, @_fifo)
        lora.OpMode (lora#DEVMODE_TX)
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
    ser.Str (string("b  - Change bandwidth", ser#NL))
    ser.Str (string("d  - Set LoRa radio defaults", ser#NL))
    ser.Str (string("h  - This help screen", ser#NL))
    ser.Str (string("p  - Decrease TX power", ser#NL))
    ser.Str (string("P  - Increase TX power", ser#NL))
    ser.Str (string("r  - Set role to receiver", ser#NL))
    ser.Str (string("s  - Change spreading factor", ser#NL))
    ser.Str (string("t  - Set role to transmitter", ser#NL))
    ser.Str (string("y  - Change syncword", ser#NL))

    repeat until _curr_state <> DISP_HELP

PRI keyDaemon | key_cmd

    repeat
        repeat until key_cmd := ser.CharIn
        case key_cmd
            "b", "B":
                _prev_state := _curr_state
                _curr_state := CYCLE_BW
                repeat until _curr_state <> CYCLE_BW

            "d", "D":
                _prev_state := _curr_state
                _curr_state := SET_DEFAULTS
                repeat until _curr_state <> SET_DEFAULTS

            "h", "H":
                _prev_state := _curr_state
                _curr_state := DISP_HELP
                repeat until _curr_state <> DISP_HELP

            "o", "O":
                _prev_state := _curr_state
                _curr_state := CYCLE_RFOUT
                repeat until _curr_state <> CYCLE_RFOUT

            "p":
                _prev_state := _curr_state
                _curr_state := DEC_TXPWR
                repeat until _curr_state <> DEC_TXPWR

            "P":
                _prev_state := _curr_state
                _curr_state := INC_TXPWR
                repeat until _curr_state <> INC_TXPWR

            "r", "R":
                _prev_state := _curr_state
                _curr_state := DO_RX
                repeat until _curr_state <> DO_RX

            "s", "S":
                _prev_state := _curr_state
                _curr_state := CYCLE_SPREAD
                repeat until _curr_state <> CYCLE_SPREAD

            "t", "T":
                _prev_state := _curr_state
                _curr_state := DO_TX

            "y", "Y":
                _prev_state := _curr_state
                _curr_state := CHANGE_SYNCW
                repeat until _curr_state <> CHANGE_SYNCW

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
