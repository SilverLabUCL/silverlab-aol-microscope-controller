%% Class for AOL scan related methods
%	The methods are able to generate ramps for AOL scanning, as well as
%   associated variables such as associated power, scan angle etc...
%   ScanParams methods exists in normalized space. Scaling (and therefore
%   conversion into micrometers, relation with FOV etc...) requires an
%   AolParams object. For conveniency, there is "aol_params_handle" field,
%   which is a handle for the current aol_params object. If you do some
%   analysis and reload a previouly acquired ScanParams Object, make sure
%   that the right aol_params object is attached to it.
% -------------------------------------------------------------------------
% Syntax: 
%   this = ScanParams(aol_params)
% -------------------------------------------------------------------------
% Class Generation Inputs:
%   aol_params (AOLParams object handle) - Optional - default is
%                                          current Controller.aol_params
%       AOLParams object handle, usually the one in the controller.
%       
% -------------------------------------------------------------------------
% Class Methods (ignoring get()/set() methods):
%
% * Generate Normalized ramps. 
%   [start, stop] = obj.handle_image_start_stops()
%    
% * helper for handle_image_start_stops
%   obj.generate_grid_diagonal()
%
% * helper for handle_image_start_stops
%   obj.generate_rows()
%
% * Generate vector representation of patches
%   [boxes] = obj.generate_miniscan_boxes(corner, v1, v2, v3)
%
% * Performs a rotation of start & stop using ScanParams.angles
%   [start, stop] = obj.rotate(start,stop,use_ratio)
%
% * Set all z at the same value
%   [fps, cycle_duration, line_duration] = obj.get_fps(averages)
%
% * ...
%   [amp0, amp1, amp2] = obj.amp(a, b, c))
%
% * ...
%   [c_val] = obj.c()
%
% * ...
%   [d_val] = obj.d()
%
% * Display drives/voxels location in normalized space
%   obj.plot_drives(mode, fig_nb)
%
% -------------------------------------------------------------------------
% Extra Notes:
%
%   If there was a massive change the acquisition system, check if
%   low_aod_delay_cycles_limit is still right
%
% -------------------------------------------------------------------------
% Examples: 
%
% * Create a ScanParams object (Full frame, rester, using default values)
%   sp = default.scan_params
%
% * Change resolution
%   sp = default.scan_params;
%   sp.mainscan_x_pixel_density = 256;
%
% * Zoom 2X
%   sp = default.scan_params;
%   sp.acceptance_angle = sp.acceptance_angle/2;
%
% * Offset scan in Z by -1 normalized Z unit
%   sp = default.scan_params;
%   sp.start_norm_raw(3,:) = -1
%
%  More examples can be found in testing_ScanParams or individual function
%  documentation.
%
% -------------------------------------------------------------------------
%                               Notice
%
% Author(s): Antoine Valera, Boris Marin, Geoffrey Evans, Vicky Griffiths
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
% See also: AolParams, default.scan_params, testing_ScanParams
%

% TODO :
%    - use ramps or drives for terminology?
%    - pockels_raw will be wrong until you send the drives.
%    - generate_miniscan_boxes could be improved
%    - The AOL_handle fields management could be improved (when loading
%      external ScanParams for instance)

classdef ScanParams < handle
    properties
        imaging_mode    	; % {'raster','miniscan', 'functional' or 'pointing'}. 
                              % Scan Mode to use for lines/points generation 
        start_norm_raw      ; % In Raster/Pointing, Normalized offset of the scan
                              % In Miniscan/Functional X,Y and Z starting point per ramp.
        stop_norm_raw       ; % In Raster/Pointing, same as start_norm_raw
                              % In Miniscan/Functional X,Y and Z stopping point per ramp.
        voxel_time          ; % dwell time per pixel in s
        amp_raw             ; % RF power to use per ramp, for each AOD crystal
        voxels_for_ramp     ; % Number of voxels per ramp. see also fixed_res and fixed_len
        fixed_res = true    ; % false to allow variable number of pixels per line
        fixed_len = true    ; % false to allow line scans with variable length.
        fixed_len_tol = 0.06; % tolerance for "fixed length". Give a bit of slack to the caluclations
        pockels_raw         ; % Pockel cell value (Power) per ramp    
        aod_delay_cycles    ; % SWAT - AOD fill - HW delay (delay between end of fill time and beginning of acquisition)
        low_aod_delay_cycles_limit = 262; % Min Delay in Controller from trigger to start of ramp (in 200MHz cycles)
        cubic_norm_distance ; % Ramp lengths in cubic normalized unit (as in, XY mormalized units)
        
        acceptance_angle    ; % beam acceptace angle. Controls Zoom 

        angles              ; % rotation angle / Rotation matrix
        quaternions = true  ; % Define if we use a rotation matrix or quaternions

        mainscan_x_pixel_density  ; % Resolution in the [-1 +1] Normalized space

        X_Y_swapped         ; % Rig specific.

        c_waves             ; %
        d_waves             ; %
        D                   ; % Curvature setting 
        
        aol_params_handle = [];% handle to the correct AOLParams object
    end

    properties (Dependent = true)
        start_norm          ; % X,Y and Z starting point per ramp.
        stop_norm           ; % X,Y and Z stopping point per ramp.
        centre_norm         ; % X,Y and Z mid-point per ramp.
        displacement_norm   ; % X,Y and Z norm length per ramp.
        num_drives          ; % Number of ramps
        num_voxels          ; % Total number of voxels in all ramps
        pixel_size_norm     ; % estimated nomalized pixel size per ramp
        fps                 ; % Number of frame per second, ignoring MC
        scan_time           ; % Scan time per ramp (dwell * n_pixel)
        full_time           ; % Total time per line (fill_time + scan_time)
    end
    
    properties (Hidden = true)
        mainscan_voxel_density_1D ; % backcompatibility fix. replaced by mainscan_x_pixel_density
    end

    methods
        function obj = ScanParams(aol_params)
            if nargin
                obj.aol_params_handle = aol_params;
            end
        end
        
        function aol_params_handle = get.aol_params_handle(obj)
            %% Return / Set up & return the aol_params handle
            % -------------------------------------------------------------
            % Syntax:
            %   aol_params_handle = ScanParams.aol_params_handle
            % -------------------------------------------------------------
            % Inputs:
            % -------------------------------------------------------------
            % Outputs:
            %   aol_params_handle (AOLParams object handle)
            %       AOLParams object handle, usually the one in the
            %       controller
            % -------------------------------------------------------------
            % Extra Notes:
            %   This is a fix when the scan_param has been reset/reloaded
            %   from an external one and the aol_handle is
            %   corrupted/missing
            % -------------------------------------------------------------
            % Author(s):
            %   Antoine Valera.
            %--------------------------------------------------------------
            % Revision Date:
            %   04-10-2019
            
            if isempty(obj.aol_params_handle)
                preexisting_controller = get_existing_controller_name(true);
                if ~isempty(preexisting_controller) % empty when loading a header for example
                    aol_params_handle = preexisting_controller.aol_params;
                    obj.aol_params_handle = aol_params_handle; % also set it right
                else
                    aol_params_handle = [];
                end
            else
                aol_params_handle = obj.aol_params_handle;
            end
        end
        
        function [start, stop] = handle_image_start_stops(obj)
            %% Generate the normalized ramps depending on imaging mode
            % -------------------------------------------------------------
            % Syntax:
            %   [start, stop] = ScanParams.handle_image_start_stops()
            % -------------------------------------------------------------
            % Inputs:
            % -------------------------------------------------------------
            % Outputs:
            %   start (3 x num_drives DOUBLE)
            %       X Y and Z normalised coordinates of the starting point
            %       of each ramp
            %
            %   stop (3 x num_drives DOUBLE)
            %       X Y and Z normalised coordinates of the stopping point
            %       of each ramp
            % -------------------------------------------------------------
            % Extra Notes:
            %   Depending on obj.imaging_mode, generates the normalised
            % X-Y-Z coordinates of each ramp. The function is called be
            % several dependant object, so make sure to stay in the right
            % imaging mode, or the ramps could be overwritten
            %   In raster mode, ramps re between -1 and +1 normalised, and
            % FOV depends on the acceptance angle.
            %   In Pointing mode ...
            %   In Functional or Miniscan mode, start and stop values are
            % read directly from obj.start_norm_raw and obj.stop_norm_raw
            % which means the values must be set manually for anything
            % different from the full frame raster (the default frame when
            % in miniscan mode) Pixel size is defined by
            % mainscan_x_pixel_density, and aa.
            %   To up or downsample, you must change either
            % mainscan_x_pixel_density or aa. To have non-squared pixels,
            % you can adjust the x resolution (scanning direction) by
            % changing voxels_per_ramp manually. You must set y first (the
            % distance between the lines). See voxels_for_ramp for more
            % details.
            %   Offsets. If you are in any mode but miniscan,
            % ScanParams.start_norm_raw is used to apply an offset to the
            % scan. in miniscan mode, start_norm_raw and stop_norm_raw are
            % the individual normalised coordinates of each ramp.
            % -------------------------------------------------------------
            % Author(s):
            %   Geoffrey Evans, Boris Marin, Antoine Valera.
            %--------------------------------------------------------------
            % Revision Date:
            %   23-03-2018

            %% Get/Adjust start and stop points
            if isempty(obj.imaging_mode)
                % initialisation phase, pass
            elseif obj.imaging_mode == ImagingMode.Raster
                %% Generate ramps from -1 to +1 with mainscan_x_pixel_density
                [start, stop] = obj.generate_rows();
            elseif obj.imaging_mode == ImagingMode.Pointing
                %% Generate a single ramp from -1 to +1 with mainscan_x_pixel_density
                if not(obj.angles(1) == 0) || not(obj.angles(3) == 0) || not(obj.angles(2) == 0)
                    error('cannot use rotated coordinates in pointing mode')
                end
                [start, stop] = obj.generate_grid_diagonal();
            elseif obj.imaging_mode == ImagingMode.Functional || obj.imaging_mode == ImagingMode.Miniscan
                %% Uses points as set in start_norm_raw and stop_norm_raw
                if ~all(size(obj.start_norm_raw) == size((obj.stop_norm_raw))) %% qq check if resolution must match too
                    error('start_norm_raw and stop_norm_raw must have the same length, you must fix that before doing any other calculation')
                end
                start = obj.start_norm_raw;
                stop = obj.stop_norm_raw;
                if size(obj.pockels_raw, 2) ~= size(obj.start_norm_raw, 2)
                    obj.pockels_raw = []; % you have to set that again
                end
            else
                error('Scan mode not recognized')
            end

            %% Rotate the ramps, but keep the original resolution
            if any(obj.angles)
                [start, stop] = obj.rotate(start, stop);
            end
        end

        function boxes = generate_miniscan_boxes(obj, corner, v1, v2, v3)
            %% Generate box objects, typically used for miniscans
            % -------------------------------------------------------------
            % Syntax:
            %   boxes = ScanParams.generate_miniscan_boxes(corner, v1, v2, v3)
            % -------------------------------------------------------------
            % Inputs:
            %   corner (3xN FLOAT)
            %       the X-Y-X location, in XY cubic voxels of the corner of
            %       each point/line/patch/volume
            %   v1 (3xN FLOAT)
            %       a X-Y-X vector, in XY cubic voxels describing the
            %       scanning direction of each line, unless v1 is set to
            %       [0;0;0] (point scan)
            %   v2 (3xN FLOAT)
            %       a X-Y-X vector, in XY cubic voxels describing a
            %       plane with v1, unless v2 is set to [0;0;0] (line scan)
            %   v3 (3xN FLOAT)
            %       a X-Y-X vector, in XY cubic voxels describing a
            %       volume with the (v1,v2) plane, unless v3 is set to
            %       [0;0;0] (patch scannin)
            % -------------------------------------------------------------
            % Outputs:
            %   boxes ({corner,v1,v2,v3} STRUCT ARRAY)
            %       A array of struct describing the desired patches, as
            %       required by Controller.set_miniscans()
            % -------------------------------------------------------------
            % Extra Notes:
            %   These vectors describe patches in XY pixels. They are
            %   only valid for a specific acceptance angle and resolution.
            %   See demo_patch_generation() for some examples
            % -------------------------------------------------------------
            % Author(s):
            %   Antoine Valera.
            %--------------------------------------------------------------
            % Revision Date:
            %   06-10-2018

            if any([size(corner,1),size(v1,1),size(v2,1),size(v3,1)] ~= 3)
               error('Input must be a 3xN matrix')
            end
            if any([size(v1,2),size(v2,2),size(v3,2)] ~= size(corner,2))
               error('all inputs must have the same size')
            end

            %% Now generate boxes
            boxes = cell(1,size(corner,2));
            for el = 1:size(corner,2)
                boxes{el} = struct('corner', corner(:,el), 'v1', v1(:,el), 'v2', v2(:,el), 'v3', v3(:,el));
            end
        end
        
        function mainscan_x_pixel_density = get.mainscan_x_pixel_density(obj)
            %% Returns the number of pixels in the scanning direction for a full frame
            % -------------------------------------------------------------
            % Syntax:
            %   mainscan_x_pixel_density = ScanParams.mainscan_x_pixel_density
            % -------------------------------------------------------------
            % Inputs:
            % -------------------------------------------------------------
            % Outputs:
            %   mainscan_x_pixel_density (INT)
            %       The number of pixels for a frame between -1 and +1 norm
            % -------------------------------------------------------------
            % Extra Notes:
            %   Includes a backcompatibility fix for old headers
            % -------------------------------------------------------------
            % Author(s):
            %   Antoine Valera.
            %---------------------------------------------
            % Revision Date:
            %   26-07-2019
            
            mainscan_x_pixel_density = obj.mainscan_x_pixel_density;
            if isempty(mainscan_x_pixel_density) 
                % https://fr.mathworks.com/help/matlab/matlab_oop/example-maintaining-class-compatibility.html
                mainscan_x_pixel_density = obj.mainscan_voxel_density_1D;
            end
        end
        
        function set.mainscan_x_pixel_density(obj, mainscan_x_pixel_density)
            %% Returns the number of drives (number of ramps)
            % -------------------------------------------------------------
            % Syntax:
            %   ScanParams.mainscan_x_pixel_density = mainscan_x_pixel_density
            % -------------------------------------------------------------
            % Inputs:
            %   mainscan_x_pixel_density (INT)
            %       resolution of the full frame. Updating the value
            %   defines the default square pixel size and wuill update the
            %   total number of drives or return an error.
            % -------------------------------------------------------------
            % Outputs:
            % -------------------------------------------------------------
            % Extra Notes:
            %   You must set this variable first. Once the number of lines
            %   for the FOV is defined, you can change the number of pixels
            %   per line (raster mode) or the number of lines (miniscan
            %   mode).
            % -------------------------------------------------------------
            % Author(s):
            %   Antoine Valera.
            %--------------------------------------------------------------
            % Revision Date:
            %   23-09-2018
            
            if ~isempty(obj.imaging_mode) && ~isempty(obj.mainscan_x_pixel_density) % initialisation phase. alternatively
                if ~obj.fixed_res && numel(unique(obj.voxels_for_ramp)) ~= 1 
                    %The order is important when you load a controller --> obj.voxels_for_ramp is empty
                    error('You cannot change resolution while you have variable line resolution (unless all lines have the same resolution). Regenerate drives with the new resolution, then set individual resolutions again')
                elseif obj.imaging_mode == ImagingMode.Miniscan && (numel(unique(obj.start_norm' - obj.stop_norm', 'rows')) > 3 || ~all(unique(obj.start_norm' - obj.stop_norm', 'rows') == [-2, 0, 0]))
                    error('You cannot change mainscan resolution in miniscan mode. Behaviour is undefined')
                end
            end
            obj.mainscan_x_pixel_density = mainscan_x_pixel_density;
        end

        %% ================================================================
        %% Calculate Resolutions and timings  =============================

        function num_drives = get.num_drives(obj)
            %% Returns the number of drives (number of ramps)
            % -------------------------------------------------------------
            % Syntax:
            %   num_drives = ScanParams.num_drives
            % -------------------------------------------------------------
            % Inputs:
            % -------------------------------------------------------------
            % Outputs:
            %   num_drives (INT)
            %       The total number of drives
            % -------------------------------------------------------------
            % Extra Notes:
            %   If you are in miniscan mode, you must set start_norm_raw
            % and stop_norm_raw correctly first
            % -------------------------------------------------------------
            % Author(s):
            %   Geoffrey Evans, Boris Marin, Antoine Valera.
            %---------------------------------------------
            % Revision Date:
            %   21-09-2018

            if isempty(obj.start_norm)
                error('You need at least 1 line in your drives')
            end

            if obj.imaging_mode == ImagingMode.Pointing
                num_drives = size(obj.start_norm, 2)^2;
            else
                num_drives = size(obj.start_norm, 2);
            end
        end

        function num_voxels_per_ramp = get.voxels_for_ramp(obj)
            %% Returns the number of voxels for each ramp
            % -------------------------------------------------------------
            % Syntax:
            %   num_voxels_per_ramp = ScanParams.voxels_for_ramp
            % -------------------------------------------------------------
            % Inputs:
            % -------------------------------------------------------------
            % Outputs:
            %   num_voxels_per_ramp (1 x N INT)
            %       The number of voxels for each ramp. the number of ramps
            %       correspond to num_drives
            % -------------------------------------------------------------
            % Extra Notes:
            %   You must set start_norm_raw and stop_norm_raw correctly
            %   first. If ScanParams.fixed_res is false, AND you are in
            %   miniscan mode, the resolution will remain unchanged.
            %   Otherwise, the resolution depends on your normalised
            %   displacement and mainscan_x_pixel_density.
            %
            %   If obj.fixed_len is false, it is particularly important to
            %   precalculate accurately your distances, as they will be
            %   rounded.
            %
            %   If you have variable lengths (not res), you must set
            %   ScanParams.fixed_len to false
            % -------------------------------------------------------------
            % Author(s):
            %   Geoffrey Evans, Boris Marin, Antoine Valera.
            %--------------------------------------------------------------
            % Revision Date:
            %   23-09-2018

            if obj.imaging_mode == ImagingMode.Pointing
                num_voxels_per_ramp = ones(1, obj.mainscan_x_pixel_density);
            else
                if isempty(obj.voxels_for_ramp) %obj.voxels_for_ramp is empty in miniscan with non fixed length when you initially generate the ramps. It's transitory
                    num_voxels_per_ramp = round(obj.mainscan_x_pixel_density .* (obj.get_cubic_norm_distance ./ 2)); % because displacement is 2 x norm, and we want a fraction of mainscan_x_pixel_density
                    num_voxels_per_ramp(num_voxels_per_ramp == 0) = 1; % For points
                    if obj.fixed_len % Set that to false if some drives must have variable length
                        num_voxels_per_ramp(:) = max(num_voxels_per_ramp(:));
                    end
                else
                    num_voxels_per_ramp = obj.voxels_for_ramp;
                end
            end
        end

        function set.voxels_for_ramp(obj, voxels_for_ramp)
            %% Update the number of voxels of each ramp
            % -------------------------------------------------------------
            % Syntax:
            %   ScanParams.voxels_for_ramp = voxels_for_ramp
            % -------------------------------------------------------------
            % Inputs:
            % -------------------------------------------------------------
            % Outputs:
            %   voxels_for_ramp (INT OR (1 x N) INT)
            %       The number of voxels per ramp. by default, it
            %   corresponds to mainscan_x_pixel_density in raster mode or
            %   to mainscan_x_pixel_density/(displacement/2) in minican
            %   mode. if obj.fixed_res is true, all lines must be the same
            %   length.
            % -------------------------------------------------------------
            % Extra Notes:
            %   If you are in miniscan mode, you must set start_norm_raw
            % and stop_norm_raw correctly first
            % -------------------------------------------------------------
            % Author(s):
            %   Antoine Valera.
            %--------------------------------------------------------------
            % Revision Date:
            %   22-09-2018

            voxels_for_ramp = round(voxels_for_ramp);
            if numel(voxels_for_ramp) == 1
                obj.voxels_for_ramp = repmat(voxels_for_ramp, 1, obj.num_drives);
            elseif ~isempty(obj.mainscan_x_pixel_density) && ~all(size(voxels_for_ramp, 2) == size(obj.start_norm, 2)) % isempty(obj.mainscan_x_pixel_density) only on startup
                error(['You cannot change the number of ramps that way. Edit mainscan_x_pixel_density or pass an array of size ', num2str(numel(obj.voxels_for_ramp))]);
            elseif numel(unique(voxels_for_ramp)) > 1 && obj.fixed_res && ~isempty(obj.mainscan_x_pixel_density) %  only on startup or when reloading a header, in which case we don't want to do this control
                error('You are in fixed resolution mode. Lines resolution must all be the same');
            else
                obj.voxels_for_ramp = voxels_for_ramp;
            end
        end

        function num_voxels = get.num_voxels(obj)
            %% Returns the total number of voxels, for all ramps
            % -------------------------------------------------------------
            % Syntax:
            %   num_voxels = ScanParams.num_voxels
            % -------------------------------------------------------------
            % Inputs:
            % -------------------------------------------------------------
            % Outputs:
            %   num_drives (INT)
            %       The total number of voxels, in all linescans
            % -------------------------------------------------------------
            % Extra Notes:
            %   If you are in miniscan mode, you must set start_norm_raw
            % and stop_norm_raw correctly first
            % -------------------------------------------------------------
            % Author(s):
            %   Geoffrey Evans, Boris Marin, Antoine Valera.
            %--------------------------------------------------------------
            % Revision Date:
            %   21-09-2018

            if obj.imaging_mode == ImagingMode.Functional || obj.imaging_mode == ImagingMode.Pointing
                num_voxels = obj.num_drives;  % one drive per point
            elseif obj.imaging_mode == ImagingMode.Raster
                num_voxels = obj.num_drives .* obj.mainscan_x_pixel_density; % number_of_drives * voxel_per_drive. all drives have the same length
            else % Miniscans and future implementation for variable length.
                num_voxels = sum(obj.voxels_for_ramp); % sum of all voxels
            end
        end

        function set.start_norm_raw(obj, start_norm_raw)
            %% Set the scan offset/location
            % -------------------------------------------------------------
            % Syntax:
            %   ScanParams.start_norm_raw = start_norm_raw
            % -------------------------------------------------------------
            % Inputs:
            %   start_norm_raw ((3 x 1) OR (3 x num drives) INT)
            %       In any mode but miniscan, input must be (3 x 1). It
            %   defines the normalised X, Y and Z offset of the whole scan.
            %       In miniscan mode, the values correspond to the starting
            %   point of each ramp, and must match ScanParams.num_drives.
            % -------------------------------------------------------------
            % Outputs:
            % -------------------------------------------------------------
            % Extra Notes:
            % Fixed length constraint is only checked once stop_norm_raw,
            % so you should set start_norm_raw first and stop_norm_raw
            % second
            % -------------------------------------------------------------
            % Author(s):
            %   Geoffrey Evans, Boris Marin, Antoine Valera.
            %--------------------------------------------------------------
            % Revision Date:
            %   23-09-2018

            if ~isempty(obj.imaging_mode) && obj.imaging_mode ~= ImagingMode.Miniscan &&  ~all(size(start_norm_raw) == [3, 1])
                error(['In Raster & Pointing imaging modes, start_norm_raw only controls offsets and must be of size (3 x 1)'])
            end
            obj.start_norm_raw = start_norm_raw;
        end

        function set.stop_norm_raw(obj, stop_norm_raw)
            %% Set the scan offset/location
            % -------------------------------------------------------------
            % Syntax:
            %   ScanParams.stop_norm_raw = stop_norm_raw
            % -------------------------------------------------------------
            % Inputs:
            %   stop_norm_raw ((3 x num drives) INT)
            %       In any mode but miniscan, input will have no effect. To
            %   control offsets, use start_norm_raw
            %       In miniscan mode, the values correspond to the stopping
            %   point of each ramp, and must match ScanParams.num_drives.
            % -------------------------------------------------------------
            % Outputs:
            % -------------------------------------------------------------
            % Extra Notes:
            % As you set this value in Miniscan mode, we also recalculate
            % voxels_for_ramp once this is done. We check that the fixed
            % length criterions are respected if obj.fixed_res == true.
            % -------------------------------------------------------------
            % Author(s):
            %   Geoffrey Evans, Boris Marin, Antoine Valera.
            %--------------------------------------------------------------
            % Revision Date:
            %   23-09-2018

            if ~isempty(obj.imaging_mode) && obj.imaging_mode ~= ImagingMode.Miniscan &&  ~all(size(stop_norm_raw) == [3, 1])
                error(['In ',obj.imaging_mode,' imaging mode, start_norm_raw must be of size (3 x 1)'])
            end
            if ~isempty(obj.stop_norm_raw) %% Don't run that check on startup or when reloading an old scanparams
                obj.check_fixed_length_contraint(obj.start_norm_raw, stop_norm_raw);
            end
            obj.stop_norm_raw = stop_norm_raw;
        end

        function centre = get.centre_norm(obj)
            %% Calculate the normalized center of each ramp
            % -------------------------------------------------------------
            % Syntax:
            %   centre = ScanParams.centre_norm
            % -------------------------------------------------------------
            % Inputs:
            % -------------------------------------------------------------
            % Outputs:
            %   centre (3 x num_drives DOUBLE)
            %       X Y and Z normalised centre between the starting
            %       and stopping point of each ramp, per axis
            % -------------------------------------------------------------
            % Extra Notes:
            %   Usually called internally when you need to calculate the
            % number of voxels per ramp. If you are in miniscan mode,
            % you must get start_norm_raw and stop_norm_raw correctly
            % -------------------------------------------------------------
            % Author(s):
            %   Geoffrey Evans, Boris Marin, Antoine Valera.
            %--------------------------------------------------------------
            % Revision Date:
            %   21-09-2018

            centre = (obj.stop_norm + obj.start_norm) / 2;
        end

        function disp = get.displacement_norm(obj)
            %% Calculate the normalized ramps displacement (~length)
            % -------------------------------------------------------------
            % Syntax:
            %   disp = ScanParams.displacement_norm
            % -------------------------------------------------------------
            % Inputs:
            % -------------------------------------------------------------
            % Outputs:
            %   disp (3 x num_drives DOUBLE)
            %       X Y and Z normalised distance between the starting
            %       and stopping point of each ramp, per axis
            % -------------------------------------------------------------
            % Extra Notes:
            %   Usually called internally when you need to calculate the
            % number of voxels per ramp. If you are in miniscan mode,
            % you must get start_norm_raw and stop_norm_raw correctly
            % -------------------------------------------------------------
            % Author(s):
            %   Geoffrey Evans, Boris Marin, Antoine Valera.
            %--------------------------------------------------------------
            % Revision Date:
            %   21-09-2018

            disp = obj.stop_norm - obj.start_norm;
        end

        function start = get.start_norm(obj)
            %% Calculate the normalized ramps starting point
            % -------------------------------------------------------------
            % Syntax:
            %   start = ScanParams.start_norm
            % -------------------------------------------------------------
            % Inputs:
            % -------------------------------------------------------------
            % Outputs:
            %   start (3 x num_drives DOUBLE)
            %       X Y and Z normalised start position of each ramp.
            % -------------------------------------------------------------
            % Extra Notes:
            %   If you are in miniscan mode, you must set start_norm_raw
            % and stop_norm_raw correctly first
            % -------------------------------------------------------------
            % Author(s):
            %   Geoffrey Evans, Boris Marin, Antoine Valera.
            %--------------------------------------------------------------
            % Revision Date:
            %   21-09-2018

            [start, ~] = obj.handle_image_start_stops();
        end

        function stop = get.stop_norm(obj)
            %% Calculate the normalized ramps stopping point
            % -------------------------------------------------------------
            % Syntax:
            %   stop = ScanParams.stop_norm
            % -------------------------------------------------------------
            % Inputs:
            % -------------------------------------------------------------
            % Outputs:
            %   stop (3 x num_drives DOUBLE)
            %       X Y and Z normalised stop position of each ramp.
            % -------------------------------------------------------------
            % Extra Notes:
            %   If you are in miniscan mode, you must set start_norm_raw
            % and stop_norm_raw correctly first
            % -------------------------------------------------------------
            % Author(s):
            %   Geoffrey Evans, Boris Marin, Antoine Valera.
            %--------------------------------------------------------------
            % Revision Date:
            %   21-09-2018

            [~, stop] = obj.handle_image_start_stops();
        end
        
        function pixel_size_norm = get.pixel_size_norm(obj)
            %% Get the pixel size in the scanning direction, per linescan
            % -------------------------------------------------------------
            % Syntax: 
            %   pixel_size_norm = ScanParams.pixel_size_norm
            % -------------------------------------------------------------
            % Inputs:
            % -------------------------------------------------------------
            % Outputs: 
            %   pixel_size_norm (3 x num_drives DOUBLE)
            %       X Y and Z normalised stop position of each ramp.
            % -------------------------------------------------------------
            % Extra Notes:
            %   If fixed_res is true all values are identical. Otherwise
            %   they can vary if there were set to different values
            % -------------------------------------------------------------
            % Author(s):
            %   Antoine Valera.
            %--------------------------------------------------------------
            % Revision Date:
            %   29-09-2018

            pixel_size_norm = obj.get_cubic_norm_distance ./ obj.voxels_for_ramp;
        end
        
        function cubic_norm_distance = get_cubic_norm_distance(obj, start_norm, stop_norm)
            %% Get cubic voxel norm distance. Use this to scale to um 
            % or check if fixed_len requirements are met.
            % -------------------------------------------------------------
            % Syntax: 
            %   cubic_norm_distance = ScanParams.get_cubic_norm_distance
            %   cubic_norm_distance = 
            %       ScanParams.get_cubic_norm_distance(start_norm, stop_norm)
            % -------------------------------------------------------------
            % Inputs: 
            %   start_norm(3 x N FLOAT) - Optional - Default are values
            %                           from obj.start_norm
            %       If you want to estimate cubic_norm_distance for a given
            %       set of drives without setting them in ScanParams, pass
            %       a manual start_norm.
            %
            %   stop_norm(3 x N FLOAT) - Optional - Default are values
            %                           from obj.stop_norm
            %       If you want to estimate cubic_norm_distance for a given
            %       set of drives without setting them in ScanParams, pass
            %       a manual stop_norm. 
            % -------------------------------------------------------------
            % Outputs:
            %   cubic_norm_distance (3 x num_drives DOUBLE)
            %       X Y and scaled Z normalised distance.
            % -------------------------------------------------------------
            % Extra Notes:
            %   Z norm units are scaled to match XY Norm. Use
            %   AolParams.x_norm_to_um_scaling to convert to um.
            % -------------------------------------------------------------
            % Author(s):
            %   Antoine Valera.
            %--------------------------------------------------------------
            % Revision Date:
            %   29-09-2018

            if nargin == 1
                start_norm = obj.start_norm;
                stop_norm  = obj.stop_norm ;
            end
            if size(start_norm,2) ~= size(stop_norm,2)
                cubic_norm_distance = NaN;
                return
            end
            if obj.imaging_mode == ImagingMode.Pointing
                cubic_norm = repmat([-2;0],1,size(start_norm,2)); %% QQ full frame only
            else
                cubic_norm = start_norm(1:2,:) - stop_norm(1:2,:);
            end
            cubic_norm(3,:) = (start_norm(3,:) - stop_norm(3,:)) ./ obj.aol_params_handle.xy_z_norm_ratio;
            cubic_norm_distance = vecnorm(cubic_norm);
        end
        
        function cubic_norm_distance = get.cubic_norm_distance(obj)
            cubic_norm_distance = obj.get_cubic_norm_distance();
        end

        function set.fixed_len(obj, fixed_len)
            %% When changing fixed_len toggle, check if condition is met
            % -------------------------------------------------------------
            % Syntax: 
            %   ScanParams.fixed_len = BOOL
            % -------------------------------------------------------------
            % Inputs: 
            %   fixed_len(BOOL)
            %       If true, all drives must have the same length (in um,
            %       not normalised units) the conversion to um uses the
            %       AolParams.xy_z_norm_ratio, itself based on the
            %       calibrated x_norm_to_um_scaling and
            %       z_norm_to_um_scaling values
            % -------------------------------------------------------------
            % Outputs: 
            % -------------------------------------------------------------
            % Extra Notes:
            % -------------------------------------------------------------
            % Author(s):
            %   Antoine Valera.
            %--------------------------------------------------------------
            % Revision Date:
            %   18-02-2019
           
            obj.fixed_len = fixed_len;
            obj.check_fixed_length_contraint(obj.start_norm_raw, obj.stop_norm_raw);
        end
        
        function set.fixed_res(obj, fixed_res)
            %% When changing fixed_res toggle, check if condition is met
            % -------------------------------------------------------------
            % Syntax: 
            %   ScanParams.fixed_res = BOOL
            % -------------------------------------------------------------
            % Inputs: 
            %   fixed_res(BOOL)
            %       If true, all drives must have the same resolution. If
            %       false resolution can vary. If you set it to true while
            %       reolutions are variable. each line res is set back to
            %       default
            % -------------------------------------------------------------
            % Outputs: 
            % -------------------------------------------------------------
            % Extra Notes:
            % -------------------------------------------------------------
            % Author(s):
            %   Antoine Valera.
            %--------------------------------------------------------------
            % Revision Date:
            %   26-10-2019
           
            obj.fixed_res = fixed_res;
            if isempty(obj.imaging_mode)
                % initialisation phase, pass
            elseif fixed_res && numel(unique(obj.voxels_for_ramp)) > 1
                fprintf('resolutions were set back to default')
                lengths = obj.get_cubic_norm_distance(obj.start_norm_raw(:,1), obj.stop_norm_raw(:,1));
                obj.voxels_for_ramp = round(lengths * obj.mainscan_x_pixel_density / 2);
            end
        end
        
        function lengths = check_fixed_length_contraint(obj, start_norm_raw, stop_norm_raw)
            %% If fixed_len is true, check if condition ramps are of same length
            % -------------------------------------------------------------
            % Syntax: 
            %   ScanParams.check_fixed_length_contraint(start_norm_raw, stop_norm_raw)
            % -------------------------------------------------------------
            % Inputs: 
            %   start_norm(3 x N FLOAT)
            %       start_norm value used to estimate cubic_norm_distance
            %
            %   stop_norm(3 x N FLOAT)
            %       stop_norm value used to estimate cubic_norm_distance
            % -------------------------------------------------------------
            % Outputs: 
            %   lengths(3 x N FLOAT)
            %       lengths of segments in um
            % -------------------------------------------------------------
            % Extra Notes:
            % -------------------------------------------------------------
            % Author(s):
            %   Antoine Valera.
            %--------------------------------------------------------------
            % Revision Date:
            %   18-02-2019

            if ~isempty(start_norm_raw) && ~isempty(obj.aol_params_handle) % obj.aol_params_handle is empty when you reload a header, but hen you don't need this check
                lengths = obj.get_cubic_norm_distance(start_norm_raw, stop_norm_raw);
                lengths = round(lengths / obj.fixed_len_tol); % tolerate 2% variability by default
                if numel(unique(lengths)) > 1 && obj.fixed_len && size(start_norm_raw, 2) > 1
                    error('obj.fixed_len is true, but current start_norm_raw and stop_norm_raw value results in variable length. If calculation is right, tolerance may have to be increased');
                end
            end
        end

        %% ================================================================
        %% Pockels related function =======================================

        function set.pockels_raw(obj, pockel_values)
            %% Set the pockel values for each ramp (in V)
            % -------------------------------------------------------------
            % Syntax:
            %   ScanParams.pockels_raw = pockel_values
            % -------------------------------------------------------------
            % Inputs:
            %   num_drives (INT, or (1 x N) INT or (4 x N) INT)
            %   - If you set only one value, all drives will get the same
            %   value
            %   - A 1 x N value gives a specific pockel cell value to each
            %   ramp
            %   - A 4 x N value gives a specific pockel cell value to each
            %   ramp, for each AOD
            % -------------------------------------------------------------
            % Outputs:
            % -------------------------------------------------------------
            % Extra Notes:
            %   Pockels values are between 0 and 2 V (hardcoded value).
            %   If you are in miniscan mode, you must set start_norm_raw
            % and stop_norm_raw correctly first, since you want to match
            % pocel values to each ramp.
            % -------------------------------------------------------------
            % Author(s):
            %   Geoffrey Evans, Boris Marin, Antoine Valera.
            %--------------------------------------------------------------
            % Revision Date:
            %   21-09-2018

            if any(pockel_values(:) > 2) || any(pockel_values(:) < 0)
                error('Pockel values must be between 0 and 2')
            end

            if isempty(pockel_values) % after changing resolution,
                obj.pockels_raw = []; % you'll have to reset the values.
            elseif numel(pockel_values) == 1 % one value for all drives
                obj.pockels_raw = repmat(pockel_values, 4, obj.num_drives);
            elseif all(size(pockel_values) == [1,obj.num_drives]) % one value per drives
                obj.pockels_raw = repmat(pockel_values, 4, 1);
            elseif all(size(pockel_values) == [4,obj.num_drives]) % one value per drive, per cristal
                obj.pockels_raw = pockel_values;
            elseif obj.imaging_mode == ImagingMode.Pointing
                obj.pockels_raw = repmat(pockel_values, 4, 1);
            else
                error('Pockel values must be either a unique value or an array of size (1 x num_drives) or (4 x num_drives)')
            end
        end

        function set.aod_delay_cycles(obj, aod_delay_cycles)
            %% Set the AOD delay cycle value. Important for sync.
            % -------------------------------------------------------------
            % Syntax:
            %   ScanParams.pockels_raw = pockel_values
            % -------------------------------------------------------------
            % Inputs:
            %   aod_delay_cycles (INT)
            %       time difference, adjusted, between aod fill time and
            %       the measured optimal sample wait after trigger
            % -------------------------------------------------------------
            % Outputs:
            % -------------------------------------------------------------
            % Extra Notes:
            % typically (see drives_for_synth_fpga.m)
            % aod_delay_cycles = 
            %   (aol_params.sampleswaitaftertrigger - aol_params.aod_fill)
            %  * (aol_params.synth_clock_freq / aol_params.daq_clock_freq)
            %  - 262
            % -------------------------------------------------------------
            % Author(s):
            %   Vicky Griffiths, Antoine Valera.
            %--------------------------------------------------------------
            % Revision Date:
            %   23-09-2018

            if aod_delay_cycles < obj.low_aod_delay_cycles_limit
                aod_delay_cycles = obj.low_aod_delay_cycles_limit; %because aod_delay_cycles cannot be < 0
            end
            obj.aod_delay_cycles = repmat((aod_delay_cycles - obj.low_aod_delay_cycles_limit), 4, obj.num_drives);
        end

        function aod_delay_cycles = get.aod_delay_cycles(obj)
            %% Get the current aod_delay_cycles
            % -------------------------------------------------------------
            % Syntax:
            %   aod_delay_cycles = ScanParams.aod_delay_cycles
            % -------------------------------------------------------------
            % Inputs:
            %   aod_delay_cycles ((1 x num_drives) INT)
            %       delay added to each cycles
            % -------------------------------------------------------------
            % Outputs:
            % -------------------------------------------------------------
            % Extra Notes:
            % -------------------------------------------------------------
            % Author(s):
            %   Vicky Griffiths, Antoine Valera.
            %--------------------------------------------------------------
            % Revision Date:
            %   23-09-2018

            aod_delay_cycles = repmat(obj.aod_delay_cycles(1), 4, obj.num_drives);
        end

        %% ================================================================
        %% Geometric Transformations ======================================

        function [start, stop] = rotate(obj, start, stop)
            %% Rotate a scan in 3D using ScanParams.angles
            % Convert coordinates to cubic voxels, rotate, convert them back
            % -------------------------------------------------------------
            % Syntax:
            %   [start, stop] = ScanParams.rotate(start, stop)
            % -------------------------------------------------------------
            % Inputs:
            %   start (3 x num_drives DOUBLE)
            %       X Y and Z normalised start position of each ramp.
            %   stop (3 x num_drives DOUBLE)
            %       X Y and Z normalised stop position of each ramp.
            % -------------------------------------------------------------
            % Outputs:
            %   start (3 x num_drives DOUBLE)
            %       new rotated X Y and Z normalised start position of each
            %       ramp.
            %   stop (3 x num_drives DOUBLE)
            %       new rotated X Y and Z normalised stop position of each
            %       ramp.
            % -------------------------------------------------------------
            % Extra Notes:
            %   Several methods are availabe for the rotation :
            %   - if ScanParams.angles is of size 3, rotation will use
            %   quaternions if ScanParams.quaternions is true, or a
            %   rotation matrix if false. Input values are read as X-Y and
            %   Z rotation angles in degrees
            %   - if ScanParams.angles is of size 4, rotation will use
            %   quaternions. Input values must be quaternions.
            %   - if ScanParams.angles is of size 9, rotation will use a
            %   rotation matrix. Input values must be a rotation matrix.
            % -------------------------------------------------------------
            % Author(s):
            %   Antoine Valera.
            %--------------------------------------------------------------
            % Revision Date:
            %   23-09-2018

            %% Scale z so x,y, and z norm are in cubic voxels
            start(3,:) = start(3,:) / obj.aol_params_handle.xy_z_norm_ratio; % Rescale Z
            stop(3,:) = stop(3,:) / obj.aol_params_handle.xy_z_norm_ratio;

            %% Read/Generate rotation matrix/quaternions
            if numel(obj.angles) == 3 % Angles : we need to calculate the rotation
                if obj.quaternions % Rotation with quaternions
                    quat = euler2quat(deg2rad(obj.angles(1)),deg2rad(obj.angles(2)),deg2rad(obj.angles(3)),'xyz');
                else % Rotation matrix alternative;
                    % needs Phased Array System Toolbox or
                    % https://github.com/jimmyDunne/kinematicToolbox/tree/master/spatialMath
                    mat = rotx(obj.angles(1))*roty(obj.angles(2))*rotz(obj.angles(3));
                end
            elseif numel(obj.angles) == 4
                quat = obj.angles;
                obj.quaternions = true;
            elseif numel(obj.angles) == 9
                mat = obj.angles;
                obj.quaternions = false;
            else
                error('Angle input must be 3 angles in degrees, or 4 quaternions or a rotation matrix')
            end

            %% Apply rotation
            if obj.quaternions % Rotation with quaternions
                start = qrot3d(start', quat)';
                stop = qrot3d(stop', quat)';
            else % Rotation matrix alternative
            	start = mat * start;
                stop = mat * stop;
            end

            %% Rescale z
            start(3,:) = start(3,:) * obj.aol_params_handle.xy_z_norm_ratio;
            stop(3,:) = stop(3,:) * obj.aol_params_handle.xy_z_norm_ratio;
        end

        %% ================================================================
        %% Scan time related functions ====================================


        function scan_time = get.scan_time(obj)
            %% Get the time necessary to scan each drive
            % This is the scanning time
            % -------------------------------------------------------------
            % Syntax:
            %   scan_time = ScanParams.scan_time()
            % -------------------------------------------------------------
            % Inputs:
            % -------------------------------------------------------------
            % Outputs:
            %   scan_time (1 x num_drives DOUBLE)
            %       scan time in s for each line (excluded fill time)
            % -------------------------------------------------------------
            % Extra Notes:
            % -------------------------------------------------------------
            % Author(s):
            %   Geoffrey Evans, Boris Marin, Antoine Valera.
            %--------------------------------------------------------------
            % Revision Date:
            %   30-09-2018

            scan_time = obj.aol_params_handle.discretize(obj.voxel_time) .* obj.voxels_for_ramp;
            if any(scan_time > 248e-6)
                error('scan time is too long for at least a one line. Max scan duration is 248us ')
            end
        end

        function full_time = get.full_time(obj)
            %% Get the time necessary for a full line scan
            % This includes AOL fill time + scanning time
            % -------------------------------------------------------------
            % Syntax:
            %   full_time = ScanParams.full_time()
            % -------------------------------------------------------------
            % Inputs:
            % -------------------------------------------------------------
            % Outputs:
            %   full_time (1 x num_drives DOUBLE)
            %       fill time + scan time in s for each line
            % -------------------------------------------------------------
            % Extra Notes:
            % -------------------------------------------------------------
            % Author(s):
            %   Geoffrey Evans, Boris Marin, Antoine Valera.
            %--------------------------------------------------------------
            % Revision Date:
            %   30-09-2018

            full_time = obj.aol_params_handle.fill_time + obj.scan_time;
            full_time = repmat(full_time, obj.aol_params_handle.num_aods, 1);
        end
        
        function fps = get.fps(obj)
            %% Get basic frame per second for current scan_params.
            % For more complex estimates, see ScanParams.get_fps().
            % -------------------------------------------------------------
            % Syntax:
            %   fps = ScanParams.fps
            % -------------------------------------------------------------
            % Inputs:
            % -------------------------------------------------------------
            % Outputs:
            %   fps (DOUBLE)
            %       Estimated scan frequency, ignoring any MC or frame
            %       averaging
            % -------------------------------------------------------------
            % Extra Notes:
            % -------------------------------------------------------------
            % Author(s):
            %   Antoine Valera.
            %--------------------------------------------------------------
            % Revision Date:
            %   24-02-2019
            %
            % See also: estimate_scan_frequency, get_frame_duration,
            % ScanParams.get_fps()

            fps = obj.get_fps();
        end

        function [fps, line_duration, overhead] = get_fps(obj, n_cycles, MC_scan_params, MC_rate)
            %% Get the expected frame per second (incl averages and MC)
            % -------------------------------------------------------------
            % Syntax:
            %   [fps, line_duration, overhead] =
            %         ScanParams.get_fps(averages, MC_scan_params, MC_rate)
            % -------------------------------------------------------------
            % Inputs:
            %   averages (INT)
            %       The number of frames to averages (1 for none)
            %   MC_scan_params (ScanParams object) - Optional
            %       If any, we calculate the MC overhead. fps are adjusted
            %    accordingly, and overhead is provided as percentage.
            %   MC_rate (DOUBLE) - Optional - default is 2
            %       in ms, the rate between 2 MC cycles. Typically from 
            %   controller.daq_fpga.MC_rate. Set to 0 to ignore
            %   mc_corrections
            % -------------------------------------------------------------
            % Outputs:
            %   fps (FLOAT)
            %       The number of frame per second CORRECTED FOR MC
            %       If average is > 1, it is the number of averaged frame 
            %       per s.
            %   cycle_duration (FLOAT)
            %       The time in seconds for a cycle, IGNORING MC
            %   line_duration (FLOAT or 1 x num drives FLOAT)
            %       The full time needed to scan each line (ignoring MC
            %       overhead)
            %   overhead (FLOAT)
            %       If MC_scan_params is provided, this is an estimate of
            %       the overhead of movement correction on the total scan
            %       time expressed as a percentage. The final exact 
            %       overhead can vary by a tiny amount
            % -------------------------------------------------------------
            % Extra Notes:
            %   With MC on, the exact overhead and cycle duration can be
            %   marginally different, depending on the exact number of
            %   MC cycles happening (a +/- 1 cycle jitter is possible). To
            %   estimate uncertainty or MC scan duration, type
            %   [~,cycle_duration,~,~] = ,...
            %           Controller.mc_scan_params.get_fps(1)
            % -------------------------------------------------------------
            % Author(s):
            %   Antoine Valera.
            %--------------------------------------------------------------
            % Revision Date:
            %   24-02-2019
            %
            % See also: estimate_scan_frequency, get_frame_duration,
            % ScanParams.fps
            if nargin < 2 || isempty(n_cycles)
                n_cycles = 1;
            end
            if nargin < 4 || isempty(MC_rate)
                MC_rate = 2; % from controller.daq_fpga.MC_rate
            end
            if nargin < 3 || isempty(MC_scan_params) || ~MC_rate
                MC_scan_params = [];
            end

            % Main scan variables
            line_duration        = obj.full_time;
            n_lines              = size(line_duration, 2);
            cycle_duration_noMC  = sum(line_duration, 2);
            line_duration        = line_duration(1,:);
            cycle_duration_noMC  = cycle_duration_noMC(1,:);
            if obj.imaging_mode == ImagingMode.Pointing
                cycle_duration_noMC = sum(line_duration * obj.mainscan_x_pixel_density);
            end

            if ~isempty(MC_scan_params)
                MC_duration     = 1/MC_scan_params.fps;
                MC_rate         = MC_rate/1000; % controller.daq_fpga.MC_rate
            else
                MC_duration = 0;
                MC_rate = 0;
            end

            %% Now calculate t of each linescan
            t_line                      = NaN(1,n_lines*n_cycles);   % absolute t start for each line scan
            abs_t_current_line          = 0;                    % current timepoint (within the loop)
            elapsed_since_reset         = 0;                    % internal timing since last MC cycle (only valid if refcountresetenabled is true)
            abs_t_reset                 = 0;                    % absolute time of last MC reset
            interrupts_count            = 0;                    % count total number of MC (for overhead calculaion)
            delta_SWAT = (obj.aol_params_handle.sampleswaitaftertrigger - obj.aol_params_handle.aod_fill)*5e-9;
            n_lines_for_reset = 3;

            for line_n = 0:((n_lines*n_cycles)-1)
                %% Get duration for the current line (in case you have variable length)
                in_cycle_line_nb        = mod(line_n, n_lines)+1;  % internal counter for variable length/duration
                current_line_duration   = line_duration(in_cycle_line_nb);

                %% Each imaging cycle starts with a MC cycle. We squeeze one here before the first line
                if in_cycle_line_nb == 1
                    [abs_t_current_line, interrupts_count, abs_t_reset, elapsed_since_reset] = insert_ref_scan_delay(delta_SWAT, abs_t_current_line, interrupts_count, MC_duration, 0);  

                    %% For each start of cycle except the first one, t is reset when the first pixel is acquired
                    extra_remaining_lines = n_lines_for_reset;
                    current_intercycle_delta = 0;
                end

                %% Set current line time in the output (which is time of first pixel, so we add AOD fill)
                t_line(line_n+1) = abs_t_current_line + obj.aol_params_handle.aod_fill * 5e-9;

                %% Now if we are less than 2 linescan from the end we block any reset. it can wait
                if in_cycle_line_nb > (n_lines-n_lines_for_reset-1) 
                    no_reset = true;
                else
                    no_reset = false;
                end

                %% Now, if NEXT LINE pass the 2ms bar, we finish the current line, and the next one and one more.
                previous_intercycle_delta = current_intercycle_delta;
                current_intercycle_delta = mod((abs_t_current_line - abs_t_reset) + current_line_duration, MC_rate);
                abs_t_current_line = abs_t_current_line + current_line_duration;

                if extra_remaining_lines < n_lines_for_reset
                    extra_remaining_lines = extra_remaining_lines - 1;
                end

                if current_intercycle_delta < previous_intercycle_delta && extra_remaining_lines == n_lines_for_reset
                    extra_remaining_lines = n_lines_for_reset - 1;
                end

                if extra_remaining_lines == 0 %&& in_cycle_line_nb < n_lines
                    [abs_t_current_line, interrupts_count, abs_t_reset, elapsed_since_reset] = insert_ref_scan_delay(delta_SWAT, abs_t_current_line, interrupts_count, MC_duration, current_line_duration);            
                    current_intercycle_delta = 0;
                    extra_remaining_lines = n_lines_for_reset;
                end

            end

            %% End time of last line
            total_duration = t_line(end) + line_duration(end) - obj.aol_params_handle.aod_fill * 5e-9; % (We remove a final aod_fill as t_line is 1st pixel time)

            %% Calculate corrected average cycle duration and overhead
            cycle_duration = total_duration / n_cycles;
            if MC_rate > 0
                overhead = 1 - (cycle_duration_noMC / cycle_duration); 
            else
                overhead = 0;
            end
            
            %% Get real mean fps
            fps = 1/cycle_duration;

            function [abs_t_current_line, interrupts_count, abs_t_reset, elapsed_since_reset] = insert_ref_scan_delay(delta_SWAT, abs_t_current_line, interrupts_count, MC_duration, delay)
                %% In this case, next line will be after MC interrupt
                abs_t_MC_Start             = abs_t_current_line + delay; % MC starts after current line completion, unless it's a new cycle

                %% If refcountresetenabled is true, we ignore the overshoot. First pixel acquired is our new 0


                %% Now we define the time for the new MC cycle reset
                if interrupts_count == 0
                    %% The very first cycle t start begins with the MC cycle onset
                    elapsed_since_reset = MC_duration + delta_SWAT*5e-9;   % For first cycle, we start at t = 0, so the first line happens after MC duration time + SWAT - aod fill
                    abs_t_reset         = 0 ;%- delta_SWAT;%*5e-9;%; 
                    MC_duration         = 0 ;%- delta_SWAT;%*5e-9;%%MC_duration + delta_SWAT*5e-9;  
                else
                    %% All the other cycles start when the first pixel is acquired, which is MC duration + 1 fill time
                    elapsed_since_reset = 0;
                    abs_t_reset         = abs_t_MC_Start;% %+ MC_duration; 
                end

                %% Set first imaging ramp t start after ref scan
                abs_t_current_line = abs_t_MC_Start + MC_duration;  % next line starts after current line completion + MC duration

                %% Increment interrupt count for overhead calulation
                interrupts_count = interrupts_count + 1;
            end
        end

        %% ================================================================
        %% Generate a'obj, b'obj, c'obj and d'obj =========================

        function amp_raw = get.amp_raw(obj)
            amp_raw = obj.amp_raw;
            if ~numel(unique(amp_raw)) ==1 && size(amp_raw, 2) ~= size(obj.start_norm, 2)
                error('amplitude values does not match the number of drives and cannot be interpolated. Please set amp_raw values manually');
            elseif numel(unique(amp_raw)) == 1
                amp_raw = ones(4,size(obj.start_norm,2)) * unique(amp_raw);
            end
        end

        function set.amp_raw(obj, amp_raw)
            obj.amp_raw = amp_raw;
        end

        function [amp0, amp1, amp2] = amp(obj, a, b, c)
            if isa(obj.amp_raw,'function_handle') %% for amplitude modulation
                [amp0, amp1, amp2] = obj.amp_raw(a, b, c);
            else%if obj.imaging_mode == ImagingMode.Pointing || obj.imaging_mode == ImagingMode.Raster
                amp0 = obj.amp_raw;%repmat(obj.amp_raw(:), 1, obj.num_drives);
                amp1 = amp0*0;
                amp2 = amp0*0;
%             else
%                 amp0 = obj.amp_raw;
%                 amp1 = amp0*0;
%                 amp2 = amp0*0;
            end
        end

        function c_val = c(obj)
            half_aperture_time = obj.aol_params_handle.aod_aperture / obj.aol_params_handle.aod_ac_vel / 2;
            c_val = repmat(3 * obj.c_waves(:) / half_aperture_time^3, 1, obj.num_drives);
        end

        function d_val = d(obj)
            half_aperture_time = obj.aol_params_handle.aod_aperture / obj.aol_params_handle.aod_ac_vel / 2;
            d_val = repmat(4 * obj.d_waves(:) / half_aperture_time^4, 1, obj.num_drives);
        end

        function plot_drives(obj, mode, fig_nb)
            %% Display current drives in normalised units
            % -------------------------------------------------------------
            % Syntax:
            %   ScanParams.plot_drives()
            % -------------------------------------------------------------
            % Inputs:
            %   mode (STR) - Optional - Default is 'simple' ; any in
            %                           {'simple', 'quiver', 'full'}
            %   Plot all ramps ('simple'), scan direction ('quiver') or
            %   all voxels ('full')
            % -------------------------------------------------------------
            % Outputs:
            % -------------------------------------------------------------
            % Extra Notes:
            % -------------------------------------------------------------
            % Author(s):
            %   Antoine Valera.
            %--------------------------------------------------------------
            % Revision Date:
            %   22-09-2018

            if nargin < 2 || isempty(mode)
                mode = 'simple';
            end
            if nargin == 3 && isnumeric(fig_nb)
                figure(fig_nb);hold on;cla();
            else
                figure();hold on
            end

            patch([-1,1,1,-1],[1,1,-1,-1],'r');hold on;
            alpha(0.05); hold on;
            if strcmp(mode, 'simple')
                plot3(  [obj.start_norm(1,:);obj.stop_norm(1,:)],...
                        [obj.start_norm(2,:);obj.stop_norm(2,:)],...
                        [obj.start_norm(3,:);obj.stop_norm(3,:)]);hold on
            elseif strcmp(mode, 'quiver')
                quiver3(    obj.start_norm(1,:), obj.start_norm(2,:), obj.start_norm(3,:) , ...
                            obj.displacement_norm(1,:), obj.displacement_norm(2,:),obj.displacement_norm(3,:), 0);hold on
            else
                X = [];Y = [];Z = [];
                for line = 1:obj.num_drives  
                    if obj.voxels_for_ramp(line) == 1
                        X = [X ; mean([obj.start_norm(1,line),obj.stop_norm(1,line)])]; % rendering trick for single voxels so they appear midline
                    else
                        X = [X ; linspace(obj.start_norm(1,line)',obj.stop_norm(1,line)',obj.voxels_for_ramp(line))'];
                    end
                    Y = [Y ; linspace(obj.start_norm(2,line)',obj.stop_norm(2,line)',obj.voxels_for_ramp(line))'];
                    Z = [Z ; linspace(obj.start_norm(3,line)',obj.stop_norm(3,line)',obj.voxels_for_ramp(line))'];
                    X = [X ; NaN];Y = [Y ; NaN];Z = [Z ; NaN];
                end
                plot3(X,Y,Z, 'LineStyle','-','Color',[0.3,0.3,0.3],'Marker','o','MarkerSize',2);hold on;
            end
            xlabel('X');ylabel('Y'),zlabel('Z');
            view([40,30]);hold on;axis equal
        end
    end
    
    methods (Hidden)
        function [start, stop] = generate_grid_diagonal(obj)
            %% Generate a single obj.mainscan_x_pixel_density ramp
            % from -1 to +1
            line_pts = linspace(-1, 1, obj.mainscan_x_pixel_density);
            start_x  = obj.start_norm_raw(1) + line_pts;
            start_y  = obj.start_norm_raw(2) + line_pts;
            start_z  = obj.start_norm_raw(3) * ones(size(start_x));
            start    = [start_x; start_y; start_z];
            stop     = start;
        end

        function [start, stop] = generate_rows(obj) % y fixed, scans x
            %% Generate obj.mainscan_x_pixel_density x obj.mainscan_x_pixel_density
            % ramps from -1 to +1
              %  drive_correction = obj.num_drives == 1; % Fix an issue with linspace when n drives is 1                
%                     res_correction = obj.voxels_for_ramp(line) > 1; % Fix an issue with single voxels
%                     X = [X ; linspace(obj.start_norm(1,line)' - drive_correction + res_correction,obj.stop_norm(1,line)' - drive_correction + res_correction,obj.voxels_for_ramp(line))'];
%                     Y = [Y ; linspace(obj.start_norm(2,line)' - drive_correction,obj.stop_norm(2,line)' - drive_correction,obj.voxels_for_ramp(line))'];
%     
            
            line_y  = linspace(-1, 1, obj.mainscan_x_pixel_density)' - (obj.mainscan_x_pixel_density == 1); % (obj.num_drives == 1) is a correction for single line res
            start_x = repmat(obj.start_norm_raw(1,:) - 1, obj.mainscan_x_pixel_density, 1);
            stop_x  = repmat(obj.start_norm_raw(1,:) + 1, obj.mainscan_x_pixel_density, 1);
            start_y = repmat(obj.start_norm_raw(2,:), obj.mainscan_x_pixel_density, 1) + repmat(line_y, 1, size(obj.start_norm_raw,2));
            start_z = repmat(obj.start_norm_raw(3,:), obj.mainscan_x_pixel_density, 1);
            start   = [start_x(:) start_y(:) start_z(:)]';
            stop    = [stop_x(:)  start_y(:) start_z(:)]';
        end
    end
end
