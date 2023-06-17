function devices = IDSerialComs()
% IDSerialComs identifies Serial COM devices on Windows systems by friendly name
% Searches the Windows registry for serial hardware info and returns devices,
% a cell array where the first column holds the name of the device and the
% second column holds the COM number. Devices returns empty if nothing is found.

devices = [];

Skey = 'HKEY_LOCAL_MACHINE\HARDWARE\DEVICEMAP\SERIALCOMM';
[~, list] = dos(['REG QUERY ' Skey]);
if ischar(list) && strcmp('ERROR',list(1:5))
    disp('Error: IDSerialComs - No SERIALCOMM registry entry')
    return;
end
list = strread(list,'%s','delimiter',' '); %#ok<FPARK> requires strread()
coms = 0;
for i = 1:numel(list)
    if strcmp(list{i}(1:3),'COM')
        if ~iscell(coms)
            coms = list(i);
        else
            coms{end+1} = list{i}; %#ok<AGROW> Loop size is always small
        end
    end
end
key = 'HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Enum\USB\';
[~, vals] = dos(['REG QUERY ' key ' /s /f "FriendlyName" /t "REG_SZ"']);
if ischar(vals) && strcmp('ERROR',vals(1:5))
    disp('Error: IDSerialComs - No Enumerated USB registry entry')
    return;
end
vals = textscan(vals,'%s','delimiter','\t');
vals = cat(1,vals{:});
out = 0;
for i = 1:numel(vals)
    if strcmp(vals{i}(1:min(12,end)),'FriendlyName')
        if ~iscell(out)
            out = vals(i);
        else
            out{end+1} = vals{i}; %#ok<AGROW> Loop size is always small
        end
    end
end

for i = 1:numel(coms)
    match = strfind(out,[coms{i},')']);
    ind = 0;
    for j = 1:numel(match)
        if ~isempty(match{j})
            ind = j;
        end
    end
    if ind ~= 0
        com = str2double(coms{i}(4:end));
        if com > 9
            length = 8;
        else
            length = 7;
        end
        if ~isempty(com)
            devices{end+1,1} = out{ind}(27:end-length); %#ok<AGROW>
            devices{end  ,2} = com; %#ok<AGROW> Loop size is always small
        end
    end
end