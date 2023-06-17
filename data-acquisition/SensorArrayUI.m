classdef SensorArrayUI < matlab.ui.componentcontainer.ComponentContainer

    properties (Access = private)
        panel
        channels
        
    end

    properties (Access = public)
        myhardware
        Enable = "on";
        Tooltip = "";
    end

    methods (Access = protected)

        function setup(ui)
            ui.panel = uipanel(ui);
            ui.panel.BorderType = 'none';
            ui.panel.Position = [0 0 375 299];

            hline = uilabel(ui.panel);
            hline.BackgroundColor = ones(1,3) * 0.3;
            hline.Position = [5 149 365 1];
            vline = uilabel(ui.panel);
            vline.BackgroundColor = ones(1,3) * 0.3;
            vline.Position = [188 5 1 289];

            ui.channels = cell(1,4);
            [ui.channels{1}.sensor_buttons, ui.channels{1}.gain_selector] = AddComponents(ui, 1);
            [ui.channels{2}.sensor_buttons, ui.channels{2}.gain_selector] = AddComponents(ui, 2);
            [ui.channels{3}.sensor_buttons, ui.channels{3}.gain_selector] = AddComponents(ui, 3);
            [ui.channels{4}.sensor_buttons, ui.channels{4}.gain_selector] = AddComponents(ui, 4);

            for k = 1:length(ui.channels)
                ui.channels{k}.sensor = [];
                ui.channels{k}.gain = str2num(ui.channels{k}.gain_selector.Value);
            end
        end

        function update(ui)
            assert(strcmp(ui.Enable,'on') || strcmp(ui.Enable,'off'))
            ui.panel.Enable = ui.Enable;
            ui.panel.Tooltip = ui.Tooltip;
        end
    end

    methods (Access = private)

        function [sensor_buttons, gain_selector] = AddComponents(ui, channel)
            if channel == 1
                offset1 = [ 5  5];
                offset2 = [ 5 67];
                offset3 = [70 32];
            elseif channel == 2
                offset1 = [190  5];
                offset2 = [310 67];
                offset3 = [190 32];
            elseif channel == 3
                offset1 = [ 5 272];
                offset2 = [ 5 187];
                offset3 = [70 152];
            elseif channel == 4
                offset1 = [190 272];
                offset2 = [310 187];
                offset3 = [190 152];
            end

            label = uilabel(ui.panel);
            label.HorizontalAlignment = 'center';
            label.FontWeight = 'bold';
            label.Position = [offset1 190 22];
            label.Text = sprintf('Channel %d', channel);

            dropdown = uidropdown(ui.panel);
            dropdown.Items = {'1', '10', '100', '1000'};
            dropdown.Position = [offset2 60 22];
            dropdown.Value = '1';
            dropdown.ValueChangedFcn = @(~,evt)ui.SetSensorOrGain(channel,[],str2num(evt.Value));
            gain_selector = dropdown;

            label = uilabel(ui.panel);
            label.HorizontalAlignment = 'center';
            label.Position = [offset2 + [0 23] 60 22];
            label.Text = 'Gain';

            sensor_buttons = {};
            for i = 1:16
                button = uibutton(ui.panel, 'push');
                button.VerticalAlignment = 'bottom';
                button.Position = [offset3 + [mod(i-1,4)*30+(1) fix((i-1)/4)*30] 25 25];
                button.Text = string(i);
                button.ButtonPushedFcn = @(~,~)ui.SetSensorOrGain(channel,i,[]);
                sensor_buttons{end+1} = button;
            end
        end

        function SetSensorOrGain(ui, channel, sensor, gain)
            if ~isempty(sensor)
                ui.channels{channel}.sensor = sensor;
            end
            if ~isempty(gain)
                ui.channels{channel}.gain = gain;
            end

            sensor = ui.channels{channel}.sensor;
            gain   = ui.channels{channel}.gain;
            if ~isempty(sensor) && ~isempty(gain)
                confirmed = ui.myhardware.SetSensorAndGain(channel, sensor, gain);

                if isempty(confirmed)
                    errordlg("Sensor board communication serial port is unresponsive")
                elseif ~confirmed
                    errordlg("Sensor board communication serial port has incorrect response")
                else
                    ui.HighlightSensorAndGain(channel, sensor, gain);
                end
            end
        end
        
        function HighlightSensorAndGain(ui, channel, sensor, gain)
            for i = 1:16
                ui.channels{channel}.sensor_buttons{i}.BackgroundColor = ones(1,3) * 0.96;
            end
            ui.channels{channel}.sensor_buttons{sensor}.BackgroundColor = [1 0 0];
            ui.channels{channel}.gain_selector.Value = num2str(gain);
        end
    end

end