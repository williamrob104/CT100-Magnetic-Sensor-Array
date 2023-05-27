import serial
from PyQt6.QtWidgets import QApplication

import custom_widgets

flip_left_right = False

ser = serial.Serial()
ser.baudrate = 9600

app = QApplication([])
app.setApplicationName("Magnetic Sensor Array")
app.setWindowIcon
app.setStyle("fusion")

widget = custom_widgets.MainWidget(ser, flip_left_right)
widget.show()

app.exec()
