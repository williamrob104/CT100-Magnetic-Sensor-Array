function [sensor_gains, gensig_mode, tf] = AutoCaptureConfigDlg(sensor_gains, gensig_mode)

    tf = false;

    if numel(sensor_gains) ~= 64
        sensor_gains = ones(1,64);
    end
    if isempty(gensig_mode) || ~(1 <= gensig_mode && gensig_mode <= 3)
        gensig_mode = 1;
    end

    gains  = [1 10 100 1000];
    colors = {[0 0.4470 0.7410] [0.8500 0.3250 0.0980] [0.9290 0.6940 0.1250] [0.4940 0.1840 0.5560]};

    fig = uifigure('Name','Acquire data settings', 'WindowStyle','modal', ...
                   'Position',[800 400 350 400], 'Resize','off');

    gridlayout = uigridlayout(fig);
    gridlayout.RowHeight = {290 '1x' 'fit' '1x' 'fit'};
    gridlayout.ColumnWidth = {'1x'};

    panel = uipanel(gridlayout, 'BorderType','none');
    panel.Layout.Row = 1;

    offset = [5 27];
    buttons = {};
    for channel = 1:4
        for sensor = 1:16
            i = (channel - 1) * 16 + sensor;
            x = mod( sensor-1,   4) + 4 * mod( channel-1,   2);
            y = fix((sensor-1) / 4) + 4 * fix((channel-1) / 2);
            button = uibutton(panel, 'Position',[[x*30 y*30] + offset 25 25], 'Text',num2str(sensor));
            setappdata(button, 'i',i);
            button.BackgroundColor = colors{gains == sensor_gains(i)};
            button.ButtonPushedFcn = @SensorButtonPushed;
            buttons{end+1} = button;
        end
        x = mod( channel-1,   2);
        y = fix((channel-1) / 2);
        label = uilabel(panel, 'Text',sprintf('Channel %d',channel), ...
            'HorizontalAlignment','center', 'FontWeight','bold', ...
            'Position',[[x*113 y*267] - [0 27] + offset 112 22]);
    end
    hline = uilabel(panel);
    hline.BackgroundColor = ones(1,3) * 0.3;
    hline.Position = [[-5 117] + offset 245 1];
    vline = uilabel(panel);
    vline.BackgroundColor = ones(1,3) * 0.3;
    vline.Position = [[117 -27] + offset 1 289];

    offset = [265 210];
    label = uilabel(panel, 'Text','Gain', 'HorizontalAlignment','center', 'FontWeight','bold', 'Position',[offset 50 22]);
    for k = 1:length(gains)
        label = uilabel(panel, 'Position',[[35 -27*k] + offset 30 22], 'Text',num2str(gains(k)));

        sticker = uibutton(panel, 'Position',[[0 -27*k] + offset 30 22],  'Text','', 'BackgroundColor',colors{k});
        setappdata(sticker, 'k',k);
        setappdata(sticker, 'timer',{});
        sticker.ButtonPushedFcn = @StickerPushed;
    end

    dropdown = uidropdown(gridlayout);
    dropdown.Layout.Row = 3;
    dropdown.Items = {'Don''t generate signal'
                      'Generate signal continuously'
                      'Regenerate signal after switching sensor'};
    dropdown.Value = dropdown.Items{gensig_mode};

    button = uibutton(gridlayout, 'Text','Ok');
    button.Layout.Row = 5;
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

    function StickerPushed(sticker,~)
        timer = getappdata(sticker, 'timer');
        if ~isempty(timer) && toc(timer) < 0.5
            k = getappdata(sticker, 'k');
            for i = 1:length(sensor_gains)
                sensor_gains(i) = gains(k);
                buttons{i}.BackgroundColor = colors{k};
            end
        end
        setappdata(sticker, 'timer',tic);
    end

    function OkButtonPushed(~,~)
        gensig_mode = find(contains(dropdown.Items, dropdown.Value));
        tf = true;
        close(fig);
    end
end