%% Superclass controlling Stack and Tile ranges
%   Type doc StackAndTile.function_name or help StackAndTile.function_name 
%   to get more details about the function inputs and outputs
%
%   Some classes inherits from StackAndTile properties (eg : XyzStage)
% -------------------------------------------------------------------------
% Syntax: 
%   this = StackAndTile()
%   	Generates a StackAndTile object
% -------------------------------------------------------------------------
% Class Generation Inputs: 
% -------------------------------------------------------------------------
% Outputs: 
%   this (StackAndTile object)
% -------------------------------------------------------------------------
% Class Methods: 
%
% * Change first plane of a Z stack, and tiling starting Z
%   StackAndTile.set.z_start(z_start)
%
% * Change last plane of a Z stack, and tiling ending Z
%   StackAndTile.set.z_stop(z_stop)
%
% * Change the number of planes of a Z-stack/Tiling
%   StackAndTile.set.z_planes(z_planes)
%
% * Change the plane spacing of a Z-stack/Tiling
%   StackAndTile.set.z_step_res(z_step_res)
%
% * Update tiling starting X-Y-Z location
%   StackAndTile.set.tile_xyz_start(tile_xyz_start)
%
% * Update tiling stopping X-Y-Z location
%   StackAndTile.set.tile_xyz_stop(tile_xyz_stop)
%
% * Makes sure that X and Y start values are < to stop values
%   StackAndTile.sort_xy_limits(new_tile_xyz_start, new_tile_xyz_stop)
%
% * Get number of planes. stop_z = start_z if spacing is 0
%   [start_z, stop_z, planes_z, step_res_z] = 
%   get_planes(~, start_z, stop_z, step_res_z)
%
% * Get spacing between planes. spacing is 0 for a single plane
%   [start_z, stop_z, planes_z, step_res_z] = 
%   get_spacing(~, start_z, stop_z, planes_z)
%
% * Function that updates all the Z related values in the class.
%   StackAndTile.update_them_all(start_z, stop_z, planes_z, step_res_z)
%
% * Check if updating z_step_res requires to swap start and stop 
%   StackAndTile.test_sign_reversal(new_z_step_res)
%
% * Store X-Y-Z position for tiled mosaic and extend stack range
%   [idx] = StackAndTile.add_tile(new_tile_xyz)
%
% * Reads current stack Z direction, and tell if new value
%   [idx] = StackAndTile.guess_if_new_min_or_new_max(new_z)
%
% * Calculate Pockel values for a range of Z planes  
%   [pockel_values] = 
%   StackAndTile.get_pockels_vs_Z_values( interpolation_mode,
%                                           pockels_start,
%                                           pockels_stop,
%                                           Z_values,
%                                           rendering)
%
% * Move to stack centre or return stack centre value        
%   stack_center = XyzStage.move_to_stack_center(move_to_stack_center)
% -------------------------------------------------------------------------
% Extra Notes:
% * To get detailled information about a function, use the matlab doc or help
%   function.
%
% * Any change in the Z component of one of them affects the other.
%
% * All values are in um.
%
% * Changing the sign of step_res swap start and stop positions for both
%   tiling and stack_res.
%
% * Step resolution has priority over num planes when changing z_start or
%   z_stop. Changing z step or numplanes will never change z_start or
%   z_stop.
%
% * For tiles, X and Y start are the smallest values and X and  end are the
%   highest ones. Tiling is therefore always done in the same direction in
%   XY
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
%   07-05-2020
%
% See also: XyzStage, stack_params, testing_StackAndTiles


classdef StackAndTiles < handle   
    properties
        tile_xyz_start = [0, 0, 1];
        tile_xyz_stop  = [0, 0,-1];
        z_start  =  1;
        z_stop   = -1;
        z_step_res = -1;
        z_planes = 3;
    end
    
    properties (Access = private)
        primary_call = true; %interal lock to prevent recursive loops
    end
    
    methods
        function this = StackAndTiles()
            %% StackAndTiles Object Constructor. 
            % -------------------------------------------------------------
            % Syntax: 
            %   this = StackAndTiles()
            % -------------------------------------------------------------
            % Inputs:
            % -------------------------------------------------------------
            % Outputs: 
            %   this (StackAndTiles object)
            %   a object to control the stacks and tiling range, keeping
            %   start, stop, step size and numplanes coherent between the
            %   stack and tiling ranges.
            % -------------------------------------------------------------
            % Extra Notes:
            % -------------------------------------------------------------
            % Author(s):
            %   Antoine Valera. 
            %---------------------------------------------
            % Revision Date:
            %   16-02-2019
        end

        function set.z_start(this, z_start)
            %% Change first plane of a Z stack, and tiling starting Z
            %   Update stack and tile starting plane. If called externally,
            %   update planes and z-step sizes too
            % -------------------------------------------------------------
            % Syntax: 
            %   StackAndTiles.z_start = new_value
            % -------------------------------------------------------------
            % Inputs:
            %   z_start (FLOAT)
            %       The position in um of the stack starting plane
            % -------------------------------------------------------------
            % Outputs: 
            % -------------------------------------------------------------
            % Extra Notes:
            % -------------------------------------------------------------
            % Author(s):
            %   Antoine Valera
            %---------------------------------------------
            % Revision Date:
            %   16-02-2018             
            
            this.z_start = z_start;
            if this.primary_call
                [start_z,stop_z,planes_z,~] = this.get_planes(this.z_start,this.z_stop,this.z_step_res);
                [start_z,~,planes_z,step_res_z] = this.get_spacing(start_z, stop_z, planes_z);
                if sign(start_z - stop_z) == sign(step_res_z)
                    step_res_z = step_res_z * -1;
                end
                this.update_them_all(start_z,[],planes_z,step_res_z);                
            end
        end
        
        function set.z_stop(this, z_stop)
            %% Change last plane of a Z stack, and tiling ending Z
            %   Update stack and tile stopping plane. If called externally,
            %   update planes and z-step sizes too.
            % -------------------------------------------------------------
            % Syntax: 
            %   StackAndTiles.z_stop = new_value
            % -------------------------------------------------------------
            % Inputs:
            %   z_stop (FLOAT)
            %       The position in um of the stack stopping plane
            % -------------------------------------------------------------
            % Outputs: 
            % -------------------------------------------------------------
            % Extra Notes:
            % -------------------------------------------------------------
            % Author(s):
            %   Antoine Valera
            %---------------------------------------------
            % Revision Date:
            %   16-02-2018  
            
            this.z_stop = z_stop;
            if this.primary_call  
                [start_z,stop_z,planes_z,step_res_z] = this.get_planes(this.z_start, this.z_stop, this.z_step_res);
                [~,stop_z,planes_z,~] = this.get_spacing(start_z, stop_z, planes_z);
                if sign(start_z - stop_z) == sign(step_res_z)
                    step_res_z = step_res_z * -1;
                end
                this.update_them_all([],stop_z,planes_z,step_res_z);              
            end
        end
        
        function set.z_planes(this, z_planes)
            %% Change the number of planes of a Z-stack/Tiling
            %   Update the number of planes in the stack. If called 
            %   externally, update the spacing between planes too
            % -------------------------------------------------------------
            % Syntax: 
            %   StackAndTiles.z_planes = new_value
            % -------------------------------------------------------------
            % Inputs:
            %   z_planes (INT)
            %       The number of planes between z_start and z_stop
            % -------------------------------------------------------------
            % Outputs: 
            % -------------------------------------------------------------
            % Extra Notes:
            % -------------------------------------------------------------
            % Author(s):
            %   Antoine Valera
            %---------------------------------------------
            % Revision Date:
            %   16-02-2018  

            this.z_planes = abs(z_planes);
            if this.primary_call
                [start_z,stop_z,~,step_res_z] = this.get_spacing(this.z_start, this.z_stop, this.z_planes);
                [start_z,stop_z,planes_z,step_res_z] = this.get_planes(start_z,stop_z,step_res_z);
                this.update_them_all(start_z,stop_z,planes_z,step_res_z);
            end
        end
        
        function set.z_step_res(this, z_step_res)
            %% Change the plane spacing of a Z-stack/Tiling
            %   Update the spacing of planes in the stack. If called 
            %   externally, update the number of planes too. If sign is
            %   changed, invert Z start and Z stop.
            % -------------------------------------------------------------
            % Syntax: 
            %   StackAndTiles.z_step_res = new_value
            % -------------------------------------------------------------
            % Inputs:
            %   z_step_res (INT)
            %       Spacing of the planes between z_start and z_stop
            % -------------------------------------------------------------
            % Outputs: 
            % -------------------------------------------------------------
            % Extra Notes:
            %   Sign of the steps indicates the direction of the
            %   stack/tiling
            % -------------------------------------------------------------
            % Author(s):
            %   Antoine Valera
            %---------------------------------------------
            % Revision Date:
            %   16-02-2018  

            this.test_sign_reversal(z_step_res); %% swap start and stop if you manually change sign
            
            this.z_step_res = z_step_res;
            if this.primary_call
                [start_z,stop_z,planes_z,~] = this.get_planes(this.z_start, this.z_stop, this.z_step_res);
                [start_z,stop_z,planes_z,step_res_z] = this.get_spacing(start_z, stop_z, planes_z);
                this.update_them_all(start_z,stop_z,planes_z,step_res_z);
            end
        end
        
        function set.tile_xyz_start(this, tile_xyz_start)
            %% Update tiling starting X-Y-Z location
            %   Update the tiling starting range in X-Y to this new value.
            %   Set the new value as a stack starting plane (and update
            %   stack range, res and n planes accordingly).
            % -------------------------------------------------------------
            % Syntax: 
            %   StackAndTiles.tile_xyz_start = new_value
            % -------------------------------------------------------------
            % Inputs:
            %   tile_xyz_start (FLOAT)
            %       X-Y-Z starting value of the new Tiling coordinate
            % -------------------------------------------------------------
            % Outputs: 
            % -------------------------------------------------------------
            % Extra Notes:
            %   Updating tiling range will change your stack range (Only
            %   defined by Z limits, so X-Y is never moved when doing Z
            %   stacks)
            % -------------------------------------------------------------
            % Author(s):
            %   Antoine Valera
            %---------------------------------------------
            % Revision Date:
            %   16-02-2018  

            this.tile_xyz_start = tile_xyz_start;
            if this.primary_call
                this.z_start = this.tile_xyz_start(3);
                this.sort_xy_limits(tile_xyz_start, []);
            end
        end
        
        function set.tile_xyz_stop(this, tile_xyz_stop)
            %% Update tiling stopping X-Y-Z location
            %   Update the tiling stopping range in X-Y to this new value.
            %   Set the new value as a stack stopping plane (and update
            %   stack range, res and n planes accordingly).
            % -------------------------------------------------------------
            % Syntax: 
            %   StackAndTiles.tile_xyz_stop = new_value
            % -------------------------------------------------------------
            % Inputs:
            %   tile_xyz_stop (FLOAT)
            %       X-Y-Z stopping value of the new Tiling coordinate
            % -------------------------------------------------------------
            % Outputs: 
            % -------------------------------------------------------------
            % Extra Notes:
            %   Updating tiling range will change your stack range (Only
            %   defined by Z limits, so X-Y is never moved when doing Z
            %   stacks)
            % -------------------------------------------------------------
            % Author(s):
            %   Antoine Valera
            %---------------------------------------------
            % Revision Date:
            %   16-02-2018  

            this.tile_xyz_stop = tile_xyz_stop;    
            if this.primary_call
                this.z_stop = this.tile_xyz_stop(3);
                this.sort_xy_limits([], tile_xyz_stop);
            end
        end
        
        
        function sort_xy_limits(this, new_tile_xyz_start, new_tile_xyz_stop)
            %% Make sure that X and Y start values are < to stop values
            %   Use internally by set.tile_xyz_start and set.tile_xyz_stop
            % -------------------------------------------------------------
            % Syntax: 
            %   StackAndTiles.tile_xyz_stop = new_value
            % -------------------------------------------------------------
            % Inputs:
            %   new_tile_xyz_start ([3 x 1] INT)
            %       X-Y-Z new starting location
            %
            %   new_tile_xyz_stop ([3 x 1] INT)
            %       X-Y-Z new stopping location
            % -------------------------------------------------------------
            % Outputs: 
            % -------------------------------------------------------------
            % Extra Notes:
            % -------------------------------------------------------------
            % Author(s):
            %   Antoine Valera
            %---------------------------------------------
            % Revision Date:
            %   16-02-2018  
            
            this.primary_call = false;
            temp_start = this.tile_xyz_start;
            temp_stop  = this.tile_xyz_stop ;
            for ax = 1:2
                if ~isempty(new_tile_xyz_start) && new_tile_xyz_start(ax) > temp_stop(ax)
                    temp_stop(ax)  = new_tile_xyz_start(ax);
                    temp_start(ax) = this.tile_xyz_stop(ax);
                elseif ~isempty(new_tile_xyz_start)
                    temp_start(ax) = new_tile_xyz_start(ax);
                elseif ~isempty(new_tile_xyz_stop) && new_tile_xyz_stop(ax) < temp_start(ax)
                    temp_start(ax) = new_tile_xyz_stop(ax);
                    temp_stop(ax) = this.tile_xyz_start(ax);
                elseif ~isempty(new_tile_xyz_stop)   
                    temp_stop(ax)  = new_tile_xyz_stop(ax);
                end
            end
            this.tile_xyz_start = temp_start;
            this.tile_xyz_stop = temp_stop;            
            this.primary_call = true;
        end
        
        function [start_z, stop_z, planes_z, step_res_z] = get_planes(~, start_z, stop_z, step_res_z)
            %% Get number of planes. stop_z = start_z if spacing is 0
            %   Get the expected number of planes, knowing the current
            %   start, stop and resolution. start and stopped are fixed, so
            %   step_res_z can is auto adjusted to return the closest
            %   possible value. Values are returned, but not updated in the
            %   class
            % -------------------------------------------------------------
            % Syntax: 
            %   [start_z, stop_z, planes_z, step_res_z] = 
            %        StackAndTiles.get_planes(start_z, stop_z, step_res_z)
            % -------------------------------------------------------------
            % Inputs:
            %   start_z (FLOAT)
            %       Z plane in um of the start of the stack
            %
            %   stop_z (FLOAT)
            %       Z plane in um of the stop of the stack
            %
            %   step_res_z (FLOAT)
            %       Z spacing between planes. The sign will be ignored, and
            %       set automatically based on the start and stop values.
            %
            % -------------------------------------------------------------
            % Outputs: 
            %   start_z (FLOAT)
            %       Z plane in um of the start of the stack
            %
            %   stop_z (FLOAT)
            %       Z plane in um of the stop of the stack
            %
            %   planes_z (FLOAT)
            %       number of Z planes between start and stop values  
            %
            %   step_res_z (FLOAT)
            %       Z spacing between planes.            
            % -------------------------------------------------------------
            % Extra Notes:
            % -------------------------------------------------------------
            % Author(s):
            %   Antoine Valera
            %---------------------------------------------
            % Revision Date:
            %   16-02-2018  

            if isinf(step_res_z) || isnan(step_res_z) || (step_res_z == 0 && stop_z == start_z)
            	step_res_z = 0;
            	planes_z = 1;
                stop_z = start_z;
            elseif step_res_z == 0 && stop_z ~= start_z
                step_res_z = stop_z - start_z;
                planes_z = 2;
                fprintf('You set a number of planes > 1, but there was no spacing. Z planes were set to 2 automatically (Zstart and Zstop).\n')
            else
                planes_z = round(abs((stop_z - start_z) / step_res_z) + 1);
            end
        end
        
        function [start_z, stop_z, planes_z, step_res_z] = get_spacing(~, start_z, stop_z, planes_z)
            %% Get spacing between planes. spacing is 0 for a single plane
            %   Get the spacing between planes, knowing the current
            %   start, stop and number of planes. start and stopped are
            %   fixed, so the sign of step_res_z depends on the direction
            %   of the stack. Values are returned, but not updated in the
            %   class
            % -------------------------------------------------------------
            % Syntax: 
            %   [start_z, stop_z, planes_z, step_res_z] = 
            %         StackAndTiles.get_spacing(start_z, stop_z, planes_z)
            % -------------------------------------------------------------
            % Inputs:
            %   start_z (FLOAT)
            %       Z plane in um of the start of the stack
            %
            %   stop_z (FLOAT)
            %       Z plane in um of the stop of the stack
            %
            %   planes_z (FLOAT)
            %       Number of planes
            %
            % -------------------------------------------------------------
            % Outputs: 
            %   start_z (FLOAT)
            %       Z plane in um of the start of the stack
            %
            %   stop_z (FLOAT)
            %       Z plane in um of the stop of the stack
            %
            %   planes_z (FLOAT)
            %       number of Z planes between start and stop values  
            %
            %   step_res_z (FLOAT)
            %       Z spacing between planes. 
            % -------------------------------------------------------------
            % Extra Notes:
            % -------------------------------------------------------------
            % Author(s):
            %   Antoine Valera
            %---------------------------------------------
            % Revision Date:
            %   16-02-2018  
            
            if isinf(planes_z) || isnan(planes_z) || planes_z == 0 || planes_z == 1 || stop_z == start_z
            	step_res_z = 0;
            	planes_z = 1;
                start_z = mean([stop_z, start_z]); %this won't do anything unless they are different
                stop_z = start_z;
                fprintf('You set the number of planes to 1, so z_stop was automatically set at the midpoint between zstart and zstop\n')
            else
                step_res_z = (stop_z - start_z) / (planes_z - 1);
            end
        end
        
        function update_them_all(this, start_z, stop_z, planes_z, step_res_z)
            %% Function that updates all the Z related values in the class.
            % -------------------------------------------------------------
            % Syntax: 
            %   [start_z, stop_z, planes_z, step_res_z] = 
            %         StackAndTiles.update_them_all(start_z, stop_z, step_res_z)
            % -------------------------------------------------------------
            % Inputs:
            %   start_z (FLOAT)
            %       Z plane in um of the start of the stack
            %
            %   stop_z (FLOAT)
            %       Z plane in um of the stop of the stack
            %
            %   step_res_z (FLOAT)
            %       Z spacing between planes. 
            % -------------------------------------------------------------
            % Outputs: 
            % -------------------------------------------------------------
            % Extra Notes:
            % -------------------------------------------------------------
            % Author(s):
            %   Antoine Valera
            %---------------------------------------------
            % Revision Date:
            %   16-02-2018  

            this.primary_call = false; %% bloc all the set functions
            if ~isempty(start_z)
                this.z_start = start_z;
                this.tile_xyz_start(3) = start_z;
            end
            if ~isempty(stop_z)
                this.z_stop = stop_z;
                this.tile_xyz_stop(3) = stop_z;
            end
            this.z_planes = planes_z;
            if ~isempty(step_res_z)
                this.z_step_res = step_res_z;
            end
            this.primary_call = true; %% release all the set functions
        end
        
        function test_sign_reversal(this, new_z_step_res)
            %% Check if updating z_step_res requires to swap start and stop 
            % -------------------------------------------------------------
            % Syntax: 
            %   StackAndTiles.test_sign_reversal(new_z_step_res)
            % -------------------------------------------------------------
            % Inputs:
            %   new_z_step_res (FLOAT)
            %       new required Z spacing between planes. The sign is
            %       compared with the sign of the previous value. 
            % -------------------------------------------------------------
            % Outputs: 
            % -------------------------------------------------------------
            % Extra Notes:
            % -------------------------------------------------------------
            % Author(s):
            %   Antoine Valera
            %---------------------------------------------
            % Revision Date:
            %   16-02-2018 
            
            if this.primary_call && (sign(new_z_step_res) ~= sign(this.z_step_res))
                this.primary_call = false; %% bloc all the set functions
                    this.z_start = this.tile_xyz_stop(3);
                    this.z_stop = this.tile_xyz_start(3);
                    this.tile_xyz_start(3) = this.z_start;
                    this.tile_xyz_stop(3) = this.z_stop;
                this.primary_call = true; %% restore previous state
            end
        end
        
        %% ###### Tiling related functions #######
        
        function idx = add_tile(this, new_tile_xyz)
            %% Store X-Y-Z position for tiled mosaic and extend stack range
            %   Update the tiling range to include the input X-Y-Z
            %   location, if one or several of the location are not
            %   included in the current tiling limits. Z stack range (z
            %   start, res and planes) is updated accordingly.
            % -------------------------------------------------------------
            % Syntax: 
            %   idx = StackAndTiles.add_tile(new_tile_xyz)
            % -------------------------------------------------------------
            % Inputs:
            %   new_tile_xyz (FLOAT)
            %       X-Y-Z value of the new location to add to the tiling
            %       range
            % -------------------------------------------------------------
            % Outputs: 
            %   idx (INT) - 1 or 2
            %       If 1, the new tile location if further than the current
            %       starting point of the tiling (direction is defined by
            %       step_res). Z-start is updated with the new value.
            %       If 2, the new tile location if further than the current
            %       stopping point of the tiling (direction is defined by
            %       step_res). Z stop is updated with the new value.
            % -------------------------------------------------------------
            % Extra Notes:
            %   Sign of the steps indicates the direction of the
            %   stack/tiling in Z. In X-Y, starting values are the most
            %   negative and stopping values are the most positive.
            % -------------------------------------------------------------
            % Author(s):
            %   Antoine Valera
            %---------------------------------------------
            % Revision Date:
            %   16-02-2018  
            
            %% Update Z min and max by calling a set function
            idx = this.guess_if_new_min_or_new_max(new_tile_xyz(3));
            if idx == 1
                this.z_start = new_tile_xyz(3);
            elseif idx == 2
                this.z_stop = new_tile_xyz(3);
            end
            
            %% Update tiling range in x and y.
            % start have the smallest values, stop the highest
            this.primary_call = false;
            for ax = 1:2
                if new_tile_xyz(ax) < this.tile_xyz_start(ax) % if it's a new min
                    fprintf('new tiling minimum set on axis %d \n', ax)
                    this.tile_xyz_start(ax) = new_tile_xyz(ax);
                end
                if new_tile_xyz(ax) > this.tile_xyz_stop(ax) % if it's a new max
                    fprintf('new tiling maximum set on axis %d \n', ax)
                    this.tile_xyz_stop(ax) = new_tile_xyz(ax);
                end
            end
            this.primary_call = true;
        end
        
        function idx = guess_if_new_min_or_new_max(this, new_z)
            %% Reads current stack Z direction, and tell if new value
            % should extend it (and in which direction)
            % -------------------------------------------------------------
            % Syntax: 
            %   idx = StackAndTiles.guess_if_new_min_or_new_max(new_z)
            % -------------------------------------------------------------
            % Inputs:
            %   new_z (FLOAT)
            %       new Z value.
            % -------------------------------------------------------------
            % Outputs: 
            %   idx (INT) - 1 or 2
            %       If 1, the Z if further than the current starting point 
            %       of the stack (direction is defined by step_res). 
            %       If 2, the Z if further than the current stopping point 
            %       of the stack (direction is defined by step_res). 
            % -------------------------------------------------------------
            % Extra Notes:
            %   Sign of the steps indicates the direction of the
            %   stack in Z.
            % -------------------------------------------------------------
            % Author(s):
            %   Antoine Valera
            %---------------------------------------------
            % Revision Date:
            %   16-02-2018  
            
            if         ((this.z_step_res > 0) && (new_z >= this.z_stop))...  %if zstart is at the bottom and zstop at the top
                    || ((this.z_step_res < 0) && (new_z <= this.z_stop))     %if zstart is at the top and zstop at the bottom
                idx = 2; %new endpoint
            elseif     ((this.z_step_res > 0) && (new_z <= this.z_start))... %if z start is at the bottom and stop at the top
                    || ((this.z_step_res < 0) && (new_z >= this.z_start))    %if zstart is at the top and zstop at the bottom
                idx = 1; %new startpoint
            else
                idx = 0;
            end
        end
        
        %% ###### Pockels related functions #######
        
        function pockel_values = get_pockels_vs_Z_values(this, interpolation_mode, pockels_start, pockels_stop, Z_values, rendering)
            %% Calculate Pockel values for a range of Z planes   
            % -------------------------------------------------------------
            % Syntax: 
            %   pockel_values = 
            %   StackAndTiles.get_pockels_vs_Z_values( interpolation_mode,
            %                                          pockels_start,
            %                                          pockels_stop,
            %                                          Z_values,
            %                                          rendering)                     
            % -------------------------------------------------------------
            % Inputs:
            %   interpolation_mode (STR) any in {'linear', 'exponential'}
            %       Interpolation method for pockel cells
            %
            %   pockels_start (FLOAT) value between 0 and 2
            %       Voltage of Pockels for Z_start
            %
            %   pockels_stop (FLOAT) value between 0 and 2
            %       voltage of Pockels for Z_stop
            %
            %   Z_values (N x 1 FLOAT) 
            %       Z plane in um of each linescan
            %
            %   rendering (BOOL)
            %       If true, plot pockel value vs depth
            % -------------------------------------------------------------
            % Outputs: 
            %   pockel_values (N x 1 FLOAT) values between 0 and 2
            %       Interpolated pockel value for each drives input in
            %       Z_values.
            % -------------------------------------------------------------
            % Extra Notes:
            %   This code will interpolate pockel values between Z start
            %   and Z stop, providing that lowest pockel value is
            %   associated with the most superficial -plane, and the
            %   highest pockel value is for the deepest plane.
            %   For exponential interpolation, tau is fixed at 5
            %   (hardcoded, best value TBD)
            % -------------------------------------------------------------
            % Author(s):
            %   Antoine Valera
            %---------------------------------------------
            % Revision Date:
            %   16-02-2018 
            
            if nargin < 2 || isempty(interpolation_mode)
                interpolation_mode = 'linear'; 
            end
            if nargin < 4 || isempty(pockels_start) || isempty(pockels_stop)
                pockels_start = 0;
                pockels_stop = 0;
            end
            if nargin < 5 || isempty(Z_values) %qq could dtected                 
                Z_values = linspace(this.z_start, this.z_stop, this.z_planes);
            end
            if nargin < 6 || isempty(rendering) %qq could dtected                 
                rendering = true;
            end
            
            tau = 5; %% QQ should be measured
            
            %% Adjust limits according to stack direction
            if this.z_stop < this.z_start
                stack_range = [this.z_start, this.z_stop];
                pockel_range = [pockels_start, pockels_stop];
            else
                stack_range = [this.z_stop, this.z_start];
                pockel_range = [pockels_stop, pockels_start];
            end    

            %% Adjust limits according to stack direction
            % this is valid for a system where : 
            % higher pockel = higher laser power = closer to the surface = positive stage values
            if this.z_start > this.z_stop && pockels_start > pockels_stop
                error('Z start is above Z stop (normal stack) but pockel start is higher. The topmost Z needs the lowest pockel value. Check your limits')
            elseif this.z_start < this.z_stop && pockels_start < pockels_stop
                error('Z start is below Z stop (reversed stack) but pockel stop is higher. The topmost Z needs the lowest pockel value. Check your limits')
            end
            
            %% Interpolate pockel using the defined input function
            n_planes = numel(Z_values);
            if n_planes == 1
                if this.z_start == this.z_stop
                    pockel_values = mean([pockels_start, pockels_stop]);
                    planes = this.z_start;
                else
                    planes = linspace(this.z_start, this.z_stop, 100);
                    pockel_values = interp1(planes, linspace(pockels_start, pockels_stop, 100), Z_values, 'nearest', 'extrap');
                end
                fit = unique(pockel_values);
            elseif pockel_range(1) == pockel_range(2)
                pockel_values = ones(1, n_planes) * pockel_range(1);
                fit = ones(1, n_planes) * pockel_range(1);
                planes = Z_values;
            elseif strcmp(interpolation_mode, 'linear') %% Linear interpolation of pockel values between stack planes
                planes = linspace(this.z_start, this.z_stop, n_planes);
                pockel_values = interp1(planes, linspace(pockels_start, pockels_stop, size(Z_values,2)), Z_values, 'nearest', 'extrap');
                fit = pockel_values;
            elseif strcmp(interpolation_mode, 'exponential') %% Exponential decay of pockel values between stack planes
                planes = linspace(stack_range(1),stack_range(2),100);                
                amp = pockel_range(2)-pockel_range(1);

                if pockel_range(1) ~= pockel_range(2)
                    fit = pockel_range(2) -  (amp * exp( tau/(stack_range(1)-stack_range(2))*(planes-stack_range(1))));
                    pockel_values = interp1(planes,fit,Z_values,'nearest','extrap');
                end
            end

            %% Plot the Pockel values that will be used
            if rendering
                figure(1013);cla();plot(Z_values,pockel_values,'ro-');hold on
                ylim([0,2]);hold on;
                xlabel('depth (um)')
                ylabel('pockel cell voltage (V)')
                plot(planes,fit,'bo-');hold on
            end
        end
        
        function stack_center = move_to_stack_center(this, move_to_stack_center)
            %% Move to, or return the value of the z stack center
            % The center is defined as the mean between 
            % StackAndTiles.z_start and StackAndTiles.z_stop
            % -------------------------------------------------------------
            % Syntax: 
            %   stack_center = 
            %      StackAndTiles.move_to_stack_center(move_to_stack_center)
            % -------------------------------------------------------------
            % Inputs: 
            %   move_to_stack_center(BOOL) - Optional  - default is true
            %                                   If true, moves the stage.
            %                                   Otherwise, just return the
            %                                   theoretical stack center
            % -------------------------------------------------------------------------
            % Outputs:
            % 	stack_center(DOUBLE) : 
            %                                   Stack Z location
            % -------------------------------------------------------------------------
            % Extra Notes:
            % -------------------------------------------------------------------------
            % Author(s):
            %   Antoine Valera
            % -------------------------------------------------------------------------
            % Revision Date:
            %   07-02-2018
            
            if nargin < 2 || isempty(move_to_stack_center)
                move_to_stack_center = true;
            end

            stack_center = mean([this.z_start this.z_stop]);
            if move_to_stack_center && this.active
                init_pos = this.get_position();
                this.move_abs([init_pos(1), init_pos(2), stack_center]);
            end
        end
    end
end