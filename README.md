# Bitcoin miner for TinyTapeout

This project is a multi-core Bitcoin miner using a SHA256 engine I wrote from scratch. It takes a total of 541 clock cycles per block hash. This gives a throughput of  about 369.7 KH/s with a 200 MHz clock.
If TinyTapeout supported it, we could use the SKY130 high-speed standard cell library, giving our die a max clock of about 400 MHz, or 736 KH/s. Still not competitive though.