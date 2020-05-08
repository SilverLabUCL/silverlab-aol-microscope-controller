function NiFpga2Matlab(FileNames, ClassName)
    %NIFPGA2MATLAB  Generate Matlab class from NI FPGA applications
    %   NiFpga2Matlab(FileNames, ClassName) generates a Matlab class from Ni
    %   Fpga VI-s so that all methods from the LabView Fpga panel can be
    %   called directly from Matlab.
    %
    % Example
    %
    % See also: NIFPGA_MEX STATUS2MSG

    % Copyright 2010-2010 Peter Fiala

    %% Set current matlab folder
    path = fileparts(mfilename('fullpath')); % toolbox path
    cd(path);

    %% Adjust source filename (remove NiFpga_ prefix and extension)
    [source_path, filename, ~] = fileparts(FileNames); % toolbox path
    if strcmp(strrep([source_path, '/', filename, '.h'],'\','/'), strrep([pwd, '/', filename, '.h'],'\','/'))
        already_in_folder = true;
    else
        already_in_folder = false;
    end
    if ~already_in_folder
        copyfile([source_path, '/', filename, '.h'], [filename, '.h']);
        copyfile([source_path, '/', filename, '.lvbitx'], [filename, '.lvbitx']);
    end

    %% Remove NiFpga_ prefix if any
    if strcmp(filename(1:7), 'NiFpga_')
        FileNames = filename(8:end);
    end

    % make sure that FileNames are stored in a cell array of strings
    if ~iscellstr(FileNames)
        FileNames = {FileNames};
    end

    % read the matlab main class template
    fname = fullfile(path, 'template', 'CMAINCLASS.m');
    fid = fopen(fname);
    if fid == -1
        error('NiFpga:file', 'Could not open file %s', fname);
    end
    temp = textscan(fid, '%s', 'delimiter', '\n', 'whitespace', '');
    fclose(fid);
    temp = temp{1};

    % replace the template variables with the FileNames
    temp = regexprep(temp, 'CMAINCLASS', ['C' ClassName]);
    temp = replacefields(temp, 'Subclasses', {'SUBCLASS'}, FileNames);
    temp = replacefields(temp, 'Subclass Constructors', {'SUBCLASS'}, FileNames);
    temp = replacefields(temp, 'Subclass Destructors', {'SUBCLASS'}, FileNames);

    % write output file
    fname = sprintf('C%s.m', ClassName);
    if ~isempty(dir(fname))
        delete(fname);
    end
    classfile = fopen(fname, 'wt');
    if classfile == -1
        error('NiFpga:file', 'could not open file %s', fname);
    end
    for i = 1 : length(temp)
        fprintf(classfile, '%s\n', temp{i});
    end
    fclose(classfile);
    fileattrib(fname, '-w');
    fprintf(1, 'Class C%s generated\n', ClassName);

    % write subclass files
    for iFile = 1 : length(FileNames)
        hFile2Matlab(FileNames{iFile});
        fprintf(1, 'Class C%s generated\n', FileNames{iFile});
    end

    %% Move the files one level up
    if isempty(ClassName)
        if ~already_in_folder
            delete(fname)
        end
        newpath = path(1:end-15);
        movefile([path, '\NiFpga_', FileNames{1}, '.lvbitx'],[newpath, '\NiFpga_', FileNames{1}, '.lvbitx'],'f');
        movefile([path, '\NiFpga_', FileNames{1}, '.h'],[newpath, '\NiFpga_', FileNames{1}, '.h'],'f'); 
        movefile([path, '\C', FileNames{1}, '.m'],[newpath, '\C', FileNames{1}, '.m'],'f');  
        error_box('You need now to update the appropriate DaQFpga*.m files with the new ',FileNames{1},' . Previous bitfiles (.h and .lvbit files) can be deleted too. You MUST restart matlab',1)
    end

end

function ID = hFile2Matlab(FileName)

    path = fileparts(mfilename('fullpath'));

    % Read CAPI h file and template file
    fname = sprintf('NiFpga_%s.h', FileName);
    fid = fopen(fname);
    if fid == -1
        error('NiFpga:file', 'Could not open file %s', fname);
    end
    hfile = textscan(fid, '%s', 'delimiter', '\n');
    fclose(fid);
    hfile = hfile{1};
    fname = fullfile(path, 'template', 'CSUBCLASS.m');
    fid = fopen(fname);
    if fid == -1
        error('NiFpga:file', 'Could not open file %s', fname);
    end
    temp = textscan(fid, '%s', 'delimiter', '\n', 'whitespace', '');
    fclose(fid);
    temp = temp{1};

    % replace class name, bitfile and signature
    expr = sprintf('#define\\sNiFpga_%s_Bitfile\\s"(?<bitfile>\\S+)"', FileName);
    bf = skipempty(regexp(hfile, expr, 'names'));
    expr = sprintf('NiFpga_%s_Signature\\s?=\\s?"(?<signature>\\S+)"', FileName);
    sign = skipempty(regexp(hfile, expr, 'names'));
    temp = regexprep(temp, {'SUBCLASS', 'BITFILE', 'SIGNATURE'},...
        {FileName, ['''' bf.bitfile ''''], ['''' sign.signature '''']});

    casts = {'Bool', 'I8', 'U8', 'I16', 'U16', 'I32', 'U32', 'I64', 'U64'};

    % Collect Indicator and Control items
    expr = sprintf('NiFpga_%s_%s', FileName,...
        '(?<type>Control|Indicator)(?<dim>Array)?(?<cast>Bool|[UI]\d+)?_(?<label>\w+)\s=\s(?<address>0x[0-9A-F]{1}),');
    Items4 = skipempty(regexp(hfile, expr, 'names'));
    expr = sprintf('NiFpga_%s_%s', FileName,...
        '(?<type>Control|Indicator)(?<dim>Array)?(?<cast>Bool|[UI]\d+)?_(?<label>\w+)\s=\s(?<address>0x[0-9A-F]{2}),');
    Items8 = skipempty(regexp(hfile, expr, 'names'));
    expr = sprintf('NiFpga_%s_%s', FileName,...
        '(?<type>Control|Indicator)(?<dim>Array)?(?<cast>Bool|[UI]\d+)?_(?<label>\w+)\s=\s(?<address>0x[0-9A-F]{3}),');
    Items8b = skipempty(regexp(hfile, expr, 'names'));
    expr = sprintf('NiFpga_%s_%s', FileName,...
        '(?<type>Control|Indicator)(?<dim>Array)?(?<cast>Bool|[UI]\d+)?_(?<label>\w+)\s=\s(?<address>0x[0-9A-F]{4}),');
    Items16 = skipempty(regexp(hfile, expr, 'names'));
    expr = sprintf('NiFpga_%s_%s', FileName,...
        '(?<type>Control|Indicator)(?<dim>Array)?(?<cast>Bool|[UI]\d+)?_(?<label>\w+)\s=\s(?<address>0x[0-9A-F]{8}),');
    Items32 = skipempty(regexp(hfile, expr, 'names'));

    Items = [Items4; Items8; Items8b; Items16; Items32];

    for iItem = 1 : length(Items)
        c = lower(Items(iItem).label(1)); 
        if c < 'a' || c > 'z'
            Items(iItem).label = ['l_' Items(iItem).label];
        end
    end

    % Replace Control/Indicator properties
    temp = replacefields(temp, 'Controls/Indicators', {'LABEL'}, {Items.label});

    I = struct2cell(Items);
    Scalars = Items(ismember(I(2,:), ''));
    Arrays = Items(ismember(I(2,:), 'Array'));

    % Read scalar block
    ID = 100;
    from = {'ID', 'LABEL', 'ADDRESS'}';
    to = cell(3, length(Scalars));
    for i = 1 : length(Scalars)
        id = find(ismember(casts, Scalars(i).cast))-1;
        to(:,i) = {sprintf('%d', ID+id)
            Scalars(i).label
            sprintf('%d', sscanf(Scalars(i).address, '%x'))}';
    end
    temp = replacefields(temp, 'Read', from, to);

    % Write scalar block
    ID = 200;
    from = {'ID', 'MATCAST', 'LABEL', 'ADDRESS'}';
    to = cell(length(from), length(Scalars));
    for i = 1 : length(Scalars)
        [~, ~, matcast] = typecon(Scalars(i).cast);
        id = find(ismember(casts, Scalars(i).cast))-1;
        to(:,i) = {sprintf('%d', ID+id)
            matcast
            Scalars(i).label
            sprintf('%d', sscanf(Scalars(i).address, '%x'))}';
    end
    temp = replacefields(temp, 'Write', from, to);

    % Read Array block
    ID = 300;
    from = {'ID', 'LABEL', 'ADDRESS', 'SIZE'}';
    to = cell(4, length(Arrays));
    for i = 1 : length(Arrays)
        id = find(ismember(casts, Arrays(i).cast))-1;
        size = skipempty(regexp(hfile,...
            sprintf('NiFpga_%s_%sArray%sSize_%s\\s=\\s(?<size>\\d+)',...
            FileName, Arrays(i).type, Arrays(i).cast, Arrays(i).label),...
            'names'));
        to(:,i) = {sprintf('%d', ID+id)
            Arrays(i).label
            sprintf('%d', sscanf(Arrays(i).address, '%x'))
            size.size};
    end
    temp = replacefields(temp, 'Read Array', from, to);

    % Write Array block
    ID = 400;
    from = {'ID', 'MATCAST', 'LABEL', 'ADDRESS', 'SIZE'}';
    to = cell(length(from), length(Arrays));
    for i = 1 : length(Arrays)
        [~, ~, matcast] = typecon(Arrays(i).cast);
        id = find(ismember(casts, Arrays(i).cast))-1;
        size = skipempty(regexp(hfile,...
            sprintf('NiFpga_%s_%sArray%sSize_%s\\s=\\s(?<size>\\d+)',...
            FileName, Arrays(i).type, Arrays(i).cast, Arrays(i).label),...
            'names'));
        to(:,i) = {sprintf('%d', ID+id)
            matcast
            Arrays(i).label
            sprintf('%d', sscanf(Arrays(i).address, '%x'))
            size.size};
    end
    temp = replacefields(temp, 'Write Array', from, to);

    % Collect FIFO items
    expr = sprintf('NiFpga_%s_%s', FileName,...
        '(?<type>TargetToHost|HostToTarget)Fifo(?<cast>Bool|[UI]\d+)_(?<label>\w+)\s=\s(?<address>\d+)');
    Items = skipempty(regexp(hfile, expr, 'names'));
    nItem = length(Items);

    if isempty(Items)
        Items = struct('type', {}, 'cast', {}, 'label', {}, 'address', {});
    end

    % Replace Fifo members
    temp = replacefields(temp, 'Fifos', {'FIFO'}, {Items.label});

    % Replace Fifo Constructors
    ID = 500;
    from = {'FIFO', 'TYPE', 'ADDRESS', 'ID'};
    to = cell(4, nItem);
    for iItem = 1 : nItem
        item = Items(iItem);
        id = find(ismember(casts, item.cast))-1;
        idd = 100*(strcmp(item.type, 'HostToTarget'));
        to(:,iItem) = {item.label
            item.type
            item.address
            sprintf('%d', ID+id+idd)};
    end
    temp = replacefields(temp, 'Fifo Constructor', from, to);

    % Replace Open Fifo
    temp = replacefields(temp, 'Open Fifo', {'FIFO'}, {Items.label});

    % Replace Close Fifo
    temp = replacefields(temp, 'Close Fifo', {'FIFO'}, {Items.label});

    % Write output
    fname = sprintf('C%s.m', FileName);
    if ~isempty(dir(fname))
        delete(fname);
    end
    classfile = fopen(fname, 'wt');
    if fid == -1
        error('NiFpga:file', 'Could not open file %s', fname);
    end
    for i = 1 : length(temp)
        fprintf(classfile, '%s\n', temp{i});
    end
    fclose(classfile);
    fileattrib(fname, '-w');
    end

    function Items = skipempty(Items)
    k = 0;
    for i = 1 : length(Items)
        if ~isempty(Items{i})
            k = k+1;
            Items{k} = Items{i};
        end
    end
    Items = cell2mat(Items(1:k));
    end

    function temp = replacefields(temp, label, from, to)
    [pre, block, post] = splitfile(temp, label);
    block2 = [];
    N = size(to,2);
    for i = 1 : N
        block2 = [
            block2
            regexprep(block, from, to(:,i));
            ];
    end
    temp = [pre; block2; post];
    end

    function [pre, block, post] = splitfile(file, label)
    filetrim = file;
    for i = 1 : length(file)
        filetrim{i} = strtrim(filetrim{i});
    end
    start = find(strcmp(sprintf('%% %s', label), filetrim), 1, 'first');
    stop = find(strcmp(sprintf('%% end %s', label), filetrim), 1, 'first');
    pre = file(1:start-1);
    block = file(start+1:stop-1);
    post = file(stop+1:end);
end