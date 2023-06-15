classdef MyHardware

    properties (Access = private)
        analog_out
        analog_in
        digital_out_relay
    end

    methods (Access = public)

        function myhardware = MyHardware()
            deviceID = "Dev1";

            % configure analog output
            dq = daq("ni");
            addoutput(dq, deviceID, "ao0", "Voltage")
            dq.Rate = dq.RateLimit(2);
            myhardware.analog_out = dq;

            % configure analog input
            dq = daq("ni");
            ch = addinput(dq, deviceID, "ai0", "Voltage");  ch.TerminalConfig = "Differential";
            ch = addinput(dq, deviceID, "ai1", "Voltage");  ch.TerminalConfig = "Differential";
            ch = addinput(dq, deviceID, "ai2", "Voltage");  ch.TerminalConfig = "Differential";
            ch = addinput(dq, deviceID, "ai3", "Voltage");  ch.TerminalConfig = "Differential";
            ch = addinput(dq, deviceID, "ai4", "Voltage");  ch.TerminalConfig = "Differential";
            dq.Rate = dq.RateLimit(2);
            myhardware.analog_in = dq;

            % configure analog output
            dq = daq("ni");
            warning('off', 'daq:Session:onDemandOnlyChannelsAdded')
            addoutput(dq, deviceID, "port1/line7", "Digital")
            warning('on', 'daq:Session:onDemandOnlyChannelsAdded')
            myhardware.digital_out_relay = dq;
        end

        function delete(myhardware)
            AnalogOutputStop(myhardware)
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
    end

end