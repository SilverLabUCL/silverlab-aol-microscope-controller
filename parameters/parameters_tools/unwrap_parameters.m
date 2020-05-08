%% Reads varargin from other function and prepare for parsing
% Several functions require to read and/or read and update paramters. These
% parameters are passed as {'Argument',Value} pairs, Struct or any
% combination of these. This function just make sure that the formatting of
% these option is right for future parsing
%
% -------------------------------------------------------------------------
% Syntax: 
%   [parameters,extra_arguments,n_new] = unwrap_parameters(varargin)
%   [parameters,~,~] = unwrap_parameters( 'Argument1', Value1,...
%                                         'Argument2', Value2)
%   [parameters,~,~] = unwrap_parameters( previous_parameters,...
%                                         'Argument1', Value1,...
%                                         'Argument2', Value2)
%
% Passing a previous set of parameters first will adjust the default.
% Passing any extra {'Argument', Value} pair update the initial parameters
% object set as a first argument.
%
% -------------------------------------------------------------------------
% Inputs: 
%   varargin : ('Argument', Value) pairs
%           or (STRUCT)
%           or (STRUCT, 'Argument', Value):
%   for ('Argument', Value) pairs use{'Armust be set as the first argument
%
%
% -------------------------------------------------------------------------
% Outputs:
%
% parameters(STRUCT) : Default is {}
%                                   A struct object if it was passed as a
%                                   first input argument. An empty struct
%                                   otherwise
%
% extra_arguments{'Argument',Value} :  Default is ''
%                                   Any new parameters that need to be
%                                   updated. An empty char array '' if
%                                   there was no {'Argument',Value}
%
% n_new(INT): Default is -1              
%                                   if first argument was a struct, then 
%                                   it is the number of {'Argument',Value}.
%                                   Value is set to -1 if there was no
%                                   first struct object, and only 
%                                   {'Argument',Value}
%
% -------------------------------------------------------------------------
% Extra Notes:
% * If you want to create a new parameter file, you can duplicate and edit 
%   read_options_template
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
%   07-02-2018
%
% See also: arboreal_params, stack_params, folder_params, file_params,
%   timing_params, analysis_params, read_options_template,
%   get_recordings_info

function [parameters, extra_arguments, n_new] = unwrap_parameters(varargin)

    %% Prepare some variables
    parameters = {};
    extra_arguments = '';
    first_new_argument = 1;
    n_new = 0;
    
    %% Unwrap varargin in case in has been passed through multiple functions
    while ~isempty(varargin) && (~isstruct(varargin) || iscell(varargin)) && numel(varargin) == 1
        varargin = varargin{1};
    end
    
    %% If varargin{1} is already a set of parameters, isolate it
    if ~isempty(varargin) && (isstruct(varargin(1)) && ~iscell(varargin(1)) || isstruct(varargin{1}))
        if numel(varargin) == 1 % if it's the only parameter
            parameters = varargin;
        elseif numel(varargin) > 1 % if it is followed by new parameters
            parameters = varargin{1};
            n_new = (numel(varargin) - 1)/2;
            first_new_argument = 2;
        end
    end

    %% If varargin contains extra new parameters or,
    %% if varargin in a new set of parameters isolate them
    if numel(varargin) > 1
        extra_arguments = varargin(first_new_argument:end);
        while (~isstruct(extra_arguments) || iscell(extra_arguments)) && numel(extra_arguments) == 1
            extra_arguments = extra_arguments{1};
        end
        n_new = (numel(extra_arguments))/2;
        if mod((numel(extra_arguments)),2)
            error('all options except the first must be Argument,Value pairs')
        end
    end
    
    %% If there was no {'Argument',Value} pairs at the begining, n_new = -1
    if isempty(varargin) || ~isstruct(varargin(1)) && ~isstruct(varargin{1})
        n_new = -1;
    end
end

