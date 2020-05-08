%% Prepare a data holder for a timed image
% This is a helper function for Controller.timed_image(). If the input is a
% duration in seconds, it estimates the number of cycles and set this value
% in parameters.d
%
% -------------------------------------------------------------------------
% Syntax: 
%   [all_data, parameters, time, n_cycles] = initialise_timed_image(controller, varargin)
%
% -------------------------------------------------------------------------
% Inputs: 
%   controller(Controller object) - Optional - Default is main Controller: 
%                                   Contains information about the
%                                   microscope setup such as FOV, dwell
%                                   time etc...
%
%   varargin(timing_params object AND/OR {'Argument',Value} pairs):  
%                                   Any pair of 'argument' and value from 
%                                   timing_params.m See function
%                                   documentation for details
%   ---------
% 
%       {'reuse_viewer’ (BOOL)}: Default is 
%                           If ...
%
% -------------------------------------------------------------------------
% Outputs:
% all_data ([R x 1] CELL ARRAY OF [N x 2] UINT16 MATRIX) :
%                                   The cell array contains one cell per
%                                   trial R. Each trial is of size N_points
%                                   (as predicted by estimate_points) and
%                                   2 (two channels).
%
% parameters (timing_params Object) :
%                                   A timing params object containing the
%                                   instruction for the acquisition (number
%                                   of trials, duration etc...)
%
% stop_image_timer (timer object) :
%                                   Currently unused
%
% n_cycles(INT) :
%                                   The number of cycles expected for the
%                                   given recording duration, or the number
%                                   of cycles set in varargin.
%
% duration(FLOAT) :
%                                   In some conditions, the number of
%                                   cycles does not exactly match the
%                                   desired duration, and is rounded up.
%                                   This is the real acquisition duration
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
% Partial Revision Date:
%   24-03-2018
%
% See also: timing_params, estimate_points, DataHolder, MCViewer
%

% TODO : 
% - cleanup the timer bit

function [all_data, parameters, stop_image_timer, number_of_cycles, duration] = initialise_timed_image(controller, varargin)
    if nargin < 1 || isempty(controller)
        controller = get_existing_controller_name(true);
    end

    %% Update timing_params object based on inputs.
    parameters = timing_params(varargin);

    if isfield(parameters, 'mode') && (strcmp(parameters.mode, 'Points') || strcmp(parameters.mode, 'Functional'))
        controller.scan_params.voxels_for_ramp(:) = 1;
        %controller.scan_params.imaging_mode = ImagingMode.Pointing; QQ
        %Pointing mode definitly not working  
    end
    
    %% Preallocate memory to improve speed for timed_image()
    if ~isfield(parameters,'number_of_cycles')
        parameters.number_of_cycles = 0;
    end

    %% Estimate number of cycles
    [number_of_cycles, ~, number_of_lines, number_of_points, line_length, duration] = estimate_points(controller, parameters, ~parameters.number_of_cycles);
    all_data = cell(parameters.repeats, 1); % each repeat is stored in a seperate cell.
    for r = 1:parameters.repeats
        if controller.online       
            all_data{r} = zeros(number_of_points, 2, 'uint16');
        else
            all_data{r} = uint16(randi([0,2^16-1], number_of_points, 2)); % random integer noise
        end
    end

    %% Generate viewer at first use
    if ~parameters.reuse_viewer
        controller.viewer = DataHolder([ones(1,number_of_lines)', line_length'], number_of_cycles); % Else the viewer is just reset when you start imaging
        
        %% Just in case there was some remaining encoder stuff, delete them
        if controller.daq_fpga.capi.Session && ~isempty(controller.encoder) && isfield(controller.encoder, 'active') && controller.encoder.active && controller.encoder.trigger.use_trigger%% True, except in simulation mode
            controller.encoder.stop(); % Just in case the encoder was still running
            controller.encoder.rt_plot = false;
            force_delete(controller.encoder.filename); % Just in case there was a remaining file  
            controller.encoder.start(); % Warning : this call last > 200ms (because of the async java process)
        end
    end

    %% Check if we want a fixed timer. Otherwise we set an estimated number of repeats.
    %if strcmp(params.timer_mode,'time')
        %% Prepare timer and triggers
    %    stop_image_timer = timer('Name','Stop_scan','StartDelay', params.duration, 'TimerFcn', @(~,~)this.stop_image(false,false)); %not closing the shutter and not stopping mc
    %    n_cycles = 'fast';
    %else
        stop_image_timer = [];
   % end
   
    %% If you do MC logging, prepare MC viewer
    if parameters.monitor_MC
        controller.rig_params.bg_mc_monitoring = MCViewer(false,['timed_image_repeat_',num2str(1, '%03d')]);
    end

    %% If pause between records is short, or records are long, data is dumped on HD and processed at the end of the recording
    if ~parameters.no_interrupt && (parameters.duration > 10 || parameters.pause < 1 || parameters.repeats > 10) || parameters.dump_data
        parameters.dump_data = true;
        controller.daq_fpga.dump_data = true;
    end 
end