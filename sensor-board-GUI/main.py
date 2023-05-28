import argparse

import serial
from PyQt6.QtWidgets import QApplication

import custom_widgets

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--flip",
        action="store_const",
        const=True,
        default=False,
        help="Flip user interface as if viewing from another side of the sensor board",
    )
    args = parser.parse_args()

    ser = serial.Serial()
    ser.baudrate = 9600

    app = QApplication([])
    app.setApplicationName("Magnetic Sensor Array")
    app.setWindowIcon
    app.setStyle("fusion")

    widget = custom_widgets.MainWidget(ser, args.flip)
    widget.show()

    app.exec()
