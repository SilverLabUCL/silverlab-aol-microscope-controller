function NiFpga_mex
%NIFPGA_MEX  Compile NiFpga.mex
%   NIFPGA_MEX compiles the NiFpga.mex file
%
% Example
%   NiFpga_mex
%
% See also: NIFPGA2MATLAB STATUS2MSG

% Copyright 2010-2010 Peter Fiala

path = fileparts(mfilename('fullpath'));

fid = fopen(fullfile(path, 'template', 'NiFpga_mex_template.c'));
temptrim = textscan(fid, '%s', 'delimiter', '\n');
temptrim = temptrim{1};
fid = fopen(fullfile(path, 'template', 'NiFpga_mex_template.c'));
temp = textscan(fid, '%s', 'delimiter', '\n', 'whitespace', '');
temp = temp{1};

mexfile = fopen(fullfile(path, 'capi', 'NiFpga_mex.c'), 'wt');
repblock('Start', temp, temptrim, {''}, {''}, [], mexfile);

nicasts = {'Bool', 'I8', 'U8', 'I16', 'U16', 'I32', 'U32', 'I64', 'U64'};
ccasts = cell(size(nicasts));
mcasts = cell(size(nicasts));
for icast = 1 : length(nicasts)
    [ccasts{icast}, mcasts{icast}] = typecon(nicasts{icast});
end

ID = 100;
for icast = 1 : length(nicasts)
    from = {'NICAST', 'CCAST', 'MATCAST'};
    to = {nicasts{icast}, ccasts{icast}, mcasts{icast}};
    repblock('Read', temp, temptrim, from, to, ID, mexfile);
    ID = ID + 1;
end

ID = 200;
for icast = 1 : length(nicasts)
    from = {'NICAST', 'CCAST', 'MATCAST'};
    to = {nicasts{icast}, ccasts{icast}, mcasts{icast}};
    repblock('Write', temp, temptrim, from, to, ID, mexfile);
    ID = ID + 1;
end

ID = 300;
for icast = 1 : length(nicasts)
    from = {'NICAST', 'CCAST', 'MATCAST'};
    to = {nicasts{icast}, ccasts{icast}, mcasts{icast}};
    repblock('ReadArray', temp, temptrim, from, to, ID, mexfile);
    ID = ID + 1;
end

ID = 400;
for icast = 1 : length(nicasts)
    from = {'NICAST', 'CCAST', 'MATCAST'};
    to = {nicasts{icast}, ccasts{icast}, mcasts{icast}};
    repblock('WriteArray', temp, temptrim, from, to, ID, mexfile);
    ID = ID + 1;
end

ID = 500;
for icast = 1 : length(nicasts)
    from = {'NICAST', 'CCAST', 'MATCAST'};
    to = {nicasts{icast}, ccasts{icast}, mcasts{icast}};
    repblock('ReadFifo', temp, temptrim, from, to, ID, mexfile);
    ID = ID + 1;
end

ID = 600;
for icast = 1 : length(nicasts)
    from = {'NICAST', 'CCAST', 'MATCAST'};
    to = {nicasts{icast}, ccasts{icast}, mcasts{icast}};
    repblock('WriteFifo', temp, temptrim, from, to, ID, mexfile);
    ID = ID + 1;
end

repblock('Stop', temp, temptrim, from, to, [], mexfile);

fclose(mexfile);
mex('-O', '-output', fullfile(path, 'NiFpga'), fullfile(path, 'capi', 'NiFpga.c'), fullfile(path, 'capi', 'NiFpga_mex.c'));

end

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

