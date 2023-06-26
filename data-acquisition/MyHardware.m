classdef MyHardware

    properties (Access = private)
        analog_out
        analog_in
        digital_out_relay
        serial
    end

    properties (SetAccess = private)
        AnalogOutputRate
        AnalogInputRate
    end

    methods (Access = public)

        function myhardware = MyHardware(port)
            deviceID = "Dev1";

            % configure analog output
            dq = daq("ni");
            addoutput(dq, deviceID, "ao0", "Voltage")
            dq.Rate = dq.RateLimit(2);
            myhardware.analog_out = dq;
            myhardware.AnalogOutputRate = dq.Rate;

            % configure analog input
            dq = daq("ni");
            ch = addinput(dq, deviceID, "ai0", "Voltage");  ch.TerminalConfig = "Differential";
            ch = addinput(dq, deviceID, "ai1", "Voltage");  ch.TerminalConfig = "Differential";
            ch = addinput(dq, deviceID, "ai2", "Voltage");  ch.TerminalConfig = "Differential";
            ch = addinput(dq, deviceID, "ai3", "Voltage");  ch.TerminalConfig = "Differential";
            ch = addinput(dq, deviceID, "ai4", "Voltage");  ch.TerminalConfig = "Differential";
            dq.Rate = dq.RateLimit(2);
            myhardware.analog_in = dq;
            myhardware.AnalogInputRate = dq.Rate;

            % configure analog output
            dq = daq("ni");
            warning('off', 'daq:Session:onDemandOnlyChannelsAdded')
            addoutput(dq, deviceID, "port1/line7", "Digital")
            warning('on', 'daq:Session:onDemandOnlyChannelsAdded')
            myhardware.digital_out_relay = dq;

            % configure serial port
            if nargin >= 1
                myhardware.serial = serialport(port, 115200, 'Timeout',0.1);
            end
        end

        function delete(myhardware)
            myhardware.serial = [];
            myhardware.AnalogOutputStop()
            myhardware.AnalogInputStop()
            myhardware.SwitchRelay(false)
        end

        function SwitchRelay(myhardware, bool)
            write(myhardware.digital_out_relay, logical(bool))
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

        function confirmation = SetSensorAndGain(myhardware, channel, sensor, gain)
            byte = MyHardware.ChannelSensorGain2Cmd(channel, sensor, gain);
            try
                flush(myhardware.serial, "input")
                write(myhardware.serial, byte, "uint8")
    
                warning('off', 'serialport:serialport:ReadWarning')
                echo = read(myhardware.serial, 1, "uint8");
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
                flush(myhardware.serial, "input")
                write(myhardware.serial, bytes, "uint8")
    
                warning('off', 'serialport:serialport:ReadWarning')
                echos = read(myhardware.serial, 4, "uint8");
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
    end

end