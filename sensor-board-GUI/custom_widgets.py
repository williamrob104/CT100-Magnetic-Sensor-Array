import os

import serial.serialutil
import serial.tools.list_ports
from serial import Serial
from PyQt6.QtCore import Qt
from PyQt6.QtGui import QIcon
from PyQt6.QtWidgets import *


class MainWidget(QWidget):
    def __init__(self, serial: Serial, fliplr=False, parent=None):
        super().__init__(parent)
        self.serial = serial

        self.board_config_widget = BoardConfigWidget(self.serial, fliplr)

        layout = QVBoxLayout()
        layout.setSizeConstraint(QLayout.SizeConstraint.SetFixedSize)

        layout.addWidget(PortConnectWidget(serial))
        layout.addWidget(self.board_config_widget)

        self.setLayout(layout)


class PortConnectWidget(QWidget):
    def __init__(self, serial: Serial, parent=None):
        super().__init__(parent)
        self.serial = serial

        self.port_selection_widget = PortComboBoxWidget()
        self.port_selection_widget.setPortName(self.serial.port)

        button = QToolButton()
        button.setIcon(load_icon("connect.png"))
        button.clicked.connect(self.onButtonClicked)

        layout = QHBoxLayout()
        layout.addWidget(self.port_selection_widget)
        layout.addWidget(button)

        self.setLayout(layout)

    def onButtonClicked(self):
        port = self.port_selection_widget.getPortName()
        if self.serial.is_open and self.serial.port == port:
            return

        self.serial.close()
        self.serial.port = port
        self.serial.write_timeout = 0.1
        try:
            self.serial.open()
        except serial.serialutil.SerialException as e:
            self.serial.close()
            display_error_message(str(e))


class PortComboBoxWidget(QComboBox):
    def __init__(self, parent=None):
        super().__init__(parent)
        self.refreshItems()

    def showPopup(self) -> None:
        self.refreshItems()
        return super().showPopup()

    def refreshItems(self):
        self.clear()
        for port in serial.tools.list_ports.comports():
            self.addItem(port.description, port.name)

    def getPortName(self):
        return self.currentData()

    def setPortName(self, port_name):
        idx = self.findData(port_name)
        if idx != -1:
            self.setCurrentIndex(idx)


class BoardConfigWidget(QFrame):
    def __init__(self, serial: Serial, fliplr, parent=None):
        super().__init__(parent)
        self.serial = serial
        self.selected_sensors = [None] * 4
        self.selected_gains   = [None] * 4
        self.sensor_set_widgets = []
        self.gain_set_widgets = []

        lr = fliplr

        layout = QGridLayout()
        layout.setSpacing(3)

        sensor_set_widget = SensorSetWidget(lambda s: self.setSensorOrGain(1, s, None), lr)
        gain_set_widget   = GainSetWidget(  lambda g: self.setSensorOrGain(1, None, g))
        self.sensor_set_widgets.append(sensor_set_widget)
        self.gain_set_widgets.append(gain_set_widget)
        layout.addWidget(QLabel('<b>Channel 1'), 4,3 if lr else 0, 1,2, Qt.AlignmentFlag.AlignCenter)
        layout.addWidget(gain_set_widget,        3,4 if lr else 0)
        layout.addWidget(sensor_set_widget,      3,3 if lr else 1)

        sensor_set_widget = SensorSetWidget(lambda s: self.setSensorOrGain(2, s, None), lr)
        gain_set_widget   = GainSetWidget(  lambda g: self.setSensorOrGain(2, None, g))
        self.sensor_set_widgets.append(sensor_set_widget)
        self.gain_set_widgets.append(gain_set_widget)
        layout.addWidget(QLabel('<b>Channel 2'), 4,0 if lr else 3, 1,2, Qt.AlignmentFlag.AlignCenter)
        layout.addWidget(gain_set_widget,        3,0 if lr else 4)
        layout.addWidget(sensor_set_widget,      3,1 if lr else 3)

        sensor_set_widget = SensorSetWidget(lambda s: self.setSensorOrGain(3, s, None), lr)
        gain_set_widget   = GainSetWidget(  lambda g: self.setSensorOrGain(3, None, g))
        self.sensor_set_widgets.append(sensor_set_widget)
        self.gain_set_widgets.append(gain_set_widget)
        layout.addWidget(QLabel('<b>Channel 3'), 0,3 if lr else 0, 1,2, Qt.AlignmentFlag.AlignCenter)
        layout.addWidget(gain_set_widget,        1,4 if lr else 0)
        layout.addWidget(sensor_set_widget,      1,3 if lr else 1)

        sensor_set_widget = SensorSetWidget(lambda s: self.setSensorOrGain(4, s, None), lr)
        gain_set_widget   = GainSetWidget(  lambda g: self.setSensorOrGain(4, None, g))
        self.sensor_set_widgets.append(sensor_set_widget)
        self.gain_set_widgets.append(gain_set_widget)
        layout.addWidget(QLabel('<b>Channel 4'), 0,0 if lr else 3, 1,2, Qt.AlignmentFlag.AlignCenter)
        layout.addWidget(gain_set_widget,        1,0 if lr else 4)
        layout.addWidget(sensor_set_widget,      1,1 if lr else 3)

        hline = QFrame()
        hline.setFrameShape(QFrame.Shape.HLine)
        layout.addWidget(hline, 2,0,1,5)

        vline = QFrame()
        vline.setFrameShape(QFrame.Shape.VLine)
        layout.addWidget(vline, 0,2,5,1)

        self.setLayout(layout)

    def setSensorOrGain(self, channel, sensor, gain_idx):
        if sensor is not None:
            self.selected_sensors[channel-1] = sensor
        if gain_idx is not None:
            self.selected_gains[channel-1]   = gain_idx

        sensor   = self.selected_sensors[channel-1]
        gain_idx = self.selected_gains[channel-1]

        if sensor is not None and gain_idx is not None:
            b1 = sensor - 1
            b2 = gain_idx << 4
            b3 = (channel - 1) << 6
            b = b1 | b2 | b3
            cmd = b.to_bytes(length=1, byteorder='big')

            try:
                self.serial.write(cmd)
            except serial.serialutil.SerialException as e:
                display_error_message(str(e))

            self.sensor_set_widgets[channel-1].highlightSensor(sensor)
            self.gain_set_widgets[channel-1].highlightGainIndex(gain_idx)

        extra = f" | \t{b:08b}" if 'b' in locals() else ""
        print(f"channel {channel} | sensor {sensor} | gain_idx {gain_idx}" + extra)


class SensorSetWidget(QWidget):
    def __init__(self, set_sensor_func, fliplr, parent=None):
        super().__init__(parent)
        self.buttons = []

        layout = QGridLayout()
        layout.setSpacing(6)
        layout.setContentsMargins(0,0,0,0)
        for i in range(16):
            button = QToolButton()
            button.setText(str(i+1))
            button.clicked.connect(lambda _,i=i: set_sensor_func(i+1))
            button.setFixedSize(20, 20)
            layout.addWidget(button, 3-i//4, 3-i%4 if fliplr else i%4)
            self.buttons.append(button)
        self.setLayout(layout)

    def highlightSensor(self, sensor_num):
        for button in self.buttons:
            button.setStyleSheet("QToolButton")
        self.buttons[sensor_num-1].setStyleSheet(
            "QToolButton { background-color : red; color : black; }")



class GainSetWidget(QWidget):
    def __init__(self, set_gain_func, parent=None):
        super().__init__(parent)

        combobox = QComboBox()
        combobox.addItems(['1', '10', '100', '1000'])
        combobox.activated.connect(lambda idx: set_gain_func(idx))
        set_gain_func(combobox.currentIndex())
        self.combobox = combobox

        layout = QVBoxLayout()
        layout.setSizeConstraint(QLayout.SizeConstraint.SetFixedSize)
        layout.addWidget(QLabel("Gain   "), 0, Qt.AlignmentFlag.AlignCenter)
        layout.addWidget(combobox)
        self.setLayout(layout)

    def highlightGainIndex(self, gain_idx):
        self.combobox.setCurrentIndex(gain_idx)



def display_error_message(text):
    msg = QMessageBox()
    msg.setIcon(QMessageBox.Icon.Critical)
    msg.setText(text)
    msg.setWindowTitle("Error")
    msg.exec()


def load_icon(image_fname) -> QIcon:
    current_dir = os.path.dirname(os.path.realpath(__file__))
    return QIcon(os.path.join(current_dir, 'icons', image_fname))
