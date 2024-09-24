function varargout = PostprocessData(data, varargin)

if strcmpi(data, "operations")
    varargout{1} = {"Display frequency gain"};
    return
end

p = inputParser;
p.KeepUnmatched = true;
addParameter(p, 'Operation', '')
parse(p, varargin{:})

op = p.Results.Operation;

if strcmpi(op, "Display frequency gain")
    DisplayFrequencyGain(data)
end

end


function DisplayFrequencyGain(data)

data = PerformFFT(data);
[~,idxs] = findpeaks(abs(data{1}.src_spectrum), 'NPeaks',5, 'SortStr','descend');
freqs = data{1}.f(idxs);

for i = 1:length(data)
    G1(i,1,:) = data{i}.ch1_spectrum(idxs) ./ data{i}.src_spectrum(idxs);
    G2(i,1,:) = data{i}.ch2_spectrum(idxs) ./ data{i}.src_spectrum(idxs);
    G3(i,1,:) = data{i}.ch3_spectrum(idxs) ./ data{i}.src_spectrum(idxs);
    G4(i,1,:) = data{i}.ch4_spectrum(idxs) ./ data{i}.src_spectrum(idxs);
end
G = [reshape(G1,4,4,[]) reshape(G3,4,4,[])
     reshape(G2,4,4,[]) reshape(G4,4,4,[])];

f = uifigure('Position',[100 100 640 480], 'Name','Display frequency gain');

gridlayout = uigridlayout(f);
gridlayout.ColumnWidth = {'1x', 'fit', 'fit'};
gridlayout.RowHeight = {'1x', 'fit', 'fit'};

ax = uiaxes(gridlayout);
ax.Layout.Row = [1 3];
ax.Layout.Column = 1;

freq_dropdown = uidropdown(gridlayout, 'Items',string(freqs));
freq_dropdown.Layout.Row = 2;
freq_dropdown.Layout.Column = 2;
freq_dropdown.ValueChangedFcn = @(~,~)displayGain();
label = uilabel(gridlayout, 'Text','Hz');
label.Layout.Row = 2;
label.Layout.Column = 3;

mode_dropdown = uidropdown(gridlayout, 'Items',{'abs' 'angle' 'real' 'imag'});
mode_dropdown.Layout.Row = 3;
mode_dropdown.Layout.Column = [2 3];
mode_dropdown.ValueChangedFcn = @(~,~)displayGain();

displayGain()

    function displayGain()
        idx = freq_dropdown.Value == string(freqs);
        C = G(:,:,idx);

        switch mode_dropdown.Value
            case 'abs',   C = abs(C);
            case 'angle', C = angle(C);
            case 'real',  C = real(C);
            case 'imag',  C = imag(C);
        end

        cla(ax)
        hold(ax,'on')
        imagesc(ax, C.')
        colorbar(ax)
        axis(ax,'square')
        axis(ax,'xy')
        xlim(ax, [0.5 8.5])
        ylim(ax, [0.5 8.5])
        
        rectangle(ax, 'Position', [0.5 0.5 4 4], 'LineWidth',1);
        rectangle(ax, 'Position', [4.5 0.5 4 4], 'LineWidth',1);
        rectangle(ax, 'Position', [0.5 4.5 4 4], 'LineWidth',1);
        rectangle(ax, 'Position', [4.5 4.5 4 4], 'LineWidth',1);

        text(ax, 0.7, 0.8, 'Channel 1', 'FontSize',18)
        text(ax, 4.7, 0.8, 'Channel 2', 'FontSize',18)
        text(ax, 0.7, 4.8, 'Channel 3', 'FontSize',18)
        text(ax, 4.7, 4.8, 'Channel 4', 'FontSize',18)
    end

end


function data = PerformFFT(data)

for i = 1:length(data)
    t = data{i}.t;
    Ts = t(2) - t(1);
    Fs = 1 / Ts;

    src = data{i}.src;
    ch1 = data{i}.ch1 / data{i}.ch1_gain;
    ch2 = data{i}.ch2 / data{i}.ch2_gain;
    ch3 = data{i}.ch3 / data{i}.ch3_gain;
    ch4 = data{i}.ch4 / data{i}.ch4_gain;

    n = length(src);
    f = (0:n-1) / n * Fs;

    w = hamming(n);
    w = w / trapz(w) * Fs;

    src_spectrum = fft(src(:) .* w) * 2 / Fs;
    ch1_spectrum = fft(ch1(:) .* w) * 2 / Fs;
    ch2_spectrum = fft(ch2(:) .* w) * 2 / Fs;
    ch3_spectrum = fft(ch3(:) .* w) * 2 / Fs;
    ch4_spectrum = fft(ch4(:) .* w) * 2 / Fs;

    mask = 1:floor(n/2)+1;
    data{i}.f            = f           (mask);
    data{i}.src_spectrum = src_spectrum(mask);
    data{i}.ch1_spectrum = ch1_spectrum(mask);
    data{i}.ch2_spectrum = ch2_spectrum(mask);
    data{i}.ch3_spectrum = ch3_spectrum(mask);
    data{i}.ch4_spectrum = ch4_spectrum(mask);
end

end
