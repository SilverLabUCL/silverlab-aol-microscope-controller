%% Create default scan_params, using specified imaging_mode and setup.ini
%   Generates a new ScanParams object correspondign to a full frame.
%   Determines the scan mode used. Ramps values can be modified later on.
%   ScanParams handle includes current wavelength, resolution, zoom,
%   angles, offsets and curvature, and the maximal amplitudes passed to 
%   the crystal, plus the ramps. 
%
% -------------------------------------------------------------------------
% Syntax: 
%   sp = default.scan_params(imaging_mode, non_default_resolution, ...
%                               non_default_aa, non_default_dwell_time)
% -------------------------------------------------------------------------
% Inputs: 
%   imaging_mode(STR) - Optional - Default is 'raster'. Defines the type
%       of scan. any in {'raster','functional','pointing','miniscan}
%                                   imaging_mode defines specific set of
%                                   constraints on the drives (see
%                                   ScanParams) and control the way
%                                   ethernet drives are sent (see
%                                   SynthFpga)
%
%   non_default_resolution(INT) - Optional - default is 400
%                                   frame resolution. Modifies 
%                                   scan_params.mainscan_x_pixel_density
%
%   non_default_aa(FLOAT) - Optional - default is 400
%                                   acceptance angle in milliradians.  
%                                   Modifies scan_params.acceptance_angle 
%
%   non_default_dwell_time(FLOAT) - Optional - default is 100e-9
%                                   dwell time. Modifies
%                                   scan_params.voxel_time
% -------------------------------------------------------------------------
% Outputs:
%   scan_params(ScanParams handle) :
%                                   return a new ScanParams object, using
%                                   default or non_default parameters
% -------------------------------------------------------------------------
% Extra Notes:
%
% * Unless specified, reloading scan params will reset the default 
%   acceptance angle, resolution and dwell time  
%
% * Current smallest possible voxel time is 0.05e-6
%   Current maximal possible mainscan_x_pixel_density is 2048
%
% * Enabling Amplitude modulation require a specific firmware and to call
%       params.amp_raw = @(a,b,c) freq_to_amp(a, b, c, [170 190 250 250],
%                                       [2,3,2.4,1.6], [39, 39, 39, 39]);
%
% * start_norm_raw are offset in normalized coordimnates (X-Y-Z)
%
% * angles are X-Y-Z rotation in degrees
%
% -------------------------------------------------------------------------
% Examples:
%
% * Example for a default raster scan:
%   sp = default.scan_params('raster')
%   sp.plot_drives();
%
% * Example for a raster scan of resolution 800x800:
%   sp = default.scan_params('raster', 800)
%   sp.plot_drives();
%
% * Example for a raster scan of default resolution, but 200ns dwell time
%   sp = default.scan_params('raster', [], [], 0.2e-6)
%   sp.plot_drives();
% -------------------------------------------------------------------------
%                               Notice
%
% Author(s): Geoffrey Evans, Antoine Valera
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
%   17-02-2019
%
% See also: drives, ScanParams, 

%   TODO : Amplitude modulation is currently controlled here, but should be 
%   moved elsewhere in the future%

function scan_params = scan_params(imaging_mode, non_default_resolution, non_default_aa, non_default_dwell_time, aol_params_handle)

    if nargin < 1 || isempty(imaging_mode);             imaging_mode = 'raster';                    end
    if nargin < 2 || isempty(non_default_resolution);	non_default_resolution = [];                end
    if nargin < 3 || isempty(non_default_aa);           non_default_aa = [];                        end
    if nargin < 4 || isempty(non_default_dwell_time);   non_default_dwell_time = [];                end
    if nargin < 5 || isempty(aol_params_handle);        aol_params_handle = default.aol_params;     end

    %% Update rig_specific code using setup.ini
    C = load_ini_file([],'[Main Configuration File]');
    
    %% Load default scan params parameters
    scan_params = default_scan(4, aol_params_handle);

    scan_params.voxel_time = read_ini_value(C,  'Pockels cal.Dwell time (µs)') * 1e-6;
    scan_params.amp_raw = [...
        read_ini_value(C,  'Control system.AOD 1 Amplitude');...
        read_ini_value(C,  'Control system.AOD 2 Amplitude');...
        read_ini_value(C,  'Control system.AOD 3 Amplitude');...
        read_ini_value(C,  'Control system.AOD 4 Amplitude')];
    scan_params.X_Y_swapped = read_ini_value(C,  'Are X Y Swapped');
    scan_params.mainscan_x_pixel_density = round(read_ini_value(C,  'Initial Scan Resolution')); 
    scan_params.acceptance_angle = read_ini_value(C,  'Initial Acceptance Angle (mrad)') * 1e-3;
    
    scan_params = generate_frame(scan_params, imaging_mode,...
           non_default_resolution, non_default_aa, non_default_dwell_time);
end

function scan_params = default_scan(n, aol_params_handle)
    scan_params = ScanParams(aol_params_handle);
    scan_params.mainscan_x_pixel_density = 400;   
    scan_params.acceptance_angle = 5e-3;
    scan_params.voxel_time = 0.1e-6;
    scan_params.start_norm_raw = [0;0;0];
    scan_params.stop_norm_raw = scan_params.start_norm_raw; 
    scan_params.c_waves = zeros(n,1);
    scan_params.d_waves = zeros(n,1);
    scan_params.D = [0, 0]; %from Geoff thesis
    scan_params.angles = [0, 0, 0]; %[x y z] in degrees; for demo try [90,90,-90] and [0,1,0]. [90,0,90] face the camera
    scan_params.X_Y_swapped = false;
end 

    
%     elseif rig_id == 2
%         params.amp_raw = [100 100 100 100]'; %2 and 3 i
%
%     elseif rig_id == 5
%         params = default_scan(6);
%         params.amp_raw = [210 200 225 220 215 200];
%         params.mainscan_x_pixel_density = 200; 
%         params.acceptance_angle = 5e-3;
%     end