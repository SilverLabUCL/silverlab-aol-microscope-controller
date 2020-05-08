%% Class linking ScanParams normalized space to the Real World
%   When generating drives in ScanParams, the calculations are done in
%   normalized space. To convert distance in real spce, we need to perform
%   some scaling operation based on the current Hardware configuration, such
%   as the AOL design, the objective used, the wavelength used etc...
%   The use or correct AolParams values relies on good quality calibration of
%   the rig.
% -------------------------------------------------------------------------
% Syntax: 
%   this = AolParams()
% -------------------------------------------------------------------------
% Class Generation Inputs:
% -------------------------------------------------------------------------
% Class Methods (ignoring get()/set() methods):
%
% * Adjust timing offsets for current wavelength
%   [corr_difference_x, corr_difference_y] = obj.correct_for_wavelength()
%    
% * Round a duration to its closest number of integer clock cycles
%   [duration] = obj.discretize(duration)
%
% * Convert a Z normalized value to um
%   [z_um] = obj.convert_z_norm_to_um(z_norm, acceptance_angle)
%
% * Convert a X/Y normalized value to um
%   [x_um] = obj.convert_z_norm_to_um(x_norm, acceptance_angle)
%
% * Convert a Z um distance to normalized value
%   [norm_z] = obj.convert_z_um_to_norm(z_um, acceptance_angle, stage_pos_z)
%
% * Convert a X/Y um distance to normalized value
%   [norm_x_or_y] = obj.convert_x_um_to_norm(x_um, acceptance_angle) 
%
% * Convert cubic voxels to normalized units
%   [norm_xyz] = obj.convert_xyz_pixels_to_norm(pixels_xyz,...
%              mainscan_x_pixel_density)
%
% * Convert cubic voxels to normalized units
%   [pixel_size_um] = obj.get_pixel_size(acceptance_angle,...
%                   mainscan_x_pixel_density)
%
% * Return the ration between xy pixels and z pixels (planes)
%   [xy_to_z_um_scaling] = obj.get_xy_to_z_scaling(z_step_res, ...
%                        acceptance_angle, mainscan_x_pixel_density)
%
% -------------------------------------------------------------------------
% Extra Notes:
%
% * Calibration values are stored in setup.ini and calibration.ini
%   Make sure values are correct over there, and that
%   configuration_file_path.ini points at the correct ini file
% -------------------------------------------------------------------------
% Examples:
%
% * Create an AolParams object
%   ap = default.aol_params
%
% * Create an AolParams object for a specific lens (which must exist as
%    a section name in calibration.ini)
%   ap = default.aol_params('Olympus 40X')
%
% * Change wavelength, which also fixes calibration values
%   ap = default.aol_para
%   ap.current_wavelength = 800e-9
%
% -------------------------------------------------------------------------
%                               Notice
%
% Author(s):
%   Antoine Valera, Paul Kirkby, Geoffrey Evans, Srinivas Nadella
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
%   24-02-2020
%
% See also: default.aol_params, ScanParams
%

% TODO :
%    - see note in correct_for_wavelength and fix if necessary
%    - move convert_xyz_pixels_to_norm to scan params?
%    - convert get_pixel_size to method?
%    - Improve get_scan_params to evaluate the parent object. this way we
%    would know if its the controller one or an external aolparams
%    - REMOVE FILL TIME INSTANCES IN AQUSITION PARAMS
%    - SOEMTHING ODD IN WAVELENGTH CORRECTION

classdef AolParams < handle
    properties
        %% Clocks and delays
        synth_clock_freq            ;
        synth_data_time_interval    ;
        synth_t0                    ;
        synth_ta                    ;    
        daq_clock_freq              ;
        sampleswaitaftertrigger     ;
        aod_fill                    ;
        startup_delay               ;
        
        %% AOD Hardware related values
        num_aods                    ;
        aod_thickness               ;
        aod_spacing                 ;
        aod_xy_offsets              ;
        aod_dirs                    ;
        transducer_centre_dist      ;
        optical_offsets             ;
        aod_diff_mode               ;
        crystal_length              ;
        aod_ac_vel                  ;
        fill_time                   ;
        ord_ref_ind                 ;
        extraord_ref_ind            ;
        aod_aperture                ;
        aod_central_wavelength      ;
        aligned_central_frequency   ;
        central_frequency           ;
        pair_def_ratio              ;
        end_aod_centre_to_ref       ;

        %% Calibration related constants
        calibration_file_path       ;
        calibration_wavelength      ;
        current_objective           ;
        sum_x                       ;
        sum_y                       ;
        difference_x                ;
        difference_y                ;
        x_norm_to_um_scaling        ;
        z_norm_to_um_scaling        ;
        xy_z_norm_ratio             ;
        distortion_corr             ;
        z_refraction_correction     ;
        z_offset_norm               ;

        fov_um                      ;
        current_wavelength          ;
    end
    
    properties (Dependent = true)
        timing_offsets              ;
    end
    
    methods  
        %% ================================================================
        %% Geometric/Electronic corrections for abberations  ==============
        
        function timing_offsets = get.timing_offsets(obj) 
            %% Update timing offsets from aol_params.m 
            % -------------------------------------------------------------
            % Syntax: 
            %   timing_offsets = AolParams.timing_offsets
            % -------------------------------------------------------------
            % Inputs:
            % -------------------------------------------------------------
            % Outputs: 
            %   timing_offsets (1 * 4 FLOAT)
            %       The timing offsets used to correct the drives. 
            % -------------------------------------------------------------
            % Extra Notes:
            %   The correction uses the current and calibration
            %   wavelengths. Make sure that the sums and diffs were set at
            %   the right wavelength. See correct_for_wavelength for more
            %   details about it.
            %   Order is [X1 Y1 X2 Y2]
            % -------------------------------------------------------------
            % Author(s):
            %   Paul Kirkby, Antoine Valera
            %---------------------------------------------
            % Revision Date:
            %   30-09-2018
            
        	timing_offsets = 1e-6 * [obj.sum_x + obj.difference_x, obj.sum_y + obj.difference_y, obj.sum_x - obj.difference_x, obj.sum_y - obj.difference_y];
        end
        
        function set.current_wavelength(obj, new_wavelength)
            %% Set correct wavelength and adjust central_frequency
            % -------------------------------------------------------------
            % Syntax: 
            %   AolParams.current_wavelength = new_wavelength
            % -------------------------------------------------------------
            % Inputs:
            %   new_wavelength (FLOAT)
            %       New wavelength, in meters
            % -------------------------------------------------------------
            % Outputs: 
            % -------------------------------------------------------------
            % Extra Notes:
            % Work with with PK 21.09.2017, updated with SN 20.07.2018, and
            % swicth to set function 25.02.2020. This function should fix
            % offset with wavelength
            % -------------------------------------------------------------
            % Author(s):
            %   Paul Kirkby, Antoine Valera, Srinivas Nadella
            %---------------------------------------------
            % Revision Date:
            %   25-02-2020

            obj.current_wavelength = new_wavelength;
            obj.central_frequency = obj.calibration_wavelength * obj.aligned_central_frequency / new_wavelength;
        end

        %% ================================================================
        %% Functions related to Timing  ===================================
        
        function fill_time = get.fill_time(obj)
            %% Get fill_time in s, from number of cycles
            % -------------------------------------------------------------
            % Syntax: 
            %   fill_time = AolParams.fill_time
            % -------------------------------------------------------------
            % Inputs:
            % -------------------------------------------------------------
            % Outputs: 
            %   fill_time (FLOAT)
            %       Time, in seconds, to fill the AOD
            % -------------------------------------------------------------
            % Extra Notes:
            %   The conversion relies on synth_clock_freq/daq_clock_freq
            % -------------------------------------------------------------
            % Author(s):
            %   Geoff Evans
            %---------------------------------------------
            % Revision Date:
            %   25-02-2020
            
            fill_time = obj.discretize(obj.aod_aperture / obj.aod_ac_vel);
        end
        
        function duration = discretize(obj, duration)
            %% Round a duration to the closest number of cycles
            % -------------------------------------------------------------
            % Syntax: 
            %   duration = AolParams.duration(duration)
            % -------------------------------------------------------------
            % Inputs:
            %   duration (FLOAT)
            %       duration to round
            % -------------------------------------------------------------
            % Outputs: 
            %   duration (FLOAT)
            %       Adjusted duration
            % -------------------------------------------------------------
            % Extra Notes:
            % -------------------------------------------------------------
            % Author(s):
            %   Geoff Evans
            %---------------------------------------------
            % Revision Date:
            %   25-02-2020
            
            hcf      = gcd(obj.synth_clock_freq, obj.daq_clock_freq);
            duration = round(duration * hcf) / hcf;
        end

        %% ================================================================
        %% Geometrical conversion function ================================        

        function z_um = convert_z_norm_to_um(obj, z_norm, acceptance_angle) 
            %% Convert Normalised Z distance to um
            % -------------------------------------------------------------
            % Syntax: 
            %   z_um = AolParams.convert_z_norm_to_um(z_norm, acceptance_angle)
            % -------------------------------------------------------------
            % Inputs:
            %   z_norm (FLOAT)
            %       normalized Z distance from natural plane
            %   acceptance_angle (FLOAT)
            %       current acceptance_angle value as in
            %       ScanParams.acceptance_angle 
            % -------------------------------------------------------------
            % Outputs: 
            %   z_um (FLOAT)
            %       distance in um from natural plane           
            % -------------------------------------------------------------
            % Extra Notes:
            % -------------------------------------------------------------
            % Author(s):
            %   Antoine Valera, Geoffrey Evans
            %---------------------------------------------
            % Revision Date:
            %   30-09-2018
            
            if nargin < 3
                acceptance_angle = obj.get_scan_params();
            end
            z_um = z_norm * obj.z_norm_to_um_scaling * acceptance_angle;
        end
        
        function x_um = convert_x_norm_to_um(obj, x_norm, acceptance_angle)
            %% Convert normalised XY distances to um
            % -------------------------------------------------------------
            % Syntax: 
            %   x_um = AolParams.convert_z_norm_to_um(x_norm, acceptance_angle)
            % -------------------------------------------------------------
            % Inputs:
            %   x_norm (FLOAT)
            %       normalized XY distance from current position
            %   acceptance_angle (FLOAT)
            %       current acceptance_angle value as in
            %       ScanParams.acceptance_angle            
            % -------------------------------------------------------------
            % Outputs: 
            %   x_um (FLOAT)
            %       distance in um from current position           
            % -------------------------------------------------------------
            % Extra Notes:
            % -------------------------------------------------------------
            % Author(s):
            %   Antoine Valera, Geoffrey Evans
            %---------------------------------------------
            % Revision Date:
            %   30-09-2018
            
            if nargin < 3
                acceptance_angle = obj.get_scan_params();
            end
            x_um = x_norm * obj.x_norm_to_um_scaling * acceptance_angle; 
        end
        
        function norm_z = convert_z_um_to_norm(obj, z_um, acceptance_angle, stage_pos_z)
            %% Calculate Z offset between stage_pos_z and position z_um
            % -------------------------------------------------------------
            % Syntax: 
            %   norm_z = AolParams.convert_z_um_to_norm(z_um, acceptance_angle, stage_pos_z)
            % -------------------------------------------------------------
            % Inputs:
            %   z_um (FLOAT)
            %       Z distance in um from stage_pos_z
            %   acceptance_angle (FLOAT)
            %       current acceptance_angle value as in
            %       ScanParams.acceptance_angle 
            %   stage_pos_z (FLOAT)
            %       reference position from which z distance is calculated.
            %       Default value is 0, so that z_um is a distance.
            %       However, you can use the absolute z position (as given
            %       by the stage) if you also specifiy the natural plane
            %       absolute position in stage_pos_z.
            % -------------------------------------------------------------
            % Outputs: 
            %   norm_z (FLOAT)
            %       Norm distance in Z between z_um and stage_pos_z         
            % -------------------------------------------------------------
            % Extra Notes:
            % -------------------------------------------------------------
            % Author(s):
            %   Antoine Valera, Geoffrey Evans
            %---------------------------------------------
            % Revision Date:
            %   30-09-2018            
            
            if nargin < 3
                acceptance_angle = obj.get_scan_params();
            end
            if nargin < 4 || isempty(stage_pos_z)
                stage_pos_z = 0;
            end
            dist_from_focal_plane = (z_um - stage_pos_z);
            norm_z = dist_from_focal_plane / ((obj.z_norm_to_um_scaling * 1) * acceptance_angle); %% or .acceptance_angle
        end
        
        function norm_x_or_y = convert_x_um_to_norm(obj, x_um, acceptance_angle) 
            %% Calculate norm XY for an offset of x_um
            % -------------------------------------------------------------
            % Syntax: 
            %   norm_x_or_y = AolParams.convert_x_um_to_norm(x_um, acceptance_angle) 
            % -------------------------------------------------------------
            % Inputs:
            %   x_um (FLOAT)
            %       XY distance in um from current stage location
            %   acceptance_angle (FLOAT)
            %       current acceptance_angle value as in
            %       ScanParams.acceptance_angle 
            % -------------------------------------------------------------
            % Outputs: 
            %   norm_x_or_y (FLOAT)
            %       Norm distance in X-Y between x_um and current stage 
            %       location      
            % -------------------------------------------------------------
            % Extra Notes:
            % -------------------------------------------------------------
            % Author(s):
            %   Antoine Valera
            %---------------------------------------------
            % Revision Date:
            %   30-09-2018  
            
            if nargin < 3
                acceptance_angle = obj.get_scan_params();
            end
            norm_x_or_y = x_um / (obj.x_norm_to_um_scaling * acceptance_angle); 
        end
        
        function norm_xyz = convert_xyz_pixels_to_norm(obj, pixels_xyz, mainscan_x_pixel_density) %% Convert cubic voxels drives to norm units
            %% Convert XYZ voxels (scaled to current XY voxel size) to norm 
            % -------------------------------------------------------------
            % Syntax: 
            %   norm_xyz = AolParams.convert_xyz_pixels_to_norm(pixels_xyz, mainscan_x_pixel_density)
            % -------------------------------------------------------------
            % Inputs:
            %   pixels_xyz (3 X N FLOAT)
            %       X, Y and Z coordinates of cubic voxels to convert in
            %       normalised units. See notes for help about conversion
            %   mainscan_x_pixel_density (FLOAT)
            %       current mainscan_x_pixel_density value as in
            %       ScanParams.mainscan_x_pixel_density 
            % -------------------------------------------------------------
            % Outputs: 
            %   norm_xyz (FLOAT)
            %       X, Y and Z coordinates in normalised units.
            % -------------------------------------------------------------
            % Extra Notes:
            % xyz are expected to be cubic xy voxels.Make sure that the z
            % diemension is expressed in the same unit.
            % Natural plane (Z = 0) is set as the current plane
            % x-y = [0, 0] correspond to the first voxel of the image
            % (the corner, not the center)
            % 
            % to convert um into cubic voxels :
            %   pixels_xyz = um_xy / Controller.scan_params.get_pixel_size
            % -------------------------------------------------------------
            % Author(s):
            %   Antoine Valera
            %---------------------------------------------
            % Revision Date:
            %   30-09-2018  
            
            if nargin < 3
                [~, mainscan_x_pixel_density] = obj.get_scan_params();
            end
            %% Convert xy pixels to xy norm values
            norm_xyz(1:2,:) = ((pixels_xyz(1:2,:) ./ mainscan_x_pixel_density) * 2 ) - 1; % mainscan_x_pixel_density corresponds to norm [-1:+1]. 
            %% Convert z pixels to z norm values
            norm_xyz(3,:) = obj.xy_z_norm_ratio * (((pixels_xyz(3,:) ./ mainscan_x_pixel_density) * 2));
        end
        
       
        function fov_um = get.fov_um(obj)
            %% Return the FOV in raster mode
            % -------------------------------------------------------------
            % Syntax: 
            %   fov_um = AolParams.fov_um()
            % -------------------------------------------------------------
            % Inputs:
            % -------------------------------------------------------------
            % Outputs: 
            %   fov_um (FLOAT)
            %       The size of the FOV in um.
            % -------------------------------------------------------------
            % Extra Notes:
            % The method works in all modes. FOV correspond to the surface
            %   visible when scanning between normalised +1 and normalised
            %   -1
            % -------------------------------------------------------------
            % Author(s):
            %   Antoine Valera
            %---------------------------------------------
            % Revision Date:
            %   30-09-2018            
            
            fov_um = obj.convert_x_norm_to_um(2); % 2 gives total FOV size, because scans go from -1 to +1
        end

        function pixel_size_um = get_pixel_size(obj, acceptance_angle, mainscan_x_pixel_density)
            %% Return the size of the pixel in the main FOV
            % -------------------------------------------------------------
            % Syntax: 
            %   fov_um = AolParams.get_pixel_size(acceptance_angle, 
            %           mainscan_x_pixel_density)
            % -------------------------------------------------------------
            % Inputs:
            %   acceptance_angle (FLOAT)
            %       current acceptance_angle value as in
            %       ScanParams.acceptance_angle 
            %   mainscan_x_pixel_density (FLOAT)
            %       current mainscan_x_pixel_density value as in
            %       ScanParams.mainscan_x_pixel_density 
            % -------------------------------------------------------------
            % Outputs: 
            %   fov_um (FLOAT)
            %       The size of the FOV in um.
            % -------------------------------------------------------------
            % Extra Notes:
            %   This function returns the XY pixel size of the min FOV or
            %   of the default miniscans. If you edited manually
            %   ScanParams.voxels_for_ramp, the value will not match the
            %   current scan.
            % -------------------------------------------------------------
            % Author(s):
            %   Antoine Valera
            %---------------------------------------------
            % Revision Date:
            %   30-09-2018   
            
            if nargin < 2
                [acceptance_angle, mainscan_x_pixel_density] = obj.get_scan_params();
            end
            pixel_size_um = convert_x_norm_to_um(obj, 2, acceptance_angle) ./ mainscan_x_pixel_density;
        end
        
        function xy_to_z_um_scaling = get_xy_to_z_scaling(obj, z_step_res, acceptance_angle, mainscan_x_pixel_density)
            %% Return the ratio between xy pixels and z pixels (eg. stack planes)
            % -------------------------------------------------------------
            % Syntax: 
            %   xy_to_z_um_scaling = AolParams.get_xy_to_z_scaling(z_step_res, acceptance_angle, mainscan_x_pixel_density)
            % -------------------------------------------------------------
            % Inputs:
            %   acceptance_angle (FLOAT)
            %       current acceptance_angle value as in
            %       ScanParams.acceptance_angle 
            %   mainscan_x_pixel_density (FLOAT)
            %       current mainscan_x_pixel_density value as in
            %       ScanParams.mainscan_x_pixel_density 
            % -------------------------------------------------------------
            % Outputs: 
            %   xy_to_z_um_scaling (FLOAT)
            %       The ratio between current z planes and xy pixels, for
            %       example when doing a Z stack.
            % -------------------------------------------------------------
            % Extra Notes:
            %   This step is usually required to convert to cubic voxels
            % -------------------------------------------------------------
            % Author(s):
            %   Antoine Valera
            %---------------------------------------------
            % Revision Date:
            %   30-09-2018 
            
            if nargin < 3
                [acceptance_angle, mainscan_x_pixel_density] = obj.get_scan_params();
            end
            xy_pixel_size = obj.get_pixel_size(acceptance_angle, mainscan_x_pixel_density);
            xy_to_z_um_scaling = abs(z_step_res / xy_pixel_size);
        end
        
        function xy_z_norm_ratio = get.xy_z_norm_ratio(obj) 
            %% Return the ratio between xy norm and z norm 
            % Used for rotation and cubic voxel scaling
            % -------------------------------------------------------------
            % Syntax: 
            %   xy_z_norm_ratio = AolParams.xy_z_norm_ratio()
            % -------------------------------------------------------------
            % Inputs:
            % -------------------------------------------------------------
            % Outputs: 
            %   xy_z_norm_ratio (FLOAT)
            %       The ratio between z norm and xy norm
            % -------------------------------------------------------------
            % Extra Notes:
            % obj.xy_z_norm_ratio is used in ScanParams. 
            % -------------------------------------------------------------
            % Author(s):
            %   Antoine Valera
            %---------------------------------------------
            % Revision Date:
            %   30-09-2018             
            
            if ~isempty(obj.x_norm_to_um_scaling) && ~isempty(obj.z_norm_to_um_scaling)
                xy_z_norm_ratio = obj.x_norm_to_um_scaling / obj.z_norm_to_um_scaling;
            else
                xy_z_norm_ratio = []; % need to be recalculated 
            end
        end
        
        function set.x_norm_to_um_scaling(obj, x_norm_to_um_scaling)
            %% Scaling factor between XY norm and um
            % -------------------------------------------------------------
            % Syntax: 
            %   AolParams.x_norm_to_um_scaling = x_norm_to_um_scaling
            % -------------------------------------------------------------
            % Inputs:
            % -------------------------------------------------------------
            % Outputs: 
            %   x_norm_to_um_scaling (INT)
            %       The scaling factor between norm coordinates and um for
            %       the current hardware
            % -------------------------------------------------------------
            % Extra Notes:
            % This value is specific of each hardware configuration. If you
            % change the lense, the value must be reconfigurated. Value is
            % loaded for calibration.ini, reading the field
            % AolPara.s.current_objective. You mut reload aol_params if you
            % change the config file
            % -------------------------------------------------------------
            % Author(s):
            %   Antoine Valera
            %---------------------------------------------
            % Revision Date:
            %   30-09-2018            
            
            obj.x_norm_to_um_scaling = x_norm_to_um_scaling;      
        end
        
        function set.z_norm_to_um_scaling(obj, z_norm_to_um_scaling)
            %% Scaling factor between Z norm and um
            % -------------------------------------------------------------
            % Syntax: 
            %   AolParams.z_norm_to_um_scaling = z_norm_to_um_scaling
            % -------------------------------------------------------------
            % Inputs:
            % -------------------------------------------------------------
            % Outputs: 
            %   z_norm_to_um_scaling (INT)
            %       The scaling factor between norm coordinates and um for
            %       the current hardware
            % -------------------------------------------------------------
            % Extra Notes:
            % This value is specific of each hardware configuration. If you
            % change the lense, the value must be reconfigurated. Value is
            % loaded for calibration.ini, reading the field
            % AolPara.s.current_objective. You mut reload aol_params if you
            % change the config file
            % -------------------------------------------------------------
            % Author(s):
            %   Antoine Valera
            %---------------------------------------------
            % Revision Date:
            %   30-09-2018 
            
            obj.z_norm_to_um_scaling = z_norm_to_um_scaling;          
        end
    end
        
    methods (Hidden = true) 
        function [acceptance_angle, mainscan_x_pixel_density] = get_scan_params(obj)
            %% Evaluate current ScanParams if not provided
            % -------------------------------------------------------------
            % Syntax: 
            %   [acceptance_angle, mainscan_x_pixel_density] = AolParams.get_scan_params()
            % -------------------------------------------------------------
            % Inputs:
            % -------------------------------------------------------------
            % Outputs: 
            %   acceptance_angle (FLOAT)
            %      The current acceptance angle as defined in
            %      ScanParams.acceptance_angle 
            %   mainscan_x_pixel_density (INT)
            %      The current resolution as defined in
            %      ScanParams.mainscan_x_pixel_density             
            % -------------------------------------------------------------
            % Extra Notes:
            % Called in numerous AolParams function if acceptance_angle or
            % mainscan_x_pixel_density are not provided.
            % Warning : If you reload a former aol_params and use it to do
            % some operations involving scan_params values (eg : acceptance
            % angle), you must manualy specify the correct scan_params in
            % most functions (eg AolParams.convert_x_norm_to_um). Leaving
            % default values will use the scan_params contained in the
            % current controller, which is probably wrong.
            % -------------------------------------------------------------
            % Author(s):
            %   Antoine Valera
            %---------------------------------------------
            % Revision Date:
            %   30-09-2018 

            controller = get_existing_controller_name(true); 
            % qq : If we could evaluate the obj parent instead, it would
            % be safer in case the operation is done on previous recordings
            
            acceptance_angle = controller.scan_params.acceptance_angle;
            mainscan_x_pixel_density = controller.scan_params.mainscan_x_pixel_density;
        end      
    end
end

