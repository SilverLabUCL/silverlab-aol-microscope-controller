%% Estimate the scanning speed and expected number of cycles for a given scan
%   The calculation will be using the current Controller.scan_parameters
%   for the mainscan speed, and if
%   Controller.daq_fpga.use_movement_correction is true, it will use
%   Controller.mc_scan_parameters to estimate the MC overhead. Real scan
%   speed will be adjusted accordingly. 
%
% -------------------------------------------------------------------------
% Syntax: 
%   [number_of_cycles, cycle_duration, number_of_lines, number_of_points,
%       line_length, MC_overhead] = 
%       estimate_points(controller, recording_params_or_duration, verbose)
%
% -------------------------------------------------------------------------
% Inputs: 
%   controller(Controller object) - Optional - Default is main Controller: 
%                                   Contains information about the
%                                   microscope setup such as FOV, dwell
%                                   time etc...
%
%   acquisition_params_or_duration (acquisition_params objet or FLOAT) - 
%       Optional - Default values is for 1s recording:
%                                   The acquisition_params object use for
%                                   the scan, with it's .duration field and 
%                                   number_of_cycles field , or
%                                   a duration in seconds.
%
%   verbose(BOOL) - Optional - Default is true
%                                   If true, information about the expected
%                                   scan are printed in the console
% -------------------------------------------------------------------------
% Outputs:
%   number_of_cycles(INT)
%                                   The expected number of cycles for a
%                                   scan of the defined duration,
%                                   corrected for MC if required. If the
%                                   recording_params.number_of_cycles is 0,
%                                   then the duration field is used. In
%                                   that case, because the system will be
%                                   using a timer, the last cycle will be
%                                   incomplete.
%
%   cycle_duration(FLOAT)
%                                   In seconds, the mean duration required 
%                                   to do a cycle. Duration is fixed
%                                   without MC, but can vary slightly if MC
%                                   is on.
%
%   number_of_lines(INT)
%                                   The number of lines per cycle. Total
%                                   number of line is therefore
%                                   number_of_lines * line_length
%
%   number_of_points(INT)
%                                   The number of points for the whole
%                                   recording
%
%   line_length(INT)
%                                   The number of pixels per line
%
%   duration(FLOAT) :
%                                   In some conditions, the number of
%                                   cycles does not exactly match the
%                                   desired duration, and is rounded up.
%                                   This is the real acquisition duration
%
%   MC_overhead(FLOAT)
%                                   The cost of MC for the current scan
%                                   sttings
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
%   Revision 24-02-2019
%
% See also: ScanParams, estimate_scan_frequency_from_raw, simplify_morpho,
%   estimate_scan_frequency
%

function [number_of_cycles, cycle_duration, number_of_lines, number_of_points, line_length, duration, MC_overhead] = estimate_points(controller, acquisition_params_or_duration, verbose)
    if nargin < 1 || isempty(controller)
        controller = get_existing_controller_name(true);
    end
    if nargin < 2 || isempty(acquisition_params_or_duration)
        recording_params = controller.scan_params;
        duration = 1; % For 1s
    elseif isnumeric(acquisition_params_or_duration)
        recording_params = controller.scan_params;
        duration = acquisition_params_or_duration; % For 1s
    else
        recording_params = acquisition_params_or_duration;
        duration = acquisition_params_or_duration.duration;
    end
    if nargin < 3 || isempty(verbose)
        verbose = true;
    end
    
    %% Get total list of lines
    if ~isfield(recording_params,'res_list')
        number_of_lines = controller.scan_params.num_drives;
    else
        number_of_lines = sum(recording_params.res_list(:,2).*recording_params.res_list(:,3));
    end
    
    %% Get scan rate
    [fps, ~ , MC_overhead] = controller.scan_params.get_fps(1, controller.mc_scan_params, double(controller.daq_fpga.MC_rate) * double(controller.daq_fpga.use_movement_correction));

    %% Estimating line length
    %%qq will be wrong with variable length
    if strcmp(controller.scan_params.imaging_mode, 'Pointing') || strcmp(controller.scan_params.imaging_mode, 'Functional') || (isfield(recording_params, 'mode') && strcmp(recording_params.mode, 'Points'))
        line_length = ones(1, controller.scan_params.num_drives);
    else
        line_length = controller.scan_params.voxels_for_ramp; % nb of points per line 
    end
    
    %% Update scan duration as we always finish the last cycle
    if isfield(recording_params,'number_of_cycles') && recording_params.number_of_cycles %% In the case you want a defined number of frames
        number_of_cycles = recording_params.number_of_cycles;
    else
        number_of_cycles = ceil(duration*fps);        
    end
    
    %% Correct duration to so last cycle is complete
    duration = number_of_cycles*1/fps;
   
    %% Now get the real expected number of data points and mean cycle duration (which includes average MC overhead if MC is on)
    cycle_duration = 1/fps; % Cycle duration, including MC
    number_of_points = sum(line_length) * number_of_cycles;
    
    %% Print output
    if verbose
        fprintf('	...     Estimated frequency : %.2f Hz \n' , fps);
        fprintf('	...     Estimated number of timepoints for %.2f seconds : %.0f \n', duration, number_of_cycles);
        fprintf('	...     Number of lines per cycle is %d \n',number_of_lines);
        if controller.daq_fpga.use_movement_correction
            fprintf('	...     MC overhead is %2.2f%% \n', 100 * MC_overhead);
        end
    end
end