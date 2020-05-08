%% Superclass function dealing with the controller daq coms
% Controller class inherits these methods and properties
%
% Type doc function_name or help function_name to get more details about
% the function inputs and outputs
%
% -------------------------------------------------------------------------
% Syntax: N/A
% -------------------------------------------------------------------------
% Class Generation Inputs: N/A 
% -------------------------------------------------------------------------
% Outputs: N/A  
% -------------------------------------------------------------------------
% Class Methods: 
%
% * Restore DaQ connection and regenerate Controller.daq_fpga()
%   Controller.reset()
%
% * Reload values from scan_params.m OR mainscan_scan_params 
%   Controller.reset_scan_params(imaging_mode, non_default_resolution,
%                            ... non_default_aa, non_default_dwell_time)
%
% * Reload default values from aol_params.m 
%   Controller.reset_aol_params()
%
% * Send new main drives to the controller. Stop any running scan
%   Controller.send_drives(setup_viewer, nostop, pockel_voltages) 
%
% * Set/Reset a specific scan mode/resolution/FOV size
%   Controller.reset_frame_and_send(imaging_mode, non_default_resolution, 
%                               ... non_default_aa, non_default_dwell_time)
%
% * Restore current aa and resolution with mainscan values
%   Controller.restore_ref_drives()
% -------------------------------------------------------------------------
% Extra Notes:
% -------------------------------------------------------------------------
% Examples:
% -------------------------------------------------------------------------
%                               Notice
%
% Author(s): Antoine Valera, Geoffrey Evans, Boris Marin. 
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
%   24-03-2018
%
% See also: generate_frame


classdef drives < handle % superclass of Controller
    properties
    end

    methods        
        function reset(this)
            %% Restore DaQ connection and regenerate Controller.daq_fpga()
            % -------------------------------------------------------------
            % Syntax: 
            %   Controller.reset() 
            % -------------------------------------------------------------
            % Inputs:      
            % -------------------------------------------------------------
            % Outputs: 
            % -------------------------------------------------------------
            % Extra Notes:
            % This may be required if the synchronization is lost between
            % the AOL control and acquisition daQ, following a crash or if
            % you reload a previous experiment
            % -------------------------------------------------------------
            % Author(s):
            %   Antoine Valera, Geoffrey Evans, Boris Marin. 
            %---------------------------------------------
            % Revision Date:
            %   24-03-2018
            
            this.daq_fpga.capi.reset();
            this.daq_fpga.delete();
            this.daq_fpga = this.rig_params.create_daq_fpga();
            
            %% Adjust Clock Sync between systems
            if this.online
                this.rig_params.backplane_connected = connect_backplane('', '', strcmpi(this.rig_params.encoder_trigger_device,"hardware"), strcmpi(this.rig_params.ttl_trigger_device,"hardware")); % any hardware triggers
                this.daq_fpga.reset_clock();
            end
        end
        
        function reset_scan_params(this, imaging_mode, non_default_resolution, non_default_aa, non_default_dwell_time)
            %% Reload values from scan_params.m OR mainscan_scan_params 
            % -------------------------------------------------------------
            % Syntax: 
            %   Controller.reset_scan_params(imaging_mode, ... 
            %                                non_default_resolution,...
            %                                non_default_aa,...
            %                                non_default_dwell_time)
            % -------------------------------------------------------------
            % Inputs:      
            %   imaging_mode (STR) - Optional - Default is '' - any in 
            %   ... {'raster', 'pointing', 'miniscan' or 'functional'}
            %       Define the type of drives to generate. See scan_params
            %       for more information
            %   non_default_resolution (INT) - Optional - Default is ''
            %       If you want any resolution other that the default 
            %       scan_params resolution, set it here.
            %       If you want to restore the resolution from
            %       mainscan_resolution, set the value to -1. Frame shape
            %       is square.
            %   non_default_aa (FLOAT) - Optional - Default is ''
            %       If you want any resolution other that the default
            %       scan_params acceptance angle set it here.
            %       If you want to restore the acceptance angle mainscan_aa,
            %       set the value to -1
            %   non_default_dwell_time (FLOAT) - Optional - Default is ''
            %       If you want any resolution other that the default
            %       scan_params dwell time, set it here.
            %       If you want to restore the dwell time from voxel_time,
            %       set the value to -1
            % -------------------------------------------------------------
            % Outputs: 
            % -------------------------------------------------------------
            % Extra Notes:
            % -------------------------------------------------------------
            % Author(s):
            %   Antoine Valera, Geoffrey Evans, Boris Marin. 
            %---------------------------------------------
            % Revision Date:
            %   24-03-2018

            if nargin < 2 || isempty(imaging_mode)
                imaging_mode = ''; % then default value is defined in scan_params
            end
            
            if nargin < 3 || isempty(non_default_resolution)
                non_default_resolution = '';
            elseif non_default_resolution == -1
                non_default_resolution = this.scan_params.mainscan_x_pixel_density;
            end
            
            if nargin < 4 || isempty(non_default_aa)
                non_default_aa = '';
            elseif non_default_aa == -1
                non_default_aa = this.scan_params.acceptance_angle;
            end
            
            if nargin < 5 || isempty(non_default_dwell_time)
                non_default_dwell_time = this.scan_params.voxel_time; %%unless we want to reset the default from setup.ini?
            elseif non_default_dwell_time == -1
                non_default_dwell_time = this.scan_params.voxel_time; 
            end
            
            %% Reset scan_params, and set any non default value
            this.scan_params = default.scan_params(imaging_mode, non_default_resolution, non_default_aa, non_default_dwell_time, this.aol_params);
        end
        
        function set_miniscans(this, patches, non_default_pockel_voltages, z_offset_um, forced_res)
            %% Set drives for the miniscan(s) defined in "patches"
            % Read Extra Notes for variable length/variable res
            % -------------------------------------------------------------
            % Syntax: 
            %   Controller.set_miniscans(this, patches,...
            %       non_default_pockel_voltages, z_offset_um, forced_res)
            % -------------------------------------------------------------
            % Inputs:
            %   patches (Cell array of planes object)
            %     Patches as defined in ScanParams.generate_miniscan_boxes.
            %     See documentation for more details. Dimensions are in
            %     pixels (in relation to mainscan_x_pixel_density)
            %   non_default_pockel_voltages (FLOAT or N x num drives FLOAT)
            %           - Optional - default is current value
            %     You can pass any pocekl cell value. If you pass a single
            %     value, the value is set for all drives. Otherwise, the
            %     number of values must match the number of drives
            %   z_offset_um (FLOAT) - Optional - default is 0
            %     The planes are set relative to the current natural plane.
            %     To scan another location, you can pass an extra Z offset
            %     in um.
            %   forced_res (INT or 2x1 INT or 1xN patches or 2xN patches
            %           matrix/cell array of INT) - Optional - default is [];
            %     When generating drives, the default resolution is defined
            %     by mainscan_x_pixel_density. You can pass a value to
            %     modify the resolution in the scanning direction, or the 
            %     number of lines in the patch.
            %       - If you pass an single INT, the value is set as line
            %       resolution for all lines
            %       - If you pass a 2x1 INT, the first value is set as the
            %       number of lines per patch and the second as the
            %       resolution for each line. A value of 0 for the first
            %       one will keep the default number of lines
            %       - If you pass a 1xN Matrix or cell array, it must have
            %       one value per patch. The value will be set as a number
            %       of lines for each patch.
            %       - If you pass a 2xN Matrix or cell array, it must have
            %       one value per patch. the first value is set as the
            %       number of lines per patch and the second as the
            %       resolution for each line. A value of 0 for the first
            %       one will keep the default number of lines       
            % -------------------------------------------------------------
            % Outputs: 
            % -------------------------------------------------------------
            % Extra Notes:
            %   This code generates planes.
            %   - v1 is the scanning direction. It fixes the line 
            %   resolution, although you can adjust that by changing 
            %   ScanParams.voxels_for_ramp later on.
            %   - v2 is the second vector of the plane, and determines the
            %   number of lines, based on the v2 size and current main_scan
            %   resolution. This cannot be changed later.
            %   - v3 is expected to be [0;0;0] as it is used vor volumes
            %   only.
            %
            %   Setting variable resolution per patch requires
            %   ScanParams.fixed_res to be false. If you pass manually a
            %   forced_res parameter, fixed_res will be adjusted for you.
            %   Other wise, you must do it manually BEFORE calling this
            %   function.
            %   If you plan to have variable length, you must set
            %   ScanParams.fixed_len to false BEFORE calling the function.
            %   See demo_patch_generation() for some examples
            % -------------------------------------------------------------
            % Author(s):
            %   Antoine Valera. 
            %---------------------------------------------
            % Revision Date:
            %   29-09-2018
            
            if nargin < 3 || isempty(non_default_pockel_voltages)
                non_default_pockel_voltages = this.pockels.on_value;
            end
            if nargin < 4 || isempty(z_offset_um)
                z_offset_um = 0;
            end
            if nargin < 5 || isempty(forced_res)
                forced_res = []; % auto
            elseif iscell(forced_res)
                forced_res = cell2mat(forced_res);
                this.scan_params.fixed_res = false;
            elseif size(forced_res, 1) == 1
                forced_res = repmat(forced_res, 1, numel(patches));                
            end
            
            this.scan_params.imaging_mode = ImagingMode.Miniscan;
            start_norm_raw = []; stop_norm_raw  = [];            
            for el = 1:numel(patches)
                corner = patches{el}.corner; v1 = patches{el}.v1; v2 = patches{el}.v2;% v3 = planes{el}.v3;
                corner(3) = corner(3) + (z_offset_um / this.aol_params.get_pixel_size) / this.aol_params.xy_z_norm_ratio; % convert Z um offset to XY pixels
                if ~isempty(forced_res) && size(forced_res, 1) == 2 && forced_res(2,el)
                    nlines = forced_res(2,el); % manually set nlines for this patch
                elseif any(v2) || (size(forced_res, 1) == 2 && ~forced_res(2,el))
                    nlines = norm(v2); % auto set nlines for this patch
                else
                    nlines = 1; % adjust for linescan
                end
                starts = [ linspace(corner(1),      corner(1)+v2(1)      ,nlines) ;... %X-Y-Z Start of each line
                           linspace(corner(2),      corner(2)+v2(2)      ,nlines) ;...
                           linspace(corner(3),      corner(3)+v2(3)      ,nlines) ];
                stops =  [ linspace(corner(1)+v1(1),corner(1)+v1(1)+v2(1),nlines) ;... %X-Y-Z Stop  of each line
                           linspace(corner(2)+v1(2),corner(2)+v1(2)+v2(2),nlines) ;...
                           linspace(corner(3)+v1(3),corner(3)+v1(3)+v2(3),nlines) ];
                start_norm_raw = [start_norm_raw, this.aol_params.convert_xyz_pixels_to_norm(starts)];
                stop_norm_raw  = [stop_norm_raw , this.aol_params.convert_xyz_pixels_to_norm(stops )];
            end
            
            %% Don't forget to adjust fixed_len/fixed_res in advance
            this.scan_params.start_norm_raw = start_norm_raw;
            this.scan_params.stop_norm_raw  = stop_norm_raw ;
            
            if ~isempty(forced_res) && forced_res(1,el)
                this.scan_params.voxels_for_ramp = forced_res(1,el)     ; %% QQ Think of a way to get that behaviour automatically
                this.scan_params.pockels_raw     = this.pockels.on_value;
            end
            this.send_drives(true, non_default_pockel_voltages);
        end

        function reset_aol_params(this)
            %% Reload default values from aol_params.m 
            % (including default wavelength and objective)
            % -------------------------------------------------------------
            % Syntax: 
            %   Controller.reset_aol_params() 
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
            %   24-03-2018
            
            %% Reset aol_params and set any non default value
            this.aol_params = default.aol_params();
        end
        
        function send_drives(this, setup_viewer, pockel_voltages, precalc_drives, precalc_drive_coeffs) 
            %% Send new main drives to the controller. Stop any running scan
            % -------------------------------------------------------------
            % Syntax: 
            %   Controller.send_drives(setup_viewer, pockel_voltages, precalc_drives, precalc_drive_coeffs) 
            % -------------------------------------------------------------
            % Inputs:
            %  setup_viewer(BOOL) - Optional - default is true
            %       id true, create viewer is called and will generate a
            %       rectangular live viewer of resolution
            %       mainscan_x_pixel_density x num_voxels. This required
            %       if the resolution of the scan changes
            %  pockel_voltages(SCALAR OR (1 x N) or (4 x N DOUBLE MATRIX)) 
            %       - Optional - default is current pockel cell voltage
            %       You can set a different pockel cell value for each line
            %       of the scan   
            %  precalc_drives(Cell Array of (1 x 13 Cells)) -
            %           Optional - default is [];
            %       The drives that could be send for the required scan.
            %       You can store them, and pass them later for faster
            %       loading.
            % -------------------------------------------------------------
            % Outputs: 
            % -------------------------------------------------------------
            % Extra Notes:
            %   Do not forget to update the acquisition side of the
            %   system. 
            %   If you send new drives and want to keep the live viewer
            %   rendering the same, you must call Controller.send_drives(false)  
            %   When changing settings in the GUI, you can call
            %   send_drives_and_scan instead.
            % -------------------------------------------------------------
            % Author(s):
            %   Antoine Valera, Geoffrey Evans, Boris Marin. 
            %---------------------------------------------
            % Revision Date:
            %   17-02-2018
            %
            % See also: send_drives_and_scan

            if nargin < 3
                pockel_voltages = this.pockels.on_value;
            end
            if nargin < 4
                precalc_drives = [];
            end
            if nargin < 5
                precalc_drive_coeffs = [];
            end
            
            %% Send new drives
            if this.daq_fpga.is_correcting
                this.daq_fpga.safe_stop();
            end
            
            this.synth_fpga.load(this.aol_params, this.scan_params, false, this.scan_params.mainscan_x_pixel_density, this.scan_params.acceptance_angle, this.daq_fpga.z_pixel_size_um, pockel_voltages, precalc_drives, precalc_drive_coeffs); % send NON MC drives. for mc drives, see Controller.mouvement_correction
            %this.pockels.prepare_ramp(this.scan_params, this.pockels.on_value, this.aol_params.fill_time * 1e9, this.frame_cycles);
            
            %% Create a new viewer (do that when you change viewer type or resolution)
            if nargin == 1 || setup_viewer
                create_viewer(this);
            end
        end
        
        function [xy_records, drive_coeffs] = precalculate_drives(this, pockel_voltages)
            %% Send new main drives to the controller. Stop any running scan
            % -------------------------------------------------------------
            % Syntax: 
            %   Controller.precalculate_drives(pockel_voltages) 
            % -------------------------------------------------------------
            % Inputs:
            %  pockel_voltages(SCALAR OR (1 x N) or (4 x N DOUBLE MATRIX)) 
            %       - Optional - default is current pockel cell voltage
            %       You can set a different pockel cell value for each line
            %       of the scan         
            % -------------------------------------------------------------
            % Outputs: 
            %  xy_records(Cell Array of (1 x 13 Cells)) 
            %       The drives that could be send for the required scan.
            %       You can store them, and pass them later for faster
            %       loading.
            %  drive_coeffs(drive_coeffs object) 
            %       The drivers coefficient.
            % -------------------------------------------------------------
            % Extra Notes:
            %   This will calculate but not send the drives. You can
            %   capture the output, and then pass it in send_drives for a
            %   much faster scanning.
            % -------------------------------------------------------------
            % Author(s):
            %   Antoine Valera
            %---------------------------------------------
            % Revision Date:
            %   26-09-2018

            if nargin < 2
                pockel_voltages = this.pockels.on_value;
            end

            %% PreCalculate but don't send new drives
            [xy_records, drive_coeffs] = this.synth_fpga.load(this.aol_params, this.scan_params, false, this.scan_params.num_drives, this.scan_params.acceptance_angle, this.daq_fpga.z_pixel_size_um, pockel_voltages);
        end
        
        function reset_frame_and_send(this, imaging_mode, non_default_resolution, non_default_aa, non_default_dwell_time)
            %% Set/Reset a specific scan mode/resolution/FOV size
            % -------------------------------------------------------------
            % Syntax: 
            %   Controller.reset_frame_and_send(imaging_mode,
            %                       non_default_resolution, non_default_aa,
            %                       non_default_dwell_time)
            % -------------------------------------------------------------
            % Inputs:      
            %   imaging_mode (STR) - Optional - Default is '' - any in 
            %   ... {'raster', 'pointing', 'miniscan' or 'functional'}
            %       Define the type of drives to generate. See scan_params
            %       for more information
            %   non_default_resolution (INT) - Optional - Default is ''
            %       If you want any resolution other that the default 
            %       scan_params resolution, set it here.
            %       If you want to restore the resolution from
            %       mainscan_resolution, set the value to -1. Frame shape
            %       is square.
            %   non_default_aa (FLOAT) - Optional - Default is ''
            %       If you want any resolution other that the default
            %       scan_params acceptance angle set it here.
            %       If you want to restore the acceptance angle mainscan_aa,
            %       set the value to -1
            %   non_default_dwell_time (FLOAT) - Optional - Default is ''
            %       If you want any resolution other that the default
            %       scan_params dwell time, set it here.
            %       If you want to restore the dwell time from voxel_time,
            %       set the value to -1
            % -------------------------------------------------------------
            % Outputs: 
            % -------------------------------------------------------------
            % Extra Notes:
            % If another resolution, acceptance angle or dwell time is 
            % passed, the full frame values are updated. If one of this
            % value is -1, the current value is kept. If the field is
            % empty, scan_params default values are set. 
            % The viewer is always reset.
            % -------------------------------------------------------------
            % Author(s):
            %   Antoine Valera, Geoffrey Evans, Boris Marin. 
            %---------------------------------------------
            % Revision Date:
            %   24-03-2018
            
            if nargin < 2 || isempty(imaging_mode)
                imaging_mode = '';
            end
            
            if nargin < 3 || isempty(non_default_resolution)
                non_default_resolution = '';
            elseif non_default_resolution == -1
                non_default_resolution = this.scan_params.mainscan_x_pixel_density;
            end
            
            if nargin < 4 || isempty(non_default_aa)
                non_default_aa = '';
            elseif non_default_aa == -1
                non_default_aa = this.scan_params.acceptance_angle;
            end
            
            if nargin < 5 || isempty(non_default_dwell_time)
                non_default_dwell_time = this.scan_params.voxel_time; %%unless we want to reset the default from setup.ini?
            elseif non_default_dwell_time == -1
                non_default_dwell_time = this.scan_params.voxel_time; 
            end
            
            %% Reset san params to basic value
            this.reset_scan_params(imaging_mode, non_default_resolution, non_default_aa, non_default_dwell_time);
            
            %% Send drives to Control FPGA (and adjust viewer)
            this.send_drives(true);
        end 
        
        function restore_ref_drives(this)
            %% Restore current aa and resolution using mainscan values
            % Use it after passing a miniscan to restore full frame
            % -------------------------------------------------------------
            % Syntax: 
            %   Controller.restore_ref_drives() 
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
            %   24-03-2018
            this.reset_scan_params('raster', this.scan_params.mainscan_x_pixel_density, this.scan_params.acceptance_angle, this.scan_params.voxel_time);
        end
    end
end