# sx1276-lora-spin
-------------

This is a P8X32A/Propeller, P2X8C4M64P/Propeller 2 driver object for the Semtech SX1276 LoRa/FSK/OOK transceiver (LoRa mode only)

**IMPORTANT**: This software is meant to be used with the [spin-standard-library](https://github.com/avsa242/spin-standard-library) (P8X32A) or [p2-spin-standard-library](https://github.com/avsa242/p2-spin-standard-library) (P2X8C4M64P). Please install the applicable library first before attempting to use this code, otherwise you will be missing several files required to build the project.

## Salient Features

* SPI connection at up to 1MHz (P1), 10MHz (P2)
* Change transceiver frequency to anything within the SX1276's tunable range
* Change transceiver frequency by LoRa uplink channel number
* Change common transceiver settings, such as: code rate, spreading factor, bandwidth, preamble length, payload length, LNA gain, transmit power
* Change device operating mode, interrupt mask, implicit header mode
* Change DIO pins functionality
* Read live RSSI
* Read packet statistics: last header code rate, last header CRC, last packet number of bytes, last packet RSSI, last packet SNR

## Requirements

P1/SPIN1:
* spin-standard-library
* P1: 1 extra core/cog for the PASM SPI engine

P2/SPIN2:
* p2-spin-standard-library

## Compiler Compatibility

| Processor | Language | Compiler               | Backend     | Status                |
|-----------|----------|------------------------|-------------|-----------------------|
| P1        | SPIN1    | FlexSpin (5.9.14-beta) | Bytecode    | OK                    |
| P1        | SPIN1    | FlexSpin (5.9.14-beta) | Native code | OK                    |
| P1        | SPIN1    | OpenSpin (1.00.81)     | Bytecode    | Untested (deprecated) |
| P2        | SPIN2    | FlexSpin (5.9.14-beta) | NuCode      | Untested              |
| P2        | SPIN2    | FlexSpin (5.9.14-beta) | Native code | OK                    |
| P1        | SPIN1    | Brad's Spin Tool (any) | Bytecode    | Unsupported           |
| P1, P2    | SPIN1, 2 | Propeller Tool (any)   | Bytecode    | Unsupported           |
| P1, P2    | SPIN1, 2 | PNut (any)             | Bytecode    | Unsupported           |

## Limitations

* Channel() method is currently limited to US band plan (due to local hardware on-hand)
* Doesn't support the SX1276's FSK/OOK packet radio mode - see sx1276-spin
* Doesn't support FHSS

