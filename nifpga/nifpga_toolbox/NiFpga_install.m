function NiFpga_install
%NIFPGA_INSTALL  Install the NiFpga toolbox
%   NIFPGA_INSTALL installs the NiFpga toolbox
%
% Example
%   NiFpga_install
%
% See also: NIFPGA2MATLAB STATUS2MSG

% Copyright 2010-2012 Peter Fiala

path = fileparts(mfilename('fullpath'));

fid = fopen(fullfile(path, 'template', 'NiFpga_mex_template.cpp'));
temptrim = textscan(fid, '%s', 'delimiter', '\n');
temptrim = temptrim{1};
fid = fopen(fullfile(path, 'template', 'NiFpga_mex_template.cpp'));
temp = textscan(fid, '%s', 'delimiter', '\n', 'whitespace', '');
temp = temp{1};

mexfile = fopen(fullfile(path, 'capi', 'NiFpga_mex.cpp'), 'wt');
repblock('Start', temp, temptrim, {''}, {''}, [], mexfile);

nicasts = {'Bool', 'I8', 'U8', 'I16', 'U16', 'I32', 'U32', 'I64', 'U64'};
ccasts = cell(size(nicasts));
mcasts = cell(size(nicasts));
for icast = 1 : length(nicasts)
    [ccasts{icast}, mcasts{icast}] = typecon(nicasts{icast});
end

tokens = {
    'Read', 100
    'Write', 200
    'ReadArray', 300
    'WriteArray', 400
    'ReadFifo', 500
    'WriteFifo', 600
    };

from = {'NICAST', 'CCAST', 'MATCAST'};
for iToken = 1 : size(tokens,1)
    str = tokens{iToken,1};
    ID = tokens{iToken,2};
    fprintf(1, 'Processing %s functions...', str);
    for icast = 1 : length(nicasts)
        to = {nicasts{icast}, ccasts{icast}, mcasts{icast}};
        repblock(str, temp, temptrim, from, to, ID, mexfile);
        ID = ID + 1;
    end
    fprintf(1, 'ready\n');
end

repblock('Stop', temp, temptrim, from, to, [], mexfile);
fclose(mexfile);

% compile the mex file
fprintf(1, 'Compiling NiFpga.%s...', mexext);
mex('-O', '-output', fullfile(path, 'NiFpga'),...
    fullfile(path, 'capi', 'NiFpga.c'),...
    fullfile(path, 'capi', 'NiFpga_mex.cpp'));
fprintf(1, 'ready\n');

% Add the installation directory to the Matlab path
fprintf(1, 'Adding NiFpga to the Matlab path...');
addpath(path);
savepath;
fprintf(1, 'ready\n');
fprintf(1, 'Congratulations, you have the NiFpga Toolbox installed!\n');

% detect if Matlab was able to save the new path, show a warning dialog
% otherwise
[warnMsg, warnId] = lastwarn;
if strcmpi(warnId, 'MATLAB:SavePath:PathNotSaved')
    warndlg(warnMsg, warnId);
end

end % End of function

function repblock(label, ctemp, ctemptrim, from, to, ID, fid)
from{end+1} = 'ID';
to{end+1} = num2str(ID);
from2 = cell(size(from));
for i = 1 : length(from)
    from2{i} = ['###' from{i} '###'];
end

start = find(strcmp(sprintf('//// %s', label), ctemptrim), 1, 'first');
stop = find(strcmp(sprintf('// end %s', label), ctemptrim), 1, 'first');
block = ctemp(start:stop);
block = regexprep(block, from, from2);
block = regexprep(block, from2, to);
for i = 2 : length(block)-1
    fprintf(fid, '%s\n', block{i});
end
end
