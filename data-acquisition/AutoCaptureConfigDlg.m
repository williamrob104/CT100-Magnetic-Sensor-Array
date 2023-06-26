function [sensor_gains, tf] = AutoCaptureConfigDlg(sensor_gains)

    tf = false;

    if numel(sensor_gains) ~= 64
        sensor_gains = ones(1,64);
    end

    gains  = [1 10 100 1000];
    colors = {[0 0.4470 0.7410] [0.8500 0.3250 0.0980] [0.9290 0.6940 0.1250] [0.4940 0.1840 0.5560]};

    fig = uifigure('Name','Acquire data configuration', 'Position',[800 400 430 400], 'WindowStyle','modal', 'Resize','off');

    offset = [50 100];
    for channel = 1:4
        for sensor = 1:16
            i = (channel - 1) * 16 + sensor;
            x = mod( sensor-1,   4) + 4 * mod( channel-1,   2);
            y = fix((sensor-1) / 4) + 4 * fix((channel-1) / 2);
            button = uibutton(fig, 'Position',[[x*30 y*30] + offset 25 25], 'Text',num2str(sensor));
            setappdata(button, 'i',i);
            button.BackgroundColor = colors{gains == sensor_gains(i)};
            button.ButtonPushedFcn = @SensorButtonPushed;
        end
        x = mod( channel-1,   2);
        y = fix((channel-1) / 2);
        label = uilabel(fig, 'Text',sprintf('Channel %d',channel), ...
            'HorizontalAlignment','center', 'FontWeight','bold', ...
            'Position',[[x*113 y*267] - [0 27] + offset 112 22]);
    end
    hline = uilabel(fig);
    hline.BackgroundColor = ones(1,3) * 0.3;
    hline.Position = [[-5 117] + offset 245 1];
    vline = uilabel(fig);
    vline.BackgroundColor = ones(1,3) * 0.3;
    vline.Position = [[117 -27] + offset 1 289];

    offset = [320 270];
    label = uilabel(fig, 'Text','Gain', 'HorizontalAlignment','center', 'FontWeight','bold', 'Position',[offset 50 22]);
    for k = 1:length(gains)
        label = uilabel(fig, 'Position',[[0 -27*k] + offset 30 22],  'Text','', 'BackgroundColor',colors{k});
        label = uilabel(fig, 'Position',[[35 -27*k] + offset 30 22], 'Text',num2str(gains(k)));
    end

    button = uibutton(fig, 'Position',[117 30 100 22], 'Text','Ok');
    button.ButtonPushedFcn = @OkButtonPushed;
       
    % Wait for fig to close before running to completion
    uiwait(fig);
   
    function SensorButtonPushed(button, ~)
        i = getappdata(button, 'i');
        k = find(gains == sensor_gains(i));
        k = mod(k, length(gains)) + 1;
        sensor_gains(i) = gains(k);
        button.BackgroundColor = colors{k};
    end

    function OkButtonPushed(~,~)
        tf = true;
        close(fig);
    end
end