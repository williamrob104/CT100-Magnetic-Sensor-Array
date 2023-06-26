function [idx,tf] = ListDlg(varargin)

idx = [];
tf = false;

p = inputParser;
addParameter(p, 'ListString', {})
addParameter(p, 'PromptString', '')
addParameter(p, 'SelectionMode', 'multiple', @(a)strcmpi(a,'multiple') || strcmpi(a,'single'))
addParameter(p, 'ListSize', [160 300])
addParameter(p, 'InitialValue', [])
addParameter(p, 'Name', '')
addParameter(p, 'OKString', 'OK')
parse(p, varargin{:})
r = p.Results;
r.ListString = convertStringsToChars(r.ListString);
[r.ListString{:}] = convertStringsToChars(r.ListString{:});

fig = uifigure('WindowStyle','modal', 'Name',r.Name, 'Resize','off', 'Visible','off');

gridlayout = uigridlayout(fig);
gridlayout.RowHeight = {};

if ~isempty(r.PromptString)
    gridlayout.RowHeight{end+1} = '1x';
    label = uilabel(gridlayout, 'Text',r.PromptString);
    label.Layout.Row = length(gridlayout.RowHeight);
    label.Layout.Column = [1 2];
end

gridlayout.RowHeight{end+1} = r.ListSize(2);
listbox = uilistbox(gridlayout);
listbox.Layout.Row = length(gridlayout.RowHeight);
listbox.Layout.Column = [1 2];
if strcmpi(r.SelectionMode, 'multiple')
    listbox.Multiselect = 'on';
end
listbox.Items = r.ListString;
if isempty(r.InitialValue)
    if strcmpi(r.SelectionMode, 'multiple')
        listbox.Value = {};
    else
        listbox.Value = listbox.Items{1};
    end
else
    listbox.Value = listbox.Items(r.InitialValue);
end

if strcmpi(r.SelectionMode, 'multiple')
    gridlayout.RowHeight{end+1} = '1x';
    button1 = uibutton(gridlayout, 'Text','Select all');
    button1.Layout.Row = length(gridlayout.RowHeight);
    button1.Layout.Column = 1;
    button1.ButtonPushedFcn = @SelectAllButtonPushed;
    button2 = uibutton(gridlayout, 'Text','Deselect all');
    button2.Layout.Row = length(gridlayout.RowHeight);
    button2.Layout.Column = 2;
    button2.ButtonPushedFcn = @DeselectAllButtonPushed;
end

    function SelectAllButtonPushed(~,~)
        listbox.Value = listbox.Items;
    end
    function DeselectAllButtonPushed(~,~)
        listbox.Value = {};
    end

gridlayout.RowHeight{end+1} = '1x';
button = uibutton(gridlayout, 'Text',r.OKString);
button.Layout.Row = length(gridlayout.RowHeight);
button.Layout.Column = [1 2];
button.ButtonPushedFcn = @OkButtonPushed;

    function OkButtonPushed(~,~)
        tf = true;
        idx = [];
        for k = 1:length(listbox.Items)
            if any(contains(listbox.Value, listbox.Items{k}))
                idx(end+1) = k;
            end
        end
        close(fig)
    end

fig.Position = [600  600  r.ListSize(1) + 20  r.ListSize(2) + length(gridlayout.RowHeight) * 32 - 12];
fig.Visible = "on";

uiwait(fig)

end