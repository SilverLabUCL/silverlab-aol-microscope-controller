%% Default AOL-hardware parameters. Values are updated using setup.ini
%   AolParams handle containing key information regarding Aol hardware
%   Some parameters must be regularly calibrated using tools in the 
%   utilities/calibration folder. Update calibrated values in 
%   calibration.ini 
%
%   To adjust timing_offsets, distortion_corr, or norm_to_um scaling please
%   refer to the manual 'Matlab User manual.docx'
% -------------------------------------------------------------------------
% Syntax: 
%   aol_params = aol_params(non_default_objective, non_default_wavelength)
%
% Example for a default aol_params:
%   aol_params = aol_params()
%
% Example for a aol_params with a specific objective (the objective must be
%               in calibration.ini): aol_params = aol_params('Nikon 20X')
%
% -------------------------------------------------------------------------
% Inputs: 
%   non_default_objective(STR) - Optional - Default is loaded from
%               setup.ini 'Current Objective' field. otherwise pass a
%               string with the name of the objective you are using. 
%               (e.g 'Nikon 20X). the string will be reformated into 
%               '[Objective.Nikon 20X]'
%
%   non_default_wavelength(FLOAT) - Optional  - Default is loaded from
%               setup.ini 'Laser wavelength (nm)' field 
%               If you changed laser wavelength, update this value as it
%               will affect timing offsets.
%               
% -------------------------------------------------------------------------
% Outputs:
%   aol_params(AolParams handle) : return a new AolParams object, using
%               default or non_default parameters. If the wavelength
%               changes, the timing offsets are auto-corrected
%
% -------------------------------------------------------------------------
% Extra Notes:
% * Calibration values are depending on the wavelength. If the wavelength 
%   is changed, please reload aol_params. The default wavelength
%    corresponds to the one used for calibration
% -------------------------------------------------------------------------
% Examples:
% -------------------------------------------------------------------------
%                               Notice
%
% Author(s):
%   Geoffrey Evans, Antoine Valera, Paul Kirkby
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
% See also: Controller, AolParams

function aol_params = aol_params(non_default_objective, non_default_wavelength)
    % Warning : pure matlab default are not updated from setup.ini
    
    %% read main setup.ini file
    [C,~] = load_ini_file([],'[Main Configuration File]');
    
    %% load default values for the right AOD config
    aol_params = default_aol(read_ini_value(C,  'Num AOD', 4));
    
    %% Update aol_params using config.ini
    % this section updates the code from default_aol()
    aol_params.synth_clock_freq = 1e6 * read_ini_value(C, 'Control system.Clock freq (MHz)');
    %should amplitudes be here?
    aol_params.synth_data_time_interval = 1e-9 * read_ini_value(C, 'Control system.Data Time Interval (ns)'); %Not used in matlab
    aol_params.synth_t0 = 1e-9 * read_ini_value(C, 'Control system.T0 (ns)'); %Not used in matlab
    aol_params.synth_ta = 1e-9 * read_ini_value(C, 'Control system.Ta (ns)'); %Not used in matlab
    aol_params.daq_clock_freq = 1e6 * read_ini_value(C, 'DAQ FPGA.Clock freq (MHz)');
    aol_params.sampleswaitaftertrigger = read_ini_value(C,  'DAQ FPGA.Samples Wait after Trigger');
    aol_params.aod_fill = read_ini_value(C,  'DAQ FPGA.AOD fill'); %previously computed with aol_params.daq_clock_freq .* aol_params.fill_time 
    aol_params.startup_delay = read_ini_value(C, 'DAQ FPGA.StartupDelay');
    aol_params.current_wavelength = read_ini_value(C,  'Laser wavelength (nm)') * 1e-9;
    
    aol_params.aod_thickness = 1e-3 * [...
        read_ini_value(C,  'AOD 1 Thickness (mm)'),...
        read_ini_value(C,  'AOD 2 Thickness (mm)'),...
        read_ini_value(C,  'AOD 3 Thickness (mm)'),...
        read_ini_value(C,  'AOD 4 Thickness (mm)')];
    aol_params.aod_spacing = 1e-3 * [...
        read_ini_value(C,  'AOD 1-2 Separation (mm)'),...
        read_ini_value(C,  'AOD 2-3 Separation (mm)'), ...
        read_ini_value(C,  'AOD 3-4 Separation (mm)')];
    aol_params.aod_xy_offsets = -[...
        read_ini_value(C,  'AOD 1 X Offset'), ...
        read_ini_value(C,  'AOD 2 X Offset'), ...
        read_ini_value(C,  'AOD 3 X Offset'), ...
        read_ini_value(C,  'AOD 4 X Offset'); ...
            read_ini_value(C,  'AOD 1 Y Offset'), ...
            read_ini_value(C,  'AOD 2 Y Offset'), ...
            read_ini_value(C,  'AOD 3 Y Offset'), ...
            read_ini_value(C,  'AOD 4 Y Offset')]; % adjusted in time_offsets
    aol_params.aod_dirs = [...
        read_ini_value(C,  'AOD 1 X Direction'), ...
        read_ini_value(C,  'AOD 2 X Direction'), ...
        read_ini_value(C,  'AOD 3 X Direction'), ...
        read_ini_value(C,  'AOD 4 X Direction'); ...
            read_ini_value(C,  'AOD 1 Y Direction'), ...
            read_ini_value(C,  'AOD 2 Y Direction'), ...
            read_ini_value(C,  'AOD 3 Y Direction'), ...
            read_ini_value(C,  'AOD 4 Y Direction')]; % adjusted in time_offsets
    aol_params.transducer_centre_dist = 1e-3 * [...
        read_ini_value(C,  'AOD 1 Centre (mm)'),...
        read_ini_value(C,  'AOD 2 Centre (mm)'),...
        read_ini_value(C,  'AOD 3 Centre (mm)'),...
        read_ini_value(C,  'AOD 4 Centre (mm)')];
    
    aol_params.optical_offsets = 1e-3 * [...
        read_ini_value(C,  'AOD Optical Offset 1 (mm)'),...
        read_ini_value(C,  'AOD Optical Offset 2 (mm)')];   
    aol_params.aod_diff_mode = read_ini_value(C,  'Diffraction mode'); %not used in matlab drivers
    aol_params.crystal_length = 1e-3 * read_ini_value(C,  'crystalLength (mm)'); %not used in matlab
    aol_params.aod_ac_vel = read_ini_value(C,  'Acoustic velocity (m/s)');
    aol_params.ord_ref_ind = read_ini_value(C,  'AOD Ord. Refractive index'); % basically fixed
    aol_params.extraord_ref_ind = read_ini_value(C,  'AOD ExtraOrd. Refractive index'); % basically fixed
    aol_params.aod_aperture = 1e-3 * read_ini_value(C,  'AOL Aperture (mm)');
    aol_params.aod_central_wavelength = 1e-9 * read_ini_value(C,  'AOL centre wavelength (nm)');
    aol_params.aligned_central_frequency = 1e6 * read_ini_value(C,  'AOL centre frequency (MHz)') * ones(1,aol_params.num_aods); % in matlab it s params.central_frequency = 35e6 * ones(1,4) or 39e6 * ones(1,6) for 6 AOD
    aol_params.central_frequency = 1e6 * read_ini_value(C,  'AOL centre frequency (MHz)') * ones(1,aol_params.num_aods); % in matlab it s params.central_frequency = 35e6 * ones(1,4) or 39e6 * ones(1,6) for 6 AOD
    aol_params.pair_def_ratio = read_ini_value(C,  'Pair Deflection Ratio'); % for scanning it should be 1, but pointing may use other values for bigger FOV
    aol_params.end_aod_centre_to_ref = [0, 0, 0]; % not used yet

    %% read values from calibration.ini file
    [C,filepath] = load_ini_file([],'[Calibration File]');
    aol_params.calibration_file_path = filepath;
    
    if nargin < 1 || isempty(non_default_objective) %then we load the default non_default_objective
        non_default_objective = ['[Objective.',read_ini_value(C,  'Current Objective'),']'];
    else
        if ~contains(non_default_objective,'[Objective.')
            non_default_objective = ['[Objective.',non_default_objective,']'];
        end
    end
    
    % this section updates the code from default_calibration()
    aol_params.current_objective = non_default_objective;  
    aol_params.calibration_wavelength = read_ini_value(C,  'Calibration Wavelength (nm)', [], non_default_objective) * 1e-9;
    aol_params.sum_x = read_ini_value(C,  'Sum X', [], non_default_objective);
    aol_params.sum_y = read_ini_value(C,  'Sum Y', [], non_default_objective);
    aol_params.difference_x = read_ini_value(C,  'Diff X', [], non_default_objective);
    aol_params.difference_y = read_ini_value(C,  'Diff Y', [], non_default_objective);
    aol_params.distortion_corr = read_ini_value(C,  'Distortion Correction', [], non_default_objective);
    aol_params.z_norm_to_um_scaling = read_ini_value(C,  'Z_norm to um_scaling', [], non_default_objective);
    aol_params.x_norm_to_um_scaling = read_ini_value(C,  'X_norm to um_scaling', [], non_default_objective);
    aol_params.z_refraction_correction = read_ini_value(C,  'Z Refraction Correction', 0, non_default_objective);
    if nargin >= 2 && ~isempty(non_default_wavelength) && ~isnan(non_default_wavelength) % NaN when laser is offline in our system
        aol_params.current_wavelength = non_default_wavelength; % Also adjust central_frequency
    end
end

function aol_params = default_aol(num_aods)
    aol_params = AolParams();
    aol_params.synth_clock_freq = 240e6;
    aol_params.synth_data_time_interval = 50e-9; %Not used in matlab
    aol_params.synth_t0 = 1e-9 * 0; %Not used in matlab
    aol_params.synth_ta = 1e-9 * 0; %Not used in matlab
    aol_params.daq_clock_freq = 200e6;
    aol_params.sampleswaitaftertrigger = 4895;  % changed to work with Virtex 7 board
    aol_params.aod_fill = 4895; %previously computed with aol_params.daq_clock_freq .* aol_params.fill_time 
    aol_params.startup_delay = 0;
    aol_params.current_wavelength = 920e-9; 
    
    aol_params = default_aol_4(aol_params);

    aol_params.aod_thickness = 8e-3 * ones(1,aol_params.num_aods);
    aol_params.aod_spacing = 5e-2 * ones(1,aol_params.num_aods-1);
    aol_params.transducer_centre_dist = 7.5e-3 * ones(1,aol_params.num_aods); %aol_params.transducer_centre_dist = ones(1,4) * 1e-3 * read_ini_value(C,  'crystalLength (mm)')./ 2;
    
    aol_params.optical_offsets = 1e-3 * [0, 0]; 
    aol_params.aod_diff_mode = -1; %not used in matlab
    aol_params.crystal_length = 15 * 1e-3; %not used in matlab
    aol_params.aod_ac_vel = 613;
    aol_params.ord_ref_ind = 2.22;
    aol_params.extraord_ref_ind = 2.44; %QQ to check (Paul)
    aol_params.aod_aperture = 15e-3;
    aol_params.aod_central_wavelength = 920e-9;
    aol_params.aligned_central_frequency = 39*1e6;
    aol_params.central_frequency = 39*1e6;
    aol_params.pair_def_ratio = 0.3;
    aol_params.end_aod_centre_to_ref = [0, 0, 0];

    % default values with no correction. default values are used with offline analysis
    aol_params = default_calibration(aol_params);
end

function aol_params = default_aol_4(aol_params)
    aol_params.num_aods = 4;

    aol_params.aod_xy_offsets = -[0, 0.0023, 0.0046, 0.0046;...
                              0, 0    , 0.0023, 0.0046];
    aol_params.aod_dirs = [1, 0, -1, 0; 0, 1, 0, -1];% implicit in drive calculation
end

function aol_params = default_calibration(aol_params)

    % default values with no correction. default values are used with offline analysis
    aol_params.calibration_wavelength = 920 * 1e-9;
    aol_params.sum_x = 0;
    aol_params.sum_y = 0;
    aol_params.difference_x = 0;
    aol_params.difference_y = 0;
    aol_params.current_objective = '[Objective.Nikon 40X]';
    aol_params.x_norm_to_um_scaling = 20000;
    aol_params.z_norm_to_um_scaling = 20000;
    aol_params.distortion_corr = 1; % focal length + (params.distortion_corr * scan_params.acceptance_angle) = Zi ; Zi is the distance from the lens to the AOL. P.K. Introduced sept 2016
    aol_params.z_refraction_correction = 0;
    aol_params.z_offset_norm = 0;
end