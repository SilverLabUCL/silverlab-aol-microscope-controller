%% Read ini file OR file paths if 'section' is indicated 
%   You can either directly read the content of an ini file by passing the
%   full adress of the file, or you can pass an ini file that contains a 
%   list of paths, plus the section name that precede this path.
%   see details about ini stucture in the Extra Notes section
% -------------------------------------------------------------------------
% Syntax: 
%   ini_info = load_ini_file(ini_file_path, section)
%
% -------------------------------------------------------------------------
% Inputs: 
%   ini_file_path(STR) - Optional : the full path of an ini file ;
%               OR the path of an ini file that contains pass, in which
%               case you need to pass the section parameter too
%               OR [], in which case if an existing configuration_file_path  
%               .ini is present in the ./Core folder, it will be used
%
%   section(STR) - Optional :
%               if you pass a file with paths in it, you must indicate the
%               name of the section that contains your path of interest
%               
%
% -------------------------------------------------------------------------
% Outputs:
%   ini_info(Nx1 Cell array) : Cell array axtracted from the ini file.
%               There is one cell per non-empty line
%
% -------------------------------------------------------------------------
% Extra Notes:
% * If default ini files are not found (for example if you start the
%   Controller for the first time, they are created using the .template
%   file.
%
% * Case 1 : Regular ini file, optionally with sections
% 	.ini file structure must be in the form
%
%     [Section name with numbers]
%     Variable 1 name = variable 1 numeric value  
%     Variable 2 name = variable 2 boolean value
% 
%     [Section name with strings]
%     Variable 3 name = "variable 3 whatever string" 
%     Variable 4 name = 'variable 4 whatever string' 
%     Variable 5 name = variable 5 whatever string 
%
% * Case 2 : Path pointing at other ini files
% 	.ini file path must be displayed as follow
%
%     [Section name for path 1]
%     X:\Wherever that file is\it_is_there.ini
%     [Section name for path 2]
%     Y:\Wherever that file is\it_is_another_one.ini
%
% -------------------------------------------------------------------------
% Examples:
%
% * Load an ini file from current foldr
%   content = load_ini_file('setup.ini');
%
% * Load a specific ini file
%   content = load_ini_file('full/path/something.ini');
%
% * Load a specific ini file
%   content = load_ini_file('full/path/something.ini');
%
% * Load the calibration file using the default config file
%   content = load_ini_file([],[Calibration File]);
%
% * Load  the calibration file using a remote file
%   content = load_ini_file('full/path/configuration_file_path.ini',...
%                           '[Calibration File]');
% -------------------------------------------------------------------------
%                               Notice
%
% Author(s): Antoine Valera
%
% This function was initially released as part of The SilverLab MatLab
% Imaging Software, an open-source application for controlling an
% Acousto-Optic Lens laser scanning microscope. The software was 
% developed in the laboratory of Prof Robin Angus Silver at University
% College London with funds from the NIH, ERC and Wellcome Trust.
%
% Copyright © 2015-2020 University College London
%
% Licensed under the Apache License, Version 2.0 (the "License");
% you may not use this file except in compliance with the License.
% You may obtain a copy of the License at
% 
%     http://www.apache.org/licenses/LICENSE-2.0
% 
% Unless required by applicable law or agreed to in writing, software
% distributed under the License is distributed on an "AS IS" BASIS,
% WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
% See the License for the specific language governing permissions and
% limitations under the License. 
% -------------------------------------------------------------------------
% Revision Date:
%   05-05-2020
%
% See also: read_ini_value

function [ini_content, filepath] = load_ini_file(ini_file_path, section)
    %% Identify filename
    if nargin < 1 || isempty(ini_file_path)
        ini_file_path = '@/configuration_file_path.ini';
    end
    if nargin < 2 || isempty(section)
        filepath = ini_file_path;
    else
        [filepath, ini_file_path] = get_setup_ini_path(ini_file_path, section);
        if isempty(filepath)
            error_box([ini_file_path(2:end), ' file do not exist and was created. Please restart the controller'], 0)
        elseif filepath == -1
            error_box(sprintf('The Section "%s" in the ini file "%s" could not be found, Check that the .ini file is correct and points to the right destination.',section,ini_file_path), 0)
        end
    end
    
    %% Fix possible path issue
    filepath = strrep(filepath, '\', '/');
    
    %% Open ini file ; read values
    fid = fopen(filepath,'r');
    if fid == -1
        if ~isfile(filepath) && isfile(strrep(filepath,'.ini','.template'))
            copyfile(strrep(filepath,'.ini','.template'),filepath);
            [~, new_name, ext] = fileparts(filepath);
            error_box([new_name,ext, ' file did not exist and was created from the existing .template file. Please check the ini file content to adjust it to the current setup and restart the controller'], 1);
            fid = fopen(filepath,'r');
        else
            current_folder = fileparts(mfilename('fullpath'));            
            if isfile([current_folder(1:end-2),'configuration_file_path.ini'])
                winopen([current_folder(1:end-2),'configuration_file_path.ini']);
            end
            [~, target_name, ext] = fileparts(filepath);
            error_box([{['The path to the configuration file : ',target_name,ext]},{'was not found in ',filepath,'.The path indicated in ./Core/configuration_file_path.ini'},{'is probably wrong. Please edit this file and restart the Controller'}], 0);
        end
    end
    text = textscan(fid, '%s','Delimiter','');
    fclose(fid);
    text = text{1};
    
    %% Split lines
    ini_content = cleanup_text(text); 
end

function [config_file_path, ini_file_path] = get_setup_ini_path(ini_file_path, section)
    %% Get the line following section if you passed an ini files with paths
    
    if strcmp(ini_file_path(1),'@')    
        %% using @ requires an configuration_file_path.ini file 
        % specifically in the ./Core folder. Used internally by the
        % controller
        [~, ~, ~, ~, ini_folder_path] = adjust_pathnames(mfilename('fullpath'));
        ini_file_path = [ini_folder_path, ini_file_path(3:end)];
    else
        %% Correct paths for typo
        [ini_file_path, ~, ~, ~, ~] = adjust_pathnames(ini_file_path);
    end
    
    %% Open path file
    path_file = fopen(ini_file_path);
    if path_file == -1
        %% If it doesn't exist, it must be generated
        create_initial_file(ini_file_path);
        path_file = fopen(ini_file_path);
    end
    
    %% Find the right line, with the path
    config_file_path = find_right_header(path_file, section); 
    fclose(path_file);
end

function result = find_right_header(path_file, match)
    %% Identify a line following indicated header
    tline = 'whatever';
    while ischar(tline) && ~strcmp(tline, match)
        tline = fgetl(path_file);
    end
    result = fgetl(path_file);
end

function text = cleanup_text(text)
    %% Normalize text to remove trailing zero and double whitespaces
    for idx = 1:size(text,1)
        line = text{idx};

        %% Removes heading and leading zeroes
        line = strip(line);

        %% Remove double spaces
        while contains(line,'  ')
            line = strrep(line,'  ',' ');
        end

        %% Make sure there is one space before and after =
        if ~contains(line,'= ')
            line = strrep(line,'=','= ');
        end
        if ~contains(line,' =')
            line = strrep(line,'=',' =');
        end

        semicolon_idx = strfind(line,';');
        if ~isempty(semicolon_idx) && semicolon_idx == size(line,2)
            line = line(1:end-1);
        end

        text{idx} = line;
    end
end

function create_initial_file(ini_file_path)

    error_box( [ini_file_path,...
               ' was not found. If it is your first use on that computer ',...
               ' or if you just reinstalled the controller, you have to update the content of this .ini file.',...
               ' The file will now be created from a standard .template file but you have to check the .ini content',...
               ' Please open the file and adjust the relevant variables and paths.',...
               ' - For analysis mode (offline), you just have to update the vaa3d path.',...
               ' - For acquisition mode (online), Please calibrate the relevant objectives, adjust communications ports',...
               ' for all required devices, the ethernet adresses. Check AOL configuration, in particular the max power passed to crystals'], 1)   
    if ~exist(ini_file_path, 'file') && exist(strrep(ini_file_path,'.ini','.template'), 'file')
        copyfile(strrep(ini_file_path,'.ini','.template'),ini_file_path);
        fid = fopen(ini_file_path,'r');
        t = textscan(fid, '%s','Delimiter',''); t = t{1};
        p = mfilename('fullpath');
        idx = sort([strfind(p,'/'),strfind(p,'\')]);
        p1 = [p(1:idx(end-1)),'+default\setup.ini'];
        p2 = [p(1:idx(end-1)),'+default\calibration.ini'];
        t{2} = p1;
        t{4} = p2;
        fclose(fid);
        fid = fopen(ini_file_path,'wt');
        fprintf(fid,'%s\n',t{:});
        fclose(fid);
    end
end

