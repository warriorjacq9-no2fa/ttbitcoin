<!---

This file is used to generate your project datasheet. Please fill in the information below and delete any unused
sections.

You can also include images in this folder and reference them in the markdown. Each image must be less than
512 kb in size, and the combined size of all images must be less than 1 MB.
-->

## How it works

This project uses a SHA256 engine I wrote to mine Bitcoin blocks provided by an external source. Bitcoin is mined when a Bitcoin miner finds a certain number (the "nonce" or number used once) that causes the double SHA256 hash of the block to be less than a certain number. That number is encoded in the nBits field of the block header, and as of the time of writing is `0x1701fca1` in compact encoding, or `0x00000000000000000001fca100000000000000000000000000000000000000` written out. In the block this was taken from, the nonce was 2,795,227,186. This is obtained only from brute-force, and takes a lot of computation power. The power of a miner is measured in hashes per second. The top miners on the market now get around 2 TH/s. My Bitcoin miner gets about 347 KH/s, so it would have taken my miner (without competition) 4,025 seconds, or 1 hour. So this miner is not very profitable, it is just an educational project.

## How to test

To use this project, you need a program which can provide block templates, usually Bitcoin Core, and you need to find a way to pipe those block templates into the design. The design will input a block template, compute the nonce, and output the nonce.
| Pin | Description |
| --- | ----------- |
| DI/O0..7 | Bidirectional data bus |
| DI8..14 | High byte of data input bus |
| DI15/LATCH | Functions as data strobe when RQ is active |
| A0..5 | address output bus |
| DONE | Signals block completion, active high |
| RQ | Signals data request, active high |

All addresses are for 16-bit words

To input a block template to the design listen on A0..5. Respond on DI/O0..7 and DI8..15 and hold LATCH high to input a byte. Send bytes according to this memory map:

| Address range | Data |
| ------- | ---- |
| 0x00-0x01 | Version |
| 0x02-0x12 | Prev. block |
| 0x12-0x22 | Merkle root |
| 0x22-0x23 | Timestamp |
| 0x24-0x25 | nBits |
| 0x26-0x27 | Zero or starting nonce |

When DONE goes high, the nonce will be outputted on DI/O0..7 according to this memory map:

| Address | Data |
| ------- | ---- |
| 0x00 | Bits 0-7 |
| 0x01 | Bits 8-15 |
| 0x02 | Bits 15-23 |
| 0x03 | Bits 24-31 |

In this state, LATCH is used as a data acknowledge input after each byte, and RQ is used as a data-ready signal

## External hardware

A computer capable of running Bitcoin Core and a microcontroller capable of interfacing the two