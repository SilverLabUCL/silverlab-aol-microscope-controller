%% Check if we are at the Z stack center
% -------------------------------------------------------------------------
% Syntax: 
%   status = check_if_at_stack_center(controller, complement_msg)
%
% -------------------------------------------------------------------------
% Inputs: 
%   controller(Controller object) - Optional - Default is main Controller:
%                                   Contains information about the
%                                   microscope setup such as FOV, dwell
%                                   time etc...
%
%   complement_msg(STR) - Optional - Default ''
%                                   Extra message to explain what happens
%                                   if we do not move.
% -------------------------------------------------------------------------
% Outputs:
%   status(BOOL)
%                                   If true, you are at the stack centre
% -------------------------------------------------------------------------
% Extra Notes:
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
%   19-04-2019
%
% See also: XyzStage.move_to_stack_center

function status = check_if_at_stack_center(controller, complement_msg)
    if nargin < 1 || isempty(controller)
        controller = get_existing_controller_name(true);
    end
    if nargin < 2 || isempty(complement_msg)
        complement_msg = '';
    end

    %% Get the current stack center
    theoretical_center = round(controller.xyz_stage.move_to_stack_center(false));
    
    %% If we are not at the stack center, ask what to do
    status = 1;
    if abs(theoretical_center - round(controller.xyz_stage.get_position(3))) > 1 % 1 um tolerance because of rounding effects
        answer = questdlg({'You are currently not at the stack center.';...
                   'Stage will usually move to the stack center when doing Z-stack or Arboureal scanning';...
                   'If you start MC from this Z position, you may loose correction later on.';...
                   complement_msg;...
                   'Do you want to continue ?'},'Z position check','Yes','No','No');
        if isempty(answer) || strcmp(answer, 'No')
            status = 0;
        end
    end         
end

