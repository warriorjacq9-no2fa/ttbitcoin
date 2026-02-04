# Bitcoin miner for TinyTapeout

This project is a multi-core Bitcoin miner using a SHA256 engine I wrote from scratch. It takes 192 clock cycles per hash, and each block takes 3 hash cycles, two for the block itself, and one to hash the intermediate hash, as per Bitcoin protocol. This gives a throughput of 576 cycles/hash, or about 347 KH/s with a 200 MHz clock.
If TinyTapeout supported it, we could use the SKY130 high-speed standard cell library, giving our die a mox clock of about 400 MHz, or 694 KH/s. Still not competitive though.