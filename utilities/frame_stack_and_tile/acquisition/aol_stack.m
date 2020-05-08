%% Execute an AOL stack. The stack direction is specified by stack params
% if sp is not defined, current pockel values are used, and stack do no
% average
%
% -------------------------------------------------------------------------
% Syntax: 
%   stack = aol_stack(controller, stack_parameters, varargin)
%
% -------------------------------------------------------------------------
% Inputs: 
%   controller(Controller object) - Optional - Default is main Controller: 
%                                   Contains information about the
%                                   microscope setup such as FOV, dwell
%                                   time etc...
%
%   stack_parameters(stack_params object) - Optional - default is
%           Controller.stack_params 
%                                   Define the stack properties.
%                                   
%   varargin({'Argument',Value} pairs) - Optional - to build 
%       stack_parameters input only  
%                                   Any pair of argument and value pairs
%                                   applied to create a stack_parameters 
%                                   input. (has no effect if
%                                   stack_parameters is not empty)
% -------------------------------------------------------------------------
% Outputs:
%
% 	stack(Cell array of {[X * Y * Z * NChannels] DOUBLE}) : 
%                                   - When not using dynamic stack, one 
%                                   cell containing a 4D matrix :
%                                   X = Controller.scan_params.mainscan_x_pixel_density
%                                   Y = Controller.scan_params.num_drives
%                                   Z = stack_parameters.num_planes
%                                   NChannels = number of channel acquired
%                                               by timed_image
%                                   - When using dynamic stack, one 
%                                   cell per selected reference:
%
% -------------------------------------------------------------------------
% Extra Notes:
% * Unless specified, aol_stack uses the current controller stack_params. 
%   For other settings than the current ones, you can either pass some 
%   settings as Name-Arguments pairs, or pass a stack_params object
% -------------------------------------------------------------------------
% Examples: 
%
% * Get a stack using current controller stack_params
%   data = aol_stack; 
%
% * Get stack based on current controller stack_params but some changes
%   data = aol_stack(c,'','num_planes',3)
%
% * Generate manually your own stack
%   stack_parameters = stack_params('','',...
%                                        'stack_start',5,...
%                                        'stack_stop',-5,...
%                                        'num_planes',11,...
%                                        'direction','x',...
%                                        'averages',3);
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

function stack = aol_stack(controller, stack_parameters, varargin)
    if nargin < 1 || isempty(controller)
        controller = get_existing_controller_name(true);
    end
    if nargin < 2 || isempty(stack_parameters)
        stack_parameters = stack_params(controller, '', varargin); % If no stack_params provided, uses controller one, augmented by any varargin
    end

    %% Adjust Pockel cell values
    if isempty(stack_parameters.pockels_start)
        stack_parameters.pockels_start = controller.pockels.on_value;
        stack_parameters.pockels_stop = stack_parameters.pockels_start;
    end
    
    %% Prepare the initial conditions
    controller.xyz_stage.move_to_stack_center(stack_parameters.move_to_stack_center); % Move stage if required
    stage_pos = controller.xyz_stage.get_position(3);
        
    %% Adjust angles depending on stack type
    initial_scan_params = controller.scan_params;
    if strcmp(stack_parameters.direction,'z')
        controller.scan_params.angles = [0,0,0];
    elseif strcmp(stack_parameters.direction,'y') %rotation around the y axis, stage moves in y. Z change during line scan so we need non linear drives
        controller.scan_params.angles = [0,90,0]; 
    elseif strcmp(stack_parameters.direction,'x') %rotation around the x axis, stage moves in x. Don't need non linear drives
        controller.scan_params.angles = [90,0,0];
    end
    
    %% Prepare function handle that will be called at each plane
    function func(position, generate_viewer) % use a closure to make a single variable function with the desired params.
        norm_position = controller.aol_params.convert_z_um_to_norm(position, controller.scan_params.acceptance_angle, stage_pos);
        controller.scan_params.start_norm_raw(3) = norm_position;
        controller.send_drives(generate_viewer);
    end

    %% Get stack
    stack = stack_generic(controller, @func, stack_parameters, initial_scan_params);
end