%% Unpack and Check if parameters Varargin Names are valid
%  This will avoid passing a wrong name, and use a default value instead
%  by mistake.
% -------------------------------------------------------------------------
% Syntax: 
%   parameters = check_names_validity(Arguments_list, varargin)
% -------------------------------------------------------------------------
% Inputs: 
%   Arguments_list({1 x M} Cell array)
%                                   Cell array of all acceptable input
%                                   arguments.
%
%   varargin({1 x 2N} Cell array)
%                                   Pairs of {'Name', Value} arguments. All
%                                   names are checked, and must match one
%                                   element of Arguments_list
% -------------------------------------------------------------------------
% Outputs:
%   parameters(STRUCT)
%                                   a paramters object, if all input names
%                                   were valid
% -------------------------------------------------------------------------
% Extra Notes:
% * To create your own parameter class, use read_options_template()
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
%   24-02-2019
%
% See also: arboreal_params, stack_params, timing_params, viewer_params 
%

function parameters = check_names_validity(Arguments_list, varargin)
    %% Check validity of the parameter name
    while ~isempty(varargin) && (~isstruct(varargin) || iscell(varargin)) && numel(varargin) == 1
        varargin = varargin{1};
    end

    for el = 1:2:numel(varargin)
        if ~any(strcmp(Arguments_list, varargin(el)))
            error(['"' ,varargin{el},'" is not a valid parameter according to your model. Valid inputs are :', strjoin(Arguments_list','\n')])
        end
    end
end


