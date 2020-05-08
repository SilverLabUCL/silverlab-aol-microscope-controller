%% Reads the value of the line corresponding to the name parameter
% After loading an ini file with load_ini_file(), you can extract any
% parameter using it parameter name. The value located after '=' will be
% returned.
% If the line does not exist, value is set to nan, unless a default value
% is provided.
% If an entry is found, but there is no value after '=', an error is raised
% If there is more than one entry, an error is raised unless you sepecify 
% and extra flag preceding this entry (in which case, the first entry after 
% that is returned)
% -------------------------------------------------------------------------
% Syntax: 
%   [value, exact_line] = read_ini_value(ini_content, name, default_value,
%           section_name, separator, ignore_case)
%
% -------------------------------------------------------------------------
% Inputs: 
%   ini_content(Nx1 Cell Array)
%                                   A cell array returned by load_ini_file().
%
%   name(STR) 
%                                   the name of the parameter to be read. 
%                                   A partial name can be used if there 
%                                   is no multiple entries with that name
%
%   default_value(any value) - Optional - default is NaN
%                                   If no entry is found, default_value is
%                                   returned.
%
%   section_name(STR) - Optional
%                                   If multiple entries are found, a search 
%                                   for section_name string is done, and 
%                                   the first valid entry following 
%                                   section_name will be returned. To 
%                                   prevent errors, use the full name of 
%                                   the class name, with the brackets.
%
%   separator(STR) - Optional - default is '|' 
%                                   If the type of data imported is a list,
%                                   split the results using this separator.
%                                   A list (even of numbers) must be 
%                                   surrounded by double quotes.
%
%   ignore_case(STR) - Optional - default is false
%                                   If true, the field name case is
%                                   ignored.
% -------------------------------------------------------------------------
% Outputs:
%   value(BOOL, STR, FLOAT or N x 1 arrays)
%                                   If found, the value read after '=' is 
%                                   read otherwise default value is 
%                                   returned
% -------------------------------------------------------------------------
% Extra Notes:
%
% * If you want to import an array, your array must be surrounded by double
%   quotes. The default seprator is '|' but can be modified.
%
% * Final trailing whitespaces are ignored.
%
% * If a value ends with a semicolon, the character will be deleted during 
%   import in load_ini_file.m.
% -------------------------------------------------------------------------
% Examples:
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
%   29-06-2019
%
% See also: default.aol_params, default.rig_params, default.scan_params, 
%           folder_params, update_calibration_ini, Laser, 
%           read_tdms_header

function [value, exact_line] = read_ini_value(ini_content, name, default_value, section_name, separator, ignore_case)
   
    if nargin < 3 || isempty(default_value)
        default_value = NaN;
    end
    if nargin < 4 || isempty(section_name)
        section_name = [];
    end
    if nargin < 5 || isempty(separator)
        separator = '|';
    end
    if nargin < 6 || isempty(ignore_case)
        ignore_case = false;
    end
    
    %% Find lines matching 'name'
    Line = contains(ini_content,name,'IgnoreCase',ignore_case);
    exact_line = [];
    
    %% Checking special cases
    % -- multiple entries, but no rules for knowing which one to use
    if sum(Line) > 1 && (nargin < 4 || isempty(section_name))
        error_box(['more than one value found for ',name,' in ini file,',...
                   'but the [section] was not specified'], 0)
    end
    
    %% If line doesn't exist default_value is set but we display a warning
    if sum(Line) == 0 
        if nargin < 3
            warning(['no entry found for ', name,' in ini file. ',...
                     'Value was set to NaN. You may want to check your configuraton files']);
        end
        value = default_value;
    end
    
    %% If multiple entries and the appropriate class was indicated, no pb
    if sum(Line) > 1 && nargin >= 4 && ~isempty(section_name)
       Header_location = find(contains(ini_content,section_name) == 1);
       if isempty(Header_location)
            error_box(['The specified section ',section_name, ' does not exist. Check for typo'], 0)
       end
       Line(1:Header_location) = 0; %zero any previous valid lines
       right_location = find(Line,1,'first'); %find index of right header
       Line(right_location+1:end) = 0; %zero any later valid lines
    end

    %% Now that all corner cases were solved, only one valid line is left
    if sum(Line) == 1 
        exact_line = find(Line == 1);
        txt = [ini_content{Line}];
        line_text = txt(strfind(txt, '= ')+1:end);
        
        %% Ignore comment
        if contains(line_text, '#')
            line_text = line_text(1:strfind(line_text,'#')-1);
        end
        
        if strcmpi(strtrim(line_text),'false') 
            value = false;
        elseif strcmpi(strtrim(line_text),'true')
            value = true;
        elseif isnumeric(str2double(line_text)) && ~isnan(str2double(line_text))
            value = str2double(line_text);
        elseif ~isempty(line_text)
            value = strip(strrep(strrep(line_text,'"',''),'''',''));
            if contains(value, separator)
                value = split(value,separator);
            end
        else
%             error_box(['entry value not identified for ', name,' in .ini file. There may be a missing parameter or a typo. Please check the ini file'], 0)
        end

    elseif sum(Line) == 0 && isnan(default_value)
%          error_box(['entry value not identified for ', name,' in .ini file. There may be a missing parameter or a typo, and no default value is provided'], 1)
    end
end