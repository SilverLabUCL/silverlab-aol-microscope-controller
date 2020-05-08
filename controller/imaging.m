%% Superclass for Controller imaging functions.
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
% * Open the shutter, set a voltage in the pockels, open the PMTs 
%   Controller.initialise() 
%
% * Close the shutter, set pockels and PMTs voltage to 0
%   Controller.finalise()
%   
% * Start live imaging acquisition by using live_scan = 1
%   Controller.live_image(read_mode, initialise) 
%
% * Stop imaging, and switch to background mc if required
%   was_scanning = 
%   Controller.stop_image(finalise, interrupt_MC_tracking)
%     
% * Capture single image or averages 
%   data = 
%   Controller.single_record(averages, reuse_viewer, averaging_method)
%
% * Display points/averaged lines during specified time
%   Controller.point_image(duration)
%
% * Scan during either a defined duration or defined number of cycles.
%   [all_data, n_cycles, wheel_time, 
%   wheel_speed, system_timescale, timings_summary, mc_log] =
%       Controller.timed_image(varargin) 
%
% * To save the currently displayed image (Processed data)
%   data = Controller.screen_capture(filename)
% -------------------------------------------------------------------------
% Extra Notes:
% * The imaging functions here are basic function that can be used in
%   a more complex arrangements. See stack_generic or get_averaged_data
%   for example
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
% See also: aol_stack, real_time_tiling

classdef imaging < handle % superclass of Controller
    properties
        frame_cycles = '';
    end

    methods   
        function initialise(this) 
            %% Open the shutter, set a voltage in the pockels, open the PMTs
            % -------------------------------------------------------------
            % Syntax: 
            %   Controller.initialise() 
            % -------------------------------------------------------------
            % Inputs:      
            % -------------------------------------------------------------
            % Outputs: 
            % -------------------------------------------------------------
            % Extra Notes:
            %   PMT control is currently disabled
            % -------------------------------------------------------------
            % Author(s):
            %   Geoffrey Evans, Boris Marin, Antoine Valera.
            %---------------------------------------------
            % Revision Date:
            %   17-02-2018
            
            this.shutter.on();
            this.pockels.on();
%             this.red_pmt.on();
%             this.green_pmt.on();
        end
        
        function finalise(this) 
            %% Close the shutter, set pockels and PMTs voltage to 0
            % -------------------------------------------------------------
            % Syntax: 
            %   Controller.finalise() 
            % -------------------------------------------------------------
            % Inputs:      
            % -------------------------------------------------------------
            % Outputs: 
            % -------------------------------------------------------------
            % Extra Notes:
            %   PMT control is currently disabled
            % -------------------------------------------------------------
            % Author(s):
            %   Geoffrey Evans, Boris Marin, Antoine Valera.
            %---------------------------------------------
            % Revision Date:
            %   17-02-2018
            
            this.daq_fpga.safe_stop(true); %stop any running scan and MC
            this.shutter.off();
            this.pockels.off();
%             this.red_pmt.off();
%             this.green_pmt.off();
        end
        
        function live_image(this, read_mode, initialise) 
            %% Start live imaging acquisition by using capi.live_scan = 1
            % -------------------------------------------------------------
            % Syntax: 
            %   Controller.live_image(read_mode, init)
            % -------------------------------------------------------------
            % Inputs: 
            %   read_mode (STR) - Optional - Default is safe - any in 
            %   ... {'safe','fast'}.
            %       Defines the type of buffer reading. 'safe' reads the
            %       buffer at each time. 'fast' uses a c pipe.
            %   initialise (BOOL) - Optional - Default is true
            %       If true, calls Controller.initialise 
            % -------------------------------------------------------------
            % Outputs: 
            % -------------------------------------------------------------
            % Extra Notes:
            % -------------------------------------------------------------
            % Author(s):
            %   Geoffrey Evans, Boris Marin, Antoine Valera.
            %---------------------------------------------
            % Revision Date:
            %   23-03-2018
           

            if nargin < 2 || isempty(read_mode)
                read_mode = 'safe';
            end  
            if nargin < 3 || isempty(initialise) || initialise
                this.initialise();
            end

            %% Plot/log mc
            this.start_mc_logging_or_plotting();

            %% Get data
            this.daq_fpga.get_data(this.viewer, this.aol_params, this.scan_params, false, read_mode);
        end  

        function was_scanning = stop_image(this, finalise, interrupt_MC_tracking)
            %% Stop imaging, and switch to background mc if required
            % -------------------------------------------------------------
            % Syntax: 
            %   was_scanning =  
            %    	Controller.stop_image(finalise, interrupt_MC_tracking)
            % -------------------------------------------------------------
            % Inputs: 
            %   finalise (BOOL) - Optional - Default is false
            %       If true, calls Controller.finalise 
            %   interrupt_MC_tracking (BOOL) - Optional - Default is false
            %       If true and if there is movement correction, the system
            %       will not automatically switch to background MC. If 
            %       finalise is true, then shutter will close, and 
            %       interrupt_MC_tracking is set to true anyway.
            % -------------------------------------------------------------
            % Outputs: 
            %   was_scanning (BOOL)
            %       Tells if the system was orginally scanning (any imaging
            %       or MC)
            % -------------------------------------------------------------
            % Extra Notes:
            % -------------------------------------------------------------
            % Author(s):
            %   Geoffrey Evans, Boris Marin, Antoine Valera.
            %---------------------------------------------
            % Revision Date:
            %   23-03-2018
            
            if nargin < 2 || isempty(finalise)
                finalise = false;
            end

            %% Adjust interrupt_MC_tracking based on inputs
            if (this.daq_fpga.use_movement_correction && finalise) || ~this.daq_fpga.use_movement_correction
                interrupt_MC_tracking = true;
            elseif nargin < 3 || isempty(interrupt_MC_tracking)
                interrupt_MC_tracking = false;
            end 

            %% Read current scanning status before stopping, so we can resume in the same mode
            was_scanning = this.daq_fpga.is_imaging;

            %% We check if we want to keep MC, providing it was initiated or running
            start_bkg_correction = (this.daq_fpga.is_correcting || this.daq_fpga.is_ready_to_correct) && this.daq_fpga.use_movement_correction && ~finalise && ~this.daq_fpga.capi.background_mc;           

            %% Stop all imaging or switch to background MC
            if ~this.daq_fpga.is_imaging  %if we click on stop and we were not scanning (with or without background MC)
                fprintf('\t\t...STOP IMAGING : Case 1 , system already stopped - nothing else to stop\n');
            elseif this.daq_fpga.capi.background_mc && ~start_bkg_correction %if we click on stop and we dont want to interrupt BGk MC if any
                fprintf('\t\t...STOP IMAGING : Case 2 , stopping imaging and not starting background MC\n');
                this.daq_fpga.safe_stop(false);
            elseif (interrupt_MC_tracking && this.daq_fpga.is_correcting) || (this.daq_fpga.is_correcting && ~start_bkg_correction) %any MC interrupt, wheteher we are in correction mode or bkg MC
                fprintf('\t\t...STOP IMAGING : Case 3 , stopping any running scan and any running (bkg) MC\n');
                this.stop_MC();
            elseif this.daq_fpga.is_imaging && ~start_bkg_correction && ~this.daq_fpga.is_correcting %if we click on stop and we were scanning (without MC) and we want no bg_MC
                fprintf('\t\t...STOP IMAGING : Case 4 , stopping any running scan. Do not start bkg MC\n');
                this.daq_fpga.safe_stop(true);
            elseif this.daq_fpga.is_imaging && start_bkg_correction && ~this.daq_fpga.is_correcting  %if we were scanning and correcting, and we want to switch to bkg MC
                fprintf('\t\t...STOP IMAGING : Case 5 , stopping scan and starting bkg MC\n');
                this.mc_background();
                finalise = false;
            elseif this.daq_fpga.is_imaging && start_bkg_correction && this.daq_fpga.is_correcting && ~this.viewer.plot_background_mc  %if we were scanning and correcting, and we want to switch to bkg MC
                fprintf('\t\t...STOP IMAGING : Case 6a , stopping scan and bkg MC should be running\n');
                this.daq_fpga.safe_stop(false);
                finalise = false;
            elseif this.daq_fpga.is_imaging && start_bkg_correction && this.daq_fpga.is_correcting && this.viewer.plot_background_mc  %if we were scanning and correcting, and we want to switch to bkg MC
                fprintf('\t\t...STOP IMAGING : Case 6b , stopping scan and displaying bkg MC plot\n');      
                this.mc_background();
                finalise = false;
            else 
                error_box('Scenario not planned', 1)
            end
            
            %% If this timer still exist, it must be deleted
            % see FIFO_initialisation.m
            delete(timerfind('Name','Start_MC'));

            %% Close shutetr and PMTs if required
            if finalise
                this.finalise()
            end 
        end

        function data = single_record(this, averages, reuse_viewer, averaging_method)
            %% Capture single image or averages 
            % -------------------------------------------------------------
            % Syntax: 
            %   data = Controller.single_record(averages, reuse_viewer, averaging_method)
            % -------------------------------------------------------------
            % Inputs: 
            %   averages (INT) - Optional - Default is 0
            %       Number of extra frames to average. use 0 for a single 
            %       frame.
            %   reuse_viewer (BOOL) - Optional - Default is false
            %       If false, a DataHolder object is created for each scan.
            %       If true, the system with reuse any preexisting one. 
            %       This will only work if the preexisting one has the
            %       exact same size.
            %   averaging_method (BOOL) - Optional - Default is 'mean', 
            %     ... any in {'mean','max','median','min','var'}
            %       Define the function to use if you acquire more than one
            %       frame.
            % -------------------------------------------------------------
            % Outputs: 
            %   data (N * M * 2 UINT16)
            %       A 2 channel output. Resolution is defined by
            %       scan_params.num_drives
            % -------------------------------------------------------------
            % Extra Notes: Use this function for screen capture, z stacks 
            %   etc...)
            % -------------------------------------------------------------
            % Author(s):
            %   Geoffrey Evans, Boris Marin, Antoine Valera.
            %---------------------------------------------
            % Revision Date:
            %   23-03-2018
            
            %TODO : enable non-square averages. Replace get_averaged_data
            %       by this method whenever possible
            
            if nargin < 2 || isempty(averages)
                averages = 0;
            end 
            if nargin < 3 || isempty(reuse_viewer)
                reuse_viewer = false;
            end 
            if nargin < 4 || isempty(averaging_method)
                averaging_method = 'mean';
            end

            %% Only fixed resolution length will work for now
            if this.scan_params.imaging_mode == ImagingMode.Pointing 
                res_x = sqrt(this.scan_params.num_drives);
                res_y = sqrt(this.scan_params.num_drives);
            else 
                res_x = unique(this.scan_params.voxels_for_ramp);
                res_y = this.scan_params.num_drives;
            end

            %% We create a data holder
            [big_data,~,~,~] = this.timed_image('recording_time_sec',0,'repeats',1,'number_of_cycles',averages+1,'pause',0,'reuse_viewer',reuse_viewer,'no_interrupt',true,'monitor_MC',false);
            
            %% We reshape and average the output using the specified method
            if ~averages
                data = cat( 3,...
                            reshape(big_data{1}(:,1),res_x, res_y, averages+1),...
                            reshape(big_data{1}(:,2),res_x, res_y, averages+1));
            else
                func = str2func(averaging_method);
                data = cat( 3,...
                            func(reshape(big_data{1}(:,1),res_x, res_y, averages+1),3),...
                            func(reshape(big_data{1}(:,2),res_x, res_y, averages+1),3));
            end
            
            
        end
        
        function point_image(this, duration)
            %% Display points/averaged lines during specified time
            % -------------------------------------------------------------
            % Syntax: 
            %   Controller.point_image(duration)
            % -------------------------------------------------------------
            % Inputs: 
            %   duration (FLOAT) - Optional - Default is 0
            %       The duration of the scan. If 0, then we have a
            %       freerunning scan.
            % -------------------------------------------------------------
            % Outputs: 
            % -------------------------------------------------------------
            % Extra Notes: 
            % -------------------------------------------------------------
            % Author(s):
            %   Antoine Valera.
            %---------------------------------------------
            % Revision Date:
            %   23-03-2018
            
            % TODO :    replace timer by n repeats
            %           support fast reading
            %           support more than 40000 points
            
            if nargin < 2 || isempty(duration)
                duration = 0;
            end
            
            %% Prepare dataholder
            this.viewer = PointsViewer(this, size(this.scan_params.start_norm, 2), duration);
            this.initialise();
            
            %% Prepare a timer if necessary.
            if duration
                fprintf(['Displaying a live ',num2str(duration),'s recording of the current drives/n'])
                start(timer('StartDelay', duration, 'TimerFcn', @(~,~)this.stop_image()));
            end
            
            %% Get data
            this.daq_fpga.get_data(this.viewer, this.aol_params, this.scan_params, 0, 'safe');%qq not tested with fast
        end
        
        function [all_data, n_cycles, encoder_data, timings_summary, mc_log] = timed_image(this, varargin) 
            %% Scan during either a defined duration or defined number of cycles.
            % -------------------------------------------------------------
            % Syntax: 
            %   [all_data, n_cycles, encoder_data, timings_summary, mc_log] 
            %          = Controller.timed_image(params, varargin) 
            % -------------------------------------------------------------
            % Inputs: 
            %   varargin(Name-Variable pairs) - Optional :
            %       Options that will be used to generate a timing_params
            %       object
            % -------------------------------------------------------------
            % Outputs: 
            %   all_data ((R x 1) CELL ARRAY of (Ch x 2) UINT16 MATRICES)
            %       The recoded resuslts, formatted in one cell R per
            %       trial. In each cell, one column per channel Ch.
            %
            %   n_cycles (INT)
            %       The number of cycles done in the scan, for all repeats
            %
            %	encoder_data (STRUCT)
            %       Contains 3 fields with default value {}.
            %       * wheel_time (N x 1 Cell Array of M x 1 FLOAT) :
            %         A cell array with one cell per trial, containing the
            %         Encoder timestamps for each point
            %       * wheel_speed (N x 1 Cell Array of M x 1 FLOAT) :
            %         A cell array with one cell per trial, containing the 
            %         Encoder speed value for each point
            %       * wheel_system_timescale (N x 1 Cell Array of M x 1 FLOAT) :
            %         A cell array with one cell per trial, containing the 
            %         System absolute time for each timepoint, as returned
            %         by the java Clock functions, written every time we
            %         read an ethernet packet
            %
            %   timings_summary(CELL ARRAY of useful stuff) :
            %       summary{1} is the real duration of each trial
            %       In some conditions, the number of cycles does not  
            %       exactly match the desired duration, and is rounded up. 
            %       This is the real acquisition duration  
            %       summary{2} is the real inter-trial pause, for each
            %       repeat. This must be added to real duration.
            %
            %   mc_log(STRUCT) :
            %       If movement correction was running, this contains the
            %       detected and corrected movement for x, y and 
            %       optionally Z   
            % -------------------------------------------------------------
            % Extra Notes: 
            %
            % See timing_params for data_acquisition control. Higher level
            %   acquisition settings can be controlled using 
            %   arboreal_params.m and the scan() function. The
            %   timing_params settings are merged with any 
            %   arboreal_params passed to the function.
            % -------------------------------------------------------------
            % Examples:
            %
            % * Get a 1 second recording of the current drives
            %   [all_data, n_cyles] = c.timed_image();
            %   n_linescans = c.scan_params.num_drives;
            %   all_data = reshape(all_data{1}, n_linescans, n_cyles, 2);
            %
            % * Get a 4 trials of 10s using the current drives
            %   [all_data, n_cyles] = c.timed_image('repeats',4,'duration',10);
            %   n_linescans = c.scan_params.num_drives;
            %   all_data = reshape(all_data{1}, n_linescans, n_cyles, 2);
            %
            % -------------------------------------------------------------
            % Author(s):
            %   Antoine Valera.
            %---------------------------------------------
            % Partial Revision Date:
            %   22-04-2019
            %
            % See also: initialise_timed_image, finalise_timed_image,
            %   push_data_to_trial_holder, timing_params, scan
            
            % TODO :- There is a hardcoded pause to stop the encoder.
            %       - Figure out why interrupts sometimes crash MC
            %       - {Maybe} add a rescue option if a scan is interrupted

            %% Preallocate memory for data holder, prepare timer
            [all_data, parameters, this.viewer.timer, this.frame_cycles, parameters.duration] = initialise_timed_image(this, varargin);


            %% Collect Data
            inter_trial_delays = zeros(1, parameters.repeats);
            for trial = 1:parameters.repeats
                if parameters.repeats > 1
                    fprintf('####### Trial %i out of %i\n',trial,parameters.repeats);
                end

                %% Adjust trial specific settings
                if trial > 1
                    inter_trial_delays(trial) = this.daq_fpga.acq_clock - parameters.duration;
                end
                
                %% Collect data
                this.daq_fpga.get_data(this.viewer, this.aol_params, this.scan_params, this.frame_cycles, 'fast', parameters.no_interrupt); %feed the dataholder while running
                intersweep_pause = tic;
                
                %% Push data to holder, or rename dumped file                
                all_data = push_data_to_trial_holder(this, all_data, trial);
                
                %% Prepare next run or finalise. pause is ignored for the last repeat
                if trial < parameters.repeats
                    %% If you do MC logging, reprepare MC viewer
                    if parameters.monitor_MC
                        this.rig_params.bg_mc_monitoring = MCViewer(false,['timed_image_repeat_',num2str(trial+1,'%03d')]);
                    end
                	pause(parameters.pause - toc(intersweep_pause))
                end                
            end

            %% Stop and format Encoder recordings
            if ~isempty(this.viewer.encoder) && this.viewer.encoder.trigger.use_trigger && ~parameters.no_interrupt
                this.viewer.encoder.stop();
                encoder_data = this.viewer.encoder.post_process();
                force_delete(this.viewer.encoder.filename);
            else
                encoder_data = struct('wheel_time',{},'wheel_speed',{},'system_timescale',{});
            end

            %% Format MC log
            if parameters.monitor_MC
                try
                    mc_log = save_MC_log('', false, false);
                catch
                    error_box('MC log backup failed. Files were renamed as *.mcbkp. You must process them and delete them manually if you want to keep them');
                    mc_log = {};
                end
            else
                mc_log = {};
            end

            %% Finalise recording. Delete temporary files
            all_data = finalise_timed_image(this, parameters, all_data);
            timings_summary = {parameters.duration, inter_trial_delays};
            n_cycles = this.frame_cycles * parameters.repeats;
        end

        function data = screen_capture(this, filename)
            %% To save the currently displayed image (Processed data)
            % -------------------------------------------------------------
            % Syntax: 
            %   Controller.screen_capture(filename)
            % -------------------------------------------------------------
            % Inputs: 
            %   filename (STR or BOOL) - Optional - Default name is a timestamp
            %       The file name or full path of the file to save. 
            %       Otherwise, we use screen_capture_DD-MMM-YYYY HH:mm:ss.tif
            %       If false, data is not saved
            % -------------------------------------------------------------
            % Outputs: 
            %   data ([X x Y x 3] UINT16 Matrix).
            %       data as display in the current viewer, including data 
            %       processing. For raw data, use controller.single_record()
            % -------------------------------------------------------------
            % Extra Notes: 
            % -------------------------------------------------------------
            % Author(s):
            %   Antoine Valera.
            %---------------------------------------------
            % Revision Date:
            %   24-03-2018
            
            if nargin < 2 || isempty(filename) || (islogical(filename) && filename)
                filename = strrep(['screen_capture_',datestr(now),'.tif'],':','_');
            end
            data = this.viewer.plt.CData;
            
            if ischar(filename)
                save_stack(im2uint16(data), filename);
                fprintf('screen capture was saved as saved as %s\n', filename);
            end
        end
        
        function quick_start(this, varargin) 
            %% Reset drives and start scanning.
            % -------------------------------------------------------------
            % Syntax: 
            %   Controller.quick_start(~)
            % -------------------------------------------------------------
            % Inputs: 
            % -------------------------------------------------------------
            % Outputs: 
            % -------------------------------------------------------------
            % Extra Notes: 
            % Helper function to start live imaging when no GUI
            % -------------------------------------------------------------
            % Author(s):
            %   Antoine Valera.
            %---------------------------------------------
            % Revision Date:
            %   24-03-2018
            
            %% Reset drives    
            this.reset_frame_and_send('raster', this.scan_params.mainscan_x_pixel_density, this.scan_params.acceptance_angle);
            
            %% Start imaging
            this.live_image('fast', true); 
        end
        
        function miniscan_image(this, miniscan_res)
            %% Help generate a Miniscan and scan it
            % -------------------------------------------------------------
            % Syntax: 
            %   Controller.miniscan_image(miniscan_res)
            % -------------------------------------------------------------
            % Inputs: 
            %   miniscan_res (INT) - Optional - Default is 40
            %       The resolution of the miniscan
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
            
            if nargin < 2 || isempty(miniscan_res)
                miniscan_res = 40;
            end
            
            %% Get frame and select ROI from it
            fprintf('ctrl-c to cancel ROI location selection...\n')
            z_um_distance = this.aol_params.convert_z_norm_to_um(this.scan_params.start_norm_raw(3));
            input_params    = {};
            input_params{1} = this.xyz_stage.get_position(3) + z_um_distance;
            input_params{2} = this.scan_params.mainscan_x_pixel_density;
            input_params{3} = this.scan_params.acceptance_angle;
            input_params{4} = this.scan_params.voxel_time; % You may wan 5e-8
            input_params{5} = this.scan_params.pockels_raw(1);
            frame = get_averaged_data(this, 4, false, true);
            ROI = select_ROI(this, '', miniscan_res, 2, uint16(cat(3,frame,zeros(size(frame,1),size(frame,2)))), input_params); % qq capture Z plane change and adjust offset

            %% Get XY plane
            rescaled_z_pixels = z_um_distance / this.aol_params.get_pixel_size; % Current Z offset
            planes = this.scan_params.generate_miniscan_boxes([ROI(2) ;ROI(1) ;rescaled_z_pixels],...
                                                              [ROI(5) ;0      ;0]                ,... %xsize
                                                              [0      ;ROI(6) ;0]                ,... %ysize
                                                              [0      ;0      ;0])               ;    %zsize                                     
            this.set_miniscans(planes, '', 0, ROI(6)); 
            
            %% Update viewer and display
            update_viewer_params_from_gui(this);
            this.initialise();this.live_image('fast')
        end

        %% Need Review
        function data_holder = continuous_scan(this, data_holder, duration) %qq prototype. Should use or be used in time image
            %% continuous raster scan, for band scan. This is simplified 
            % version of timed_image
            % The timer is created outside the loop, to minimize delay
            start(timer('Name','Stop_scan','StartDelay', duration, 'TimerFcn', @(~,~)this.stop_image(false,true))); %%replace by count
            this.daq_fpga.get_data(data_holder, this.aol_params, this.scan_params, 0, 'fast', false); % feed the dataholder while running
            delete(timerfindall('Name','Stop_scan'));
        end  
    end
end