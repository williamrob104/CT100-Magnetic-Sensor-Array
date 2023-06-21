## UART interface

The UART interface uses a baud of 115200. Each byte `c` received on the RX end is parsed as follows.

`c[7:6]` represents the channel number\
`c[5:4]` represents the gain on that channel\
`c[3:0]` represents the sensor which the channel is switched to

When the gain setting and sensor switching is finished, the same byte is echoed on the TX end.
