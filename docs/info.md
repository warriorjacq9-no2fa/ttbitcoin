<!---

This file is used to generate your project datasheet. Please fill in the information below and delete any unused
sections.

You can also include images in this folder and reference them in the markdown. Each image must be less than
512 kb in size, and the combined size of all images must be less than 1 MB.
-->

## How it works

This project uses a SHA256 engine I wrote to hash Bitcoin blocks provided by an external source. Bitcoin is mined when a Bitcoin miner finds a certain number (the "nonce" or number used once) that causes the double SHA256 hash of the block to be less than a certain number. That number is encoded in the nBits field of the block header, and as of the time of writing is `0x1701fca1` in compact encoding, or `0x00000000000000000001fca100000000000000000000000000000000000000` written out. In the block this was taken from, the nonce was 2,795,227,186. This is obtained only from brute-force, and takes a lot of computation power. The power of a miner is measured in hashes per second. The top miners on the market now get around 2 trillion hashes per second. My Bitcoin miner gets about 81 thousand hashes per second, so it would have taken my miner (without competition) 34,241 seconds, or 9 and a half. So this miner is not very profitable, it is just an educational project.

## How to test

To use this project, you need a program which can provide block templates, usually Bitcoin Core, and you need to find a way to pipe those block templates into the design. The design will input a block template, compute the hash, and output the hash.

All addresses are for 8-bit words

To input a block template to the design listen on RQ for a request and A/DO0..7 for the address. Respond on DI0..7 and pull RDY high. Send bytes according to this memory map:

| Address range | Data |
| ------- | ---- |
| 0x00-0x03 | Version |
| 0x04-0x23 | Prev. block |
| 0x24-0x43 | Merkle root |
| 0x44-0x47 | Timestamp |
| 0x48-0x4B | nBits |
| 0x4C-0x4F | Zero or starting nonce |

When DONE goes high, the hash will be outputted on A/DO0..7 one byte at a time, with the first byte being the most significant byte.

In this state, RDY is used as a data acknowledge input after each byte, and RQ is used as a data-ready signal. DONE will go low when there is no data left.

## External hardware

A computer capable of running Bitcoin Core and a microcontroller capable of interfacing the computer with the device