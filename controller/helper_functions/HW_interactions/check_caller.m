%% Return false if one of the unwanted_callers is part of dbstack
% -------------------------------------------------------------------------
% Syntax: 
%   cond_detected = check_caller(unwanted_callers, stack_min_depth)
% -------------------------------------------------------------------------
% Inputs: 
%   unwanted_callers(STR or STR Cell Array) 
%                                   If any function listed unwanted_callers
%                                   appears in the call stack,
%                                   cond_detected returns true.
%
%   stack_min_depth(INT) - Optional - Default is Inf
%                                   Call stacks shorter than this returns 
%                                   true
% -------------------------------------------------------------------------
% Outputs:
%
%   cond_detected(BOOL)
%                                   True if one of the 2 input criterion is
%                                   valid.
% -------------------------------------------------------------------------
% Extra Notes:
% * The function is used in the code to avoid calling the destructor for HW
%   objects when they are reloaded. This prevents the destruction of 
%   existing session when you are online
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
%   11-04-2019
%
% See also: Controller, DaqFpga, SynthFpga, Hardware

function cond_detected = check_caller(unwanted_callers, stack_min_depth)
    if ischar(unwanted_callers)
        unwanted_callers = {unwanted_callers};
    end
    if nargin < 2 || isempty(stack_min_depth)
        stack_min_depth = Inf;
    end
    
    cond_detected = 0;
    stackcall = dbstack;
    if ~isinf(stack_min_depth)
        cond_detected = numel(stackcall)-1 <= stack_min_depth; % add check_caller itself in your counts!
    end
    
    if ~cond_detected
        cond_detected = cond_detected || contains([stackcall.file],'.mlapp');

        if ~cond_detected
            stackcall = [stackcall.name];      
            for unwanted = unwanted_callers
                unwanted = unwanted{1};
                cond_detected = cond_detected || contains(stackcall, unwanted);
            end
        end
    end
end

