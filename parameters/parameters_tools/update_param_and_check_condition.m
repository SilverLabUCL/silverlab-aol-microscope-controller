%% Checking contraints on {'Argument',Value} pairs and update values
%   When you create a params object, on some specific {'Argument',Value}
%   pairs can be passed. This function check if the inputs are valid, and
%   if the data type is respected. If a value is passed, the input parameter
%   object is updated with the new value, otherwise, the default value is
%   set.
%
% -------------------------------------------------------------------------
% Syntax: 
%   parameters = update_param_and_check_condition(condition, field_name,...
%                  default_value, update, arg_list, parameters, data_type)
%
% -------------------------------------------------------------------------
% Inputs: 
%   argument(STR) : 
%                                   The argument name corresponding to the
%                                   field to update. This is the first
%                                   element you have to pass in an 
%                                   {argument,Value} pair
%
%   field_name(STR) : 
%                                   The field name to create for this input
%                                   argument in the parameters object. If 
%                                   the field isabsent it will be created,
%                                   otherwise it may just be updated.
%
%   default_value(any type of data) : 
%                                   The default value to give to this
%                                   field, if update == -1. The data type
%                                   must match 'data_type' setting (if
%                                   specified).
%
%   update(INT) : 
%                                   If 0, we don't change any parameter.
%                                   If > 0 or -1, we update the value if  
%                                   the 'argument' is in arg_list.
%                                   If -1, and the argument is not in arg
%                                   list, we set the default value
%                                   parameters.field_name = default_value.
%                                   if > 1, and the argument is not in the
%                                   list we do not add any default and
%                                   leave the object as such
%
%   arg_list(CELL ARRAY) : 
%                                   The whole {'Argument','Value'} pair
%                                   passed the the previous function. If
%                                   one of the cell field matches 
%                                   argument, the following cell value is
%                                   used. The data must match 'data_type'
%
%   parameters(STRUCT) : 
%                                   any pre-existing parameters obeject to
%                                   be updated. This is where the fields
%                                   are added / changed.
%
%   data_type(STR) - Optional - any in {'int', 'float', 'bool', 'str',
%       'obj', 'path', {'any','series','of','str'} }: 
%                                   If specified, the data type in the
%                                   arg_list must macth this setting.
%                                   - 'int' accepts round values or arrays 
%                                   (they can be of any numerical data type,
%                                   providing they are round). The output
%                                   is a double of a round value.
%                                   - 'float' accepts any numerical value
%                                   or array.
%                                   - 'bool' accepts any numerical or 
%                                   logical value but no arrays. The output  
%                                   is a logical value.
%                                   - 'str' accepts char and strings.
%                                   - 'obj' will attempt to evaluate the
%                                   parameter
%                                   - 'path' will make sure that your file
%                                   path have / and no \ and that the file
%                                   end with / if its a folder.
%                                   - {cell array of char} will check that
%                                   your input parameter is one of the
%                                   element of this list.
%
% -------------------------------------------------------------------------
% Outputs:
%
%   parameters(STRUCT) : Default is the input parameter
%                                   If you passed an updated value, the 
%                                   designated field is updated. Otherwise,
%                                   the default value is set.
%
% -------------------------------------------------------------------------
% Extra Notes:
% * The function works with unwrap_parameters()
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
%   12-03-2018
%
% See also: unwrap_parameters

function parameters = update_param_and_check_condition(argument, field_name, default_value, update, arg_list, parameters, data_type)
    if nargin < 7
        data_type = false; % then no constraint on the parameter
    end
    
    %% Check if the varargin contain one of the valid 'Name'
    if iscell(argument) && numel(argument) > 1% backcompatibility trick when multiple arguments are valid for a same condition
        cond = cellfun(@(x) any(strcmp(arg_list, x)), argument);
    else % most cases
        cond = strcmp(arg_list, argument);
    end
    if sum(cond) > 1
        %% Ignore all duplicates except the last one
        to_ignore = find(cond, sum(cond)-1, 'first');
        to_ignore = sort([to_ignore, to_ignore+1]);
        arg_list(to_ignore) = [];
    end
    if ischar(argument) % When 1 valid input only (most cases)
        cond = strcmp(arg_list, argument);
    else % When several valid input names are valid
        cond = strcmp(arg_list, argument{1});
        for idx = 2:numel(argument)
            cond = cond | strcmp(arg_list, argument{idx});
        end
    end

    %% Check if the value must be updated or set to default
    if update && any(cond) %any(find(strcmp(argument, arg_list),1))
        %% Read and update value. Check for constraints
        
        %% We fist apply the value anyway
        parameters.(field_name) = arg_list{find(cond == 1)+1};

        %% Now we check for contraints and adjust datatype if required
        is_char_or_char_list = (iscell(data_type) && any(cellfun(@isstr, data_type))) || isstr(data_type);
        if is_char_or_char_list && any(contains(data_type, '@')) && isa(parameters.(field_name),'function_handle'); % this can be on top of any other fitler
            % ok
        elseif strcmp(data_type,'int')
            if (any(~isnumeric(parameters.(field_name))) && any(~islogical(parameters.(field_name)))) || any(mod(parameters.(field_name),1))
                error_box([' --- parameter ',field_name,' must be a round value ---'], false)
            end
            parameters.(field_name) = double(parameters.(field_name));
        elseif strcmp(data_type,'float')
            if any(~isnumeric(double(parameters.(field_name))))
                error_box([' --- parameter ',field_name,' must be a number ---'], false)
            end
            parameters.(field_name) = double(parameters.(field_name));     
        elseif strcmp(data_type,'bool')
            if (~isnumeric(parameters.(field_name)) && ~islogical(parameters.(field_name))) || numel(parameters.(field_name)) > 1
                error_box([' --- parameter ',field_name,' must be a unique boolean ---'], false)
            end
            parameters.(field_name) = logical(parameters.(field_name));   
        elseif strcmp(data_type,'str')
            if ~ischar(parameters.(field_name))
                error_box([' --- parameter ',field_name,' must be a text string ---'], false)
            end
            parameters.(field_name) = parameters.(field_name);  
        elseif strcmp(data_type,'cell')
            if ~iscell(parameters.(field_name))
                error_box([' --- parameter ',field_name,' must be a cell or cell array ---'], false)
            end
            parameters.(field_name) = parameters.(field_name);  
        elseif strcmp(data_type,'obj')
            if ~ischar(parameters.(field_name))
                error_box([' --- parameter ',field_name,' must be evaluable ---'], false)
            end
            parameters.(field_name) = eval(parameters.(field_name)); 
        elseif strcmp(data_type,'path')
            if ~ischar(parameters.(field_name)) || (~contains(parameters.(field_name),'~') && ~exist(parameters.(field_name)))
                error_box([' --- parameter ',field_name,' must be a valid path ---'], false)
            end
            [parameters.(field_name), folder, ~, ~, ~] = adjust_pathnames(parameters.(field_name)); %We assume it's a file path
            if isempty(parameters.(field_name))
                % If it's a folder path, parameters.(field_name) would be empty. 
                parameters.(field_name) = folder;
            end
        elseif iscell(data_type)    
            if ~any(strcmp(data_type, parameters.(field_name))) && isstr(cell2mat(data_type))
                error_box([strjoin([' --- input str must be one of the following : ',data_type,' ---'],' ; '), 'but was ', parameters.(field_name)], false)
            end
        end 
    elseif update == -1 && ~isfield(parameters, field_name)
    	parameters.(field_name) = default_value;
    end
end
