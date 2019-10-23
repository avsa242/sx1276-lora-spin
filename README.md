# sx1276-spin
-------------

This is a P8X32A/Propeller driver object for the Semtech SX1276 LoRa/FSK/OOK transceiver.

## Salient Features

* SPI connection at up to 1MHz
* Change transceiver frequency to anything within the SX1276's tunable range (NOTE: Only tested on the 915MHz band)
* Change transceiver frequency by LoRa uplink channel number (NOTE: Currently limited to US/915MHz band)
* Change common transceiver settings, such as: code rate, spreading factor, bandwidth, preamble length, payload length, LNA gain, transmit power
* Change device operating mode, interrupt mask, implicit header mode
* Change DIO pins functionality
* Read live RSSI
* Read packet statistics: last header code rate, last header CRC, last packet number of bytes, last packet RSSI, last packet SNR

## Requirements

* 1 extra core/cog for the PASM SPI driver
* Tested with HopeRF RFM95W (900MHz) module

## Compiler compatibility

- [x] OpenSpin (tested with 1.00.81)
- [ ] ~~FastSpin~~ (FTBFS)

## Limitations

* Very early in development - may malfunction, or outright fail to build
* Channel method is currently limited to US band plan
* Doesn't support the SX1276's FSK/OOK packet radio mode (currently unplanned)
* Doesn't support changing TX power
* Doesn't support FHSS

## TODO
- [x] Implement method to change TX power
- [ ] Write ANSI-compatible terminal version of demo
- [ ] Implement support for other band plans
- [ ] Make settings in the demo runtime changeable
- [ ] Implement FHSS
