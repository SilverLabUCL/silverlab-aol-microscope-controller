%% Return the name of any existing controller located in the base workspace
% -------------------------------------------------------------------------
% Syntax: 
%   controller = get_existing_controller_name(evaluate)
% -------------------------------------------------------------------------
% Inputs: 
%   evaluate(BOOL) - Optional - Default is false 
%                                   If true, the controller found is
%                                   returned as an object instead of a
%                                   string
% -------------------------------------------------------------------------
% Outputs: 
%   controller(STR or Controller Object or {}) : 
%                                   - The Controller name of any existing 
%                                   controller if evaluate is false, or ''. 
%                                   - A handle to the controller object 
%                                   if evaluate is true (or {} if nothing
%                                   is found).
% -------------------------------------------------------------------------
% Extra Notes:
% -------------------------------------------------------------------------
% Examples:
%
% * Get the Controller name
%    name = get_existing_controller_name();
%
% * Get the Controller
%    name = get_existing_controller_name(true);
%
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
%   13-03-2018
%
% See also: Controller

function controller = get_existing_controller_name(evaluate)
    if nargin < 1 || isempty(evaluate)
        evaluate = false;
    end

    %% Default output
    controller = '';
    
    %% Check for existing controller in base workspace
    base_variable = evalin('base','who');
    for el = 1:numel(base_variable)
        if strcmp(class(evalin('base',base_variable{el})),'Controller')
            controller = base_variable{el};
        end  
    end
    
    %% Evaluate if required, and if anything found
    if evaluate && ~isempty(controller)
        controller = evalin('base',controller);
    elseif evaluate && isempty(controller) 
        controller = {}; % instead of ''
    end
end