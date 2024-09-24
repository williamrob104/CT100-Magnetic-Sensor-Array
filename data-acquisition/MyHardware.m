classdef MyHardware

    properties (Access = private)
        analog_out
        analog_in
        serial_relay
        serial_sensor
    end

    properties (SetAccess = private)
        error_analog_out
        error_analog_in
        error_serial_sensor
        error_serial_relay

        AnalogOutputRate
        AnalogInputRate
        SerialSensorName
        SerialRelayName
    end

    methods (Access = public)

        function myhardware = MyHardware()
            % configure analog output
            try
                dq = daq("ni");
                deviceID = "cDAQ1Mod6";
                addoutput(dq, deviceID, "ao0", "Voltage")
                dq.Rate = dq.RateLimit(2);
                myhardware.analog_out = dq;
                myhardware.AnalogOutputRate = dq.Rate;
            catch err
                myhardware.error_analog_out = err.message;
            end

            % configure analog input
            try
                dq = daq("ni");
                deviceID = "cDAQ1Mod7";
                ch = addinput(dq, deviceID, "ai0", "Voltage");  ch.TerminalConfig = "Differential";
                ch = addinput(dq, deviceID, "ai1", "Voltage");  ch.TerminalConfig = "Differential";
                ch = addinput(dq, deviceID, "ai2", "Voltage");  ch.TerminalConfig = "Differential";
                ch = addinput(dq, deviceID, "ai3", "Voltage");  ch.TerminalConfig = "Differential";
                ch = addinput(dq, deviceID, "ai4", "Voltage");  ch.TerminalConfig = "Differential";
                dq.Rate = dq.RateLimit(2);
                myhardware.analog_in = dq;
                myhardware.AnalogInputRate = dq.Rate;
            catch err
                myhardware.error_analog_in = err.message;
            end

            % configure serial port for sensor array
            try
                friendlyName = "USB Serial Port";
                myhardware.serial_sensor = MyHardware.connectToSerialPort(friendlyName, 115200, 'Timeout',0.1);
                myhardware.SerialSensorName = sprintf("%s (%s)", friendlyName, myhardware.serial_sensor.Port);
            catch err
                myhardware.error_serial_sensor = err.message;
            end

            % configure serial port for relay
            try
                friendlyName = "USB-SERIAL CH340";
                myhardware.serial_relay = MyHardware.connectToSerialPort(friendlyName, 9600, 'Timeout',0.1);
                myhardware.SerialRelayName = sprintf("%s (%s)", friendlyName, myhardware.serial_sensor.Port);
            catch err
                myhardware.error_serial_relay = err.message;
            end
        end

        function delete(myhardware)
            try myhardware.AnalogOutputStop(), catch, end
            try myhardware.AnalogInputStop(),  catch, end
            try myhardware.SwitchRelay(false), catch, end
            myhardware.serial_sensor = [];
            myhardware.serial_relay = [];
        end

        function AnalogOutputContinuous(myhardware, expr)
            myhardware.AnalogOutputStop();
            rate = myhardware.analog_out.Rate;

            expr = insertBefore(expr, newline, ';');
            expr = strcat(expr, ';');

            start_t = 0;
            t = linspace(start_t, start_t+1, rate+1).'; t = t(1:end-1);
            y = [];
            eval(expr);
            if ~all(size(y) == [rate 1])
                error('"y" does not match the size of "t"')
            end
            preload(myhardware.analog_out, y)

            function loadMoreData(obj, ~)
                start_t = start_t + 1;
                t = linspace(start_t, start_t+1, rate+1).'; t = t(1:end-1);
                eval(expr);
                assert(all(size(y) == [rate 1]))
                write(obj, y)
            end

            myhardware.analog_out.ScansRequiredFcn = @loadMoreData;
            start(myhardware.analog_out, "Continuous")
        end

        function AnalogOutputStop(myhardware)
            stop(myhardware.analog_out)
            flush(myhardware.analog_out)
            write(myhardware.analog_out, 0)
        end

        function [t,src,ch1,ch2,ch3,ch4] = AnalogInputSingle(myhardware, span)
            [data,t,~] = read(myhardware.analog_in, span, "OutputFormat","Matrix");
            src = data(:,1);
            ch1 = data(:,2);
            ch2 = data(:,3);
            ch3 = data(:,4);
            ch4 = data(:,5);
        end

        function AnalogInputContinuous(myhardware, span, callback)
            myhardware.AnalogInputStop();
            if isa(span, 'duration')                
                count = seconds(span) * myhardware.analog_in.Rate;
            else
                count = span;
            end
            count = max(count, myhardware.analog_in.Rate * 0.1);
            myhardware.analog_in.ScansAvailableFcnCount = count;

            function handleMoreData(obj, ~)
                [data,t,~] = read(obj, obj.ScansAvailableFcnCount, "OutputFormat","Matrix");
                callback(t, data(:,1), data(:,2), data(:,3), data(:,4), data(:,5));
            end

            myhardware.analog_in.ScansAvailableFcn = @handleMoreData;
            start(myhardware.analog_in, "Continuous")
        end

        function AnalogInputStop(myhardware)
            stop(myhardware.analog_in)
            flush(myhardware.analog_in)
        end

        function SwitchRelay(myhardware, bool)
            if bool
                write(myhardware.serial_relay, [0xA0 0x01 0x01 0xA2], "uint8")
            else
                write(myhardware.serial_relay, [0xA0 0x01 0x00 0xA1], "uint8")
            end
        end

        function confirmation = SetSensorAndGain(myhardware, channel, sensor, gain)
            byte = MyHardware.ChannelSensorGain2Cmd(channel, sensor, gain);
            try
                flush(myhardware.serial_sensor, "input")
                write(myhardware.serial_sensor, byte, "uint8")
    
                warning('off', 'serialport:serialport:ReadWarning')
                echo = read(myhardware.serial_sensor, 1, "uint8");
                warning('on',  'serialport:serialport:ReadWarning')
                confirmation = (byte == echo);
            catch
                confirmation = [];
            end
        end

        function confirmation = SetAllSensorAndGain(myhardware, ...
                channel1_sensor, channel1_gain, channel2_sensor, channel2_gain, ...
                channel3_sensor, channel3_gain, channel4_sensor, channel4_gain)
            byte1 = MyHardware.ChannelSensorGain2Cmd(1, channel1_sensor, channel1_gain);
            byte2 = MyHardware.ChannelSensorGain2Cmd(2, channel2_sensor, channel2_gain);
            byte3 = MyHardware.ChannelSensorGain2Cmd(3, channel3_sensor, channel3_gain);
            byte4 = MyHardware.ChannelSensorGain2Cmd(4, channel4_sensor, channel4_gain);
            bytes = [byte1 byte2 byte3 byte4];
            try
                flush(myhardware.serial_sensor, "input")
                write(myhardware.serial_sensor, bytes, "uint8")
    
                warning('off', 'serialport:serialport:ReadWarning')
                echos = read(myhardware.serial_sensor, 4, "uint8");
                warning('on',  'serialport:serialport:ReadWarning')
                if ~isempty(echos)
                    confirmation = (length(bytes) == length(echos)) && all(bytes == echos);
                else
                    confirmation = [];
                end
            catch
                confirmation = [];
            end
        end
    end

    methods (Access = private, Static)

        function byte = ChannelSensorGain2Cmd(channel, sensor, gain)
            assert(1 <= channel && channel <= 4)
            assert(1 <= sensor && sensor <= 16)
            assert(gain == 1 || gain == 10 || gain == 100 || gain == 1000)

            if     gain == 1,    gain_idx = uint8(0);
            elseif gain == 10,   gain_idx = uint8(1);
            elseif gain == 100,  gain_idx = uint8(2);
            elseif gain == 1000, gain_idx = uint8(3);
            end

            byte = bitor( bitshift(uint8(channel-1),6), bitshift(gain_idx,4) );
            byte = bitor( byte                        , uint8(sensor-1)      );
        end

        function serial = connectToSerialPort(friendlyName, baud, varargin)
            port = [];
            devices = IDSerialComs();
            for i = 1:size(devices,1)
                if strcmp(devices{i,1}, friendlyName)
                    if isempty(port)
                        port = sprintf("COM%d", devices{i,2});
                    else
                        error('Multiple serial ports with the name "%s"', friendlyName)
                    end
                end
            end

            if isempty(port)
                error('Cannot find serial port with the name "%s"', friendlyName)
            else
                serial = serialport(port, baud, varargin{:});
            end
        end

    end

end