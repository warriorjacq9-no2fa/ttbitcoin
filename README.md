[![push](https://github.com/warriorjacq9-no2fa/ttbitcoin/actions/workflows/push.yaml/badge.svg)](https://github.com/warriorjacq9-no2fa/ttbitcoin/actions/workflows/push.yaml)
# Bitcoin miner for TinyTapeout

This project is a single-core Bitcoin miner using a SHA256 engine I wrote from scratch. It takes a total of 980 clock cycles per block hash. This gives a throughput of about 81.6 KH/s with an 80 MHz clock. It uses a 4-round unrolled SHA256 core and a basic 8/16-bit bus interface.