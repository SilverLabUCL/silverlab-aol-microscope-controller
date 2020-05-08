%% Superclass functions controlling stage position and stack range
% Controller class inherits these methods and properties
%
% Type doc function_name or help function_name to get more details about
% the function inputs and outputs
%
% More functions in utilities/movement_correction/
% -------------------------------------------------------------------------
% Syntax: N/A
% -------------------------------------------------------------------------
% Class Generation Inputs: N/A 
% -------------------------------------------------------------------------
% Outputs: N/A  
% -------------------------------------------------------------------------
% Class Methods: 
%
% * Store z_start or z_stop (idx = 1 or idx = 2 respectively)
% idx = Controller.set_z_pos(idx, new_pos)
%
% * Updates tiling range + z stacks limits if necessary
% idx = Controller.store_tile_range()
%
% * Reset z_stack and tiling range around current position
% Controller.reset_tile_range(varargin)
%
% * Check inputs and calculate step size
% Controller.update_z_planes(varargin)
%
% * Print suggestion for 1 um plane or cubic voxels
% Controller.suggestion = suggest_plane_value(print)
%
% -------------------------------------------------------------------------
% Extra Notes:
% To get detailled information about a function, use the matlab doc or help
% function.
%
% More functions are available in ./analog/XyzStage.m and 
% ./core/data_structure/StackAndTiles.m
% -------------------------------------------------------------------------
% Examples:
% -------------------------------------------------------------------------
%                               Notice
%
% Author(s): Victoria Griffiths, Antoine Valera, Geoffrey Evans
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
%   25-03-2018
%
% See also XyzStage, StackAndTiles


classdef stage_control < handle % superclass of Controller

    properties
    end

    methods    
        function idx = set_z_pos(this, idx, varargin)
            %% Store z_start or z_stop (idx = 1 or idx = 2 respectively)
            % -------------------------------------------------------------
            % Model: 
            %   idx = Controller.set_z_pos(idx, new_pos)
            % -------------------------------------------------------------
            % Inputs: 
            %   idx (INT) - [] OR 1 OR 2.
            %       1 or 2 defines if you want to update z_start or z_stop.
            %       If you just want to extent the current z range, leave
            %       idx empty.
            %   varargin (BOOL) - Optional - Default is current z
            %       The new position to update 
            % -------------------------------------------------------------
            % Outputs: 
            % -------------------------------------------------------------
            % Extra Notes:
            % -------------------------------------------------------------
            % Author(s):
            %   Antoine Valera.
            %---------------------------------------------
            % Revision Date:
            %   25-03-2018
            
            %% Read stage position if required
            if isempty(varargin) || nargin < 3
                pos = this.xyz_stage.get_position(3);
            else
                pos = varargin{1};
            end
            
            %% Read stage position if required. update position
            if isempty(idx)
                idx = this.xyz_stage.guess_if_new_min_or_new_max(pos);
                if idx == 1
                    this.xyz_stage.z_start = pos;
                elseif idx == 2
                    this.xyz_stage.z_stop = pos;
                end
            elseif idx == 1
                this.xyz_stage.z_start = pos;
            elseif idx == 2
                this.xyz_stage.z_stop = pos;
            end

            %% Fix 
            this.update_z_planes();
        end

        function idx = store_tile_range(this)
            %% Updates tiling range + z stacks limits if necessary
            % -------------------------------------------------------------
            % Model: 
            %   idx = Controller.store_tile_range()
            % -------------------------------------------------------------
            % Inputs: 
            % -------------------------------------------------------------
            % Outputs: 
            %   idx (INT) - 1 OR 2.
            %       1 or 2 defines if you updated z_start or z_stop.
            % -------------------------------------------------------------
            % Extra Notes:
            % -------------------------------------------------------------
            % Author(s):
            %   Antoine Valera.
            %---------------------------------------------
            % Revision Date:
            %   25-03-2018
            
            pos = this.xyz_stage.get_position();
            idx = this.xyz_stage.add_tile(pos);
        end
       
        function reset_tile_range(this, varargin)
            %% Reset z_stack and tiling range around current position
            % -------------------------------------------------------------
            % Model: 
            %   idx = Controller.store_tile_range()
            % -------------------------------------------------------------
            % Inputs: 
            % -------------------------------------------------------------
            % Outputs: 
            %   idx (INT) - 1 OR 2.
            %       1 or 2 defines if you updated z_start or z_stop.
            % -------------------------------------------------------------
            % Extra Notes:
            % -------------------------------------------------------------
            % Author(s):
            %   Antoine Valera.
            %---------------------------------------------
            % Revision Date:
            %   25-03-2018
            
            % TODO : the GUI part will break
            
            %% Read current position
            pos = this.xyz_stage.get_position();
            for ax = 1:3
                this.xyz_stage.tile_xyz_start(ax) = pos(ax);
                this.xyz_stage.tile_xyz_stop(ax) = pos(ax);
            end
            
            %% Create a +/- 1um stack around current position
            this.xyz_stage.z_start = pos(3)+1;
            this.xyz_stage.z_stop = pos(3)-1;
            this.xyz_stage.z_planes = 3;
            
            %% Update GUI fields
            if ~this.gui_handles.is_gui
                fprintf('tiling range reset to current FOV; i.e. [%5.1f %5.1f %5.1f] \n', this.xyz_stage.tile_xyz_start)
                f = figure(1000);
                h = f.Children(6);
                set(h,'String','3');% qq set the text edit to 1!!
            elseif isempty(varargin)
                %%pass
            else
                this.gui_handles.number_of_steps.String = '3';
            end
            this.update_z_planes(varargin)
        end
        
        function update_z_planes(this, varargin)
            %% Check inputs and calculate step size
            % -------------------------------------------------------------
            % Model: 
            %   Controller.update_z_planes(varargin)
            % -------------------------------------------------------------
            % Inputs: 
            % -------------------------------------------------------------
            % Outputs:
            % -------------------------------------------------------------
            % Extra Notes:
            % -------------------------------------------------------------
            % Author(s):
            %   Antoine Valera.
            %---------------------------------------------
            % Revision Date:
            %   25-03-2018
            
            %% Read and set Z value from input string
            if isnan(this.xyz_stage.z_planes) %this is dealing with the input field
            	errordlg('You must enter a numeric value','Invalid Input','modal')
            	this.xyz_stage.z_planes = 1;
            elseif isempty(varargin)
                %this.xyz_stage.z_planes not updated
            elseif ~iscell(varargin{1})
                if ~this.gui_handles.is_gui
                    this.xyz_stage.z_planes = abs(round(str2double(varargin{1}.String)));
                else
                    try
                        this.xyz_stage.z_planes = abs(round(varargin{1}.Value));
                    catch
                        this.xyz_stage.z_planes = abs(round(str2double(varargin{1}.String)));
                    end
                end
                this.xyz_stage.z_planes = this.xyz_stage.z_planes; %?!
            else
            	%reset tile; pass
            end
            
            %% Print suggestion for 1 um plane or ubic voxels
            suggest_plane_value(this);
        end
        
        function suggestion = suggest_plane_value(this, print)
            %% Print suggestion for 1 um plane or cubic voxels
            % -------------------------------------------------------------
            % Model: 
            %   suggestion = Controller.suggest_plane_value(print)
            % -------------------------------------------------------------
            % Inputs: 
            %   print (BOOL) - Optional - default is ~gui
            %       If true, print some text with suggested values
            % -------------------------------------------------------------
            % Outputs: 
            %   suggestion (INT) - 1 OR 2.
            %       1 or 2 defines if you updated z_start or z_stop.
            % -------------------------------------------------------------
            % Extra Notes:
            % -------------------------------------------------------------
            % Author(s):
            %   Antoine Valera.
            %---------------------------------------------
            % Revision Date:
            %   25-03-2018

            if nargin < 2
                print  = ~this.gui_handles.is_gui;
            end
            
            %% Calculate values
            steps = numel(linspace(this.xyz_stage.z_start,this.xyz_stage.z_stop,this.xyz_stage.z_planes));
            start_point = this.xyz_stage.z_start;
            stop_point = this.xyz_stage.z_stop;
            planes_for_one_um_steps = round(abs(start_point-stop_point)+1);
            planes_for_cubic_voxels = round((abs(start_point-stop_point)+1) / this.aol_params.get_pixel_size());

            %% Print if requested
            if print
                fprintf('#############################\n')
                fprintf('--- from %5.1f to %5.1f with %d steps of %5.1fum\n', start_point,stop_point, steps, this.xyz_stage.z_step_res)
                fprintf('--- for 1µm steps try %i planes\n',planes_for_one_um_steps )
                fprintf('--- for cubic voxels try %i planes\n', planes_for_cubic_voxels)
                fprintf('Mosaic info : Xrange = %5.1f to %5.1f (%5.1f um); Yrange = %5.1f to %5.1f (%5.1f um); Zrange = %5.1f to %5.1f (%5.1f um)\n', this.xyz_stage.tile_xyz_start(1), this.xyz_stage.tile_xyz_stop(1), (this.xyz_stage.tile_xyz_start(1)-this.xyz_stage.tile_xyz_stop(1)) ,this.xyz_stage.tile_xyz_start(2), this.xyz_stage.tile_xyz_stop(2),(this.xyz_stage.tile_xyz_start(2)-this.xyz_stage.tile_xyz_stop(2)),this.xyz_stage.tile_xyz_start(3), this.xyz_stage.tile_xyz_stop(3),(this.xyz_stage.tile_xyz_start(3)-this.xyz_stage.tile_xyz_stop(3)))
            end
            
            %% Format output
            suggestion = [start_point,stop_point,steps,this.xyz_stage.z_step_res,planes_for_one_um_steps,planes_for_cubic_voxels,planes_for_one_um_steps];
        end        
    end
end