%% Execute a motor stack. The stack direction is specified by stack params
% if stack_parameters is not defined, current pockel values are used, and
% stack do no average. Unless some parameters are bypassed, aol z=0. 
% The motor is brought back to the initial position in the end.
%
% -------------------------------------------------------------------------
% Syntax: 
%   stack = stack = motor_stack(controller, stack_parameters)
%
% -------------------------------------------------------------------------
% Inputs: 
%   controller(Controller object) - Optional - Default is main Controller:
%                                   Contains information about the
%                                   microscope setup such as FOV, dwell
%                                   time etc...
%
%   stack_parameters(stack_params object) - Optional but should be set:  
%                                   Define the stack properties.
%
% -------------------------------------------------------------------------
% Outputs:
%
% 	stack({[X * Y * Z * NChannels] DOUBLE}) : 
%                                   one cell containing a 4D matrix :
%                                   X = Controller.scan_params.mainscan_x_pixel_density
%                                   Y = Controller.scan_params.num_drives
%                                   Z = stack_parameters.num_planes
%                                   NChannels = number of channel acquired
%                                               by timed_image
%
% -------------------------------------------------------------------------
% Extra Notes:
% !! Double check the stack range to prevent collision !!
%
% -------------------------------------------------------------------------
% Examples: 
%
% * Create stack_params options and do a z-stack
%   stack_parameters = stack_params(c);
%   stack_parameters.stack_start = 'x';
%   stack_parameters.averages = 3;
%   aol_stack(c, stack_parameters);
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
%   07-02-2018
%
% See also: stack_params, stack_generic
%

function stack = motor_stack(controller, stack_parameters)
    if nargin < 1 || isempty(controller)
        controller = get_existing_controller_name(true);
    end
    if nargin < 2 || isempty(stack_parameters); stack_parameters = stack_params(controller); end

    initial_pos = controller.xyz_stage.get_position();
    
    %% Adjust Pockel cell values
    if isempty(stack_parameters.pockels_start)
        stack_parameters.pockels_start = controller.pockels.on_value;
        stack_parameters.pockels_stop = stack_parameters.pockels_start;
    end

    %% Prepare the initial conditions and prepare function handle that will 
    % be called at each plane
    initial_scan_params = controller.scan_params;
    if strcmp(stack_parameters.direction,'z')
        controller.scan_params.angles = [0,0,0];
        func = @(z,~) controller.xyz_stage.move_abs([initial_pos(1), initial_pos(2), z]);
    elseif strcmp(stack_parameters.direction,'y')
        controller.scan_params.angles = [0,90,0];
        func = @(y,~) controller.xyz_stage.move_abs([initial_pos(1), y, initial_pos(3)]);
    elseif strcmp(stack_parameters.direction,'x')
        controller.scan_params.angles = [90,0,0];
        func = @(x,~) controller.xyz_stage.move_abs([x, initial_pos(2), initial_pos(3)]);
    end
    
    %% Get and Process data
    stack = stack_generic(controller, func, stack_parameters, initial_scan_params);
end