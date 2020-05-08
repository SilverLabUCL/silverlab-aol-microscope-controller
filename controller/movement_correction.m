%% Superclass for Controller MC function (and DaQ setup).
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
% * Prepare the Aquisition DaQ for MC (thr, n lines etc...)
%   Controller.prepare_daq_for_mc(MC_thrXY, MC_thrZ)
%
% * Send drives for MC reference. Uses Controller.mc_scan_params
%   Controller.send_mc_drives(pockel_voltages)
%
% * Prepare DAQ for MC, start tracking but not correcting
%   Controller.initialize_mc()
%
% * Initialise MC background controller tools
%   Controller.mc_background()
%
% * Switch DaQ and Controller MC off, Do not reset drives
%   Controller.stop_MC()
%
% * Pause temporarily or resume MC
%   Controller.pause_resume_MC(new_value)
%
% * Display MC metrics in a live plot or in a log file
%   Controller.start_mc_logging_or_plotting(new_plot_status)
%
% * Stop MC plotting, doesn't destroy the timer
%   [previous_timers, previous_plot_status] =
%   Controller.stop_mc_logging_or_plotting()
%
% -------------------------------------------------------------------------
% Extra Notes:
%
% * The prepare_daq_for_mc() and send_mc_drives() methods are necessary 
%   to initiate MC
%
% * More RT-3DMC functions available in utilities/movement_correction/
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
%   24-03-2018
%
% See also:

%% TODO
% move function from utilities/movement_correction/ and chage them to
% proper methods

classdef movement_correction < handle % superclass of Controller
    properties
        mc_timer_refresh_rate = 0.01; % can be slower if required
        host_channel          = 1   ; % MC host channel
        suggested_MC_ROI      = [0;0;0];
        suggested_z_ref       = NaN;  % default should be controller.xyz_stage.get_position(3); 
        suggested_thr         = 1;
    end

    methods
        function prepare_daq_for_mc(this, MC_thrXY, MC_thrZ)
            %% Prepare the Aquisition DaQ for MC (thr, n lines etc...)
            % -------------------------------------------------------------
            % Syntax:
            %   Controller.prepare_daq_for_mc(MC_thrXY, MC_thrZ)
            % -------------------------------------------------------------
            % Inputs:
            %   MC_thrXY (UINT16)
            %       The threshold to use for XY
            %   MC_thrZ (UINT16) - Optional - Default is MC_thrXY threshold
            %       The threshold to use for Z
            % -------------------------------------------------------------
            % Outputs:
            % -------------------------------------------------------------
            % Extra Notes:
            % -------------------------------------------------------------
            % Author(s):
            %   Victoria Griffiths, Antoine Valera, Geoffrey Evans
            %---------------------------------------------
            % Revision Date:
            %   18-03-2019
            %
            % See also: select_MC_Thr

            %% Set a value for MC_thrZ
            if nargin < 3
                MC_thrZ = MC_thrXY;
            end

            %% Define MC ROI parameters. You have to send this again ONLY if you want to change your mc ref.
            this.daq_fpga.safe_stop(true);              % interrupt any running scan or background MC
            this.daq_fpga.is_ready_to_correct = false;  % unless you didn't change the dwell time nor the resolution of the ref, send_mc_drives must be redone

            %% We update ROI size, so that the viewer has the right shape
            ref_res                     = this.mc_scan_params.voxels_for_ramp(1); % qq assume square ROI.
            this.daq_fpga.mc_roi_size   = [ref_res, ref_res + this.daq_fpga.Z_Lines]; % set ROI size into DaQ object

            %% Update CAPI
            this.daq_fpga.threshold_xy  = uint16(MC_thrXY);
            this.daq_fpga.threshold_z   = uint16(MC_thrZ); % may need a dark noise offset
            this.daq_fpga.Z_Lines       = ceil(this.daq_fpga.Z_Lines);
            if ~this.daq_fpga.mc_auto_relock
                ref_res = 255;
            end
            this.daq_fpga.ref_diff_x_y  = uint8(ref_res); % Can be changed later on
            this.daq_fpga.ref_diff_z    = uint8(ref_res); % Can be changed later on
            this.daq_fpga.set_move_corr_params(this.aol_params, this.mc_scan_params); %set size and dwell time for ref frame on the daqfpga
            fprintf('\t...MC SETUP : movement correction drives were sent to the DAQ\n')

            %% Set DaQ flag to ready
            this.daq_fpga.daq_mc_ready  = true;
        end

        function send_mc_drives(this, pockel_voltages)
            %% Send drives for MC reference. Uses Controller.mc_scan_params
            % You have to call this function if your reference drives
            % changes (including if you change wavelength).
            % -------------------------------------------------------------
            % Syntax:
            %   Controller.send_mc_drives(pockel_voltages)
            % -------------------------------------------------------------
            % Inputs:
            %   pockel_voltages (FLOAT) - Optional - Default is current V
            %       MC drives pockel value
            % -------------------------------------------------------------
            % Outputs:
            % -------------------------------------------------------------
            % Extra Notes:
            % -------------------------------------------------------------
            % Author(s):
            %   Victoria Griffiths, Antoine Valera, Geoffrey Evans
            %---------------------------------------------
            % Revision Date:
            %   18-03-2019
            %
            % See also: prepare_MC_miniscan, set_and_send_MC_drives

            if nargin < 2 || isempty(pockel_voltages)
                pockel_voltages     = this.pockels.on_value;
            end
            
            %% Make sure nothing is rnning
            this.daq_fpga.safe_stop(false);  %interrupt any running scan but NOT background MC

            %% Extra precaution to force you to reset DaQ side
            % If you didn't change the dwell time/resolution of the
            % ref/wavelength/pockel values of the ref, the send_mc_drives
            % would not be necessary
            this.daq_fpga.is_ready_to_correct = false; 
            this.synth_fpga.load(this.aol_params, this.mc_scan_params, true, this.mc_scan_params.mainscan_x_pixel_density, this.mc_scan_params.acceptance_angle, this.daq_fpga.z_pixel_size_um, pockel_voltages, '', ''); % send mc drives
            fprintf('\t...MC SETUP : new movement correction drives sent to the controller\n')

            %% Now we're good on the controller side
            this.daq_fpga.controller_mc_ready = true;

            %% After new drives were sent, reinitialise offset,
            %% and modify a few tags so that next time you image, MC starts
            this.initialize_mc();
        end

        function initialize_mc(this)
            %% Prepare DAQ for MC, start tracking but not correcting
            % Correction starts only when start_mc() sequence is called
            % -------------------------------------------------------------
            % Syntax:
            %   Controller.initialize_mc()
            % -------------------------------------------------------------
            % Inputs:
            %   pockel_voltages (FLOAT) - Optional - Default is current V
            %       MC drives pockel value
            % -------------------------------------------------------------
            % Outputs:
            % -------------------------------------------------------------
            % Extra Notes:
            % To start, you must have daq_fpga.controller_mc_ready == true
            % and  daq_fpga.daq_mc_ready == true, which can be set using
            % controller.send_mc_drives and controller.prepare_daq_for_mc
            %
            % Once setup, any call to get_data will start the MC (live
            % image or timed image)
            % -------------------------------------------------------------
            % Author(s):
            %   Victoria Griffiths, Antoine Valera, Geoffrey Evans
            %---------------------------------------------
            % Revision Date:
            %   18-03-2019
            %
            % See also: start_mc, send_mc_drives, prepare_daq_for_mc

            %% Enable MC tracking (control for correction itself is managed by the host_offset toggles. see this.pause_resume_MC)
            this.daq_fpga.use_movement_correction   = true;
            this.daq_fpga.use_z_movement_correction = this.daq_fpga.use_movement_correction && this.daq_fpga.Z_Lines;    
            
            %% Now check if we actually CAN use it
            if this.daq_fpga.controller_mc_ready && this.daq_fpga.daq_mc_ready
                %% Reset some controller/viewer settings
                this.daq_fpga.live_rendering_mode   = 0; % disable hostFIFO ROI rendering in blue, as not all viewer support it. You can reenable it if desired

                %% Disable any correction that could be running
                this.daq_fpga.capi.usehostoffset    = 1;
                this.daq_fpga.capi.use_host_offset_z= 1;

                %% Signal that system is ready
                this.daq_fpga.is_ready_to_correct   = true;

                fprintf('\t...MC SETUP : movement correction is ready to start\n')
            elseif this.daq_fpga.controller_mc_ready && ~this.daq_fpga.daq_mc_ready
                this.stop_MC();
                error_box('initialize_mc was called but the daq is not set up correctly', 0)
            elseif ~this.daq_fpga.controller_mc_ready && this.daq_fpga.daq_mc_ready
                this.stop_MC();
                error_box('initialize_mc was called but the controller is not set up correctly', 0)
            else
                this.stop_MC();
                error_box('initialize_mc was called but both the controller and the daq were not set up', 0)
            end
        end

        function mc_background(this)
            %% Initialise MC background controller tools
            % MC background is running automatically anyway if
            % controller.daq_fpga.capi.background_mc is true
            % -------------------------------------------------------------
            % Syntax:
            %   Controller.mc_background()
            % -------------------------------------------------------------
            % Inputs:
            % -------------------------------------------------------------
            % Outputs:
            % -------------------------------------------------------------
            % Extra Notes:
            % To start, you must have daq_fpga.controller_mc_ready == true
            % and  daq_fpga.daq_mc_ready == true, which can be set using
            % controller.send_mc_drives and controller.prepare_daq_for_mc
            %
            % Once setup, any call to get_data will start the MC (live
            % image or timed image)
            % -------------------------------------------------------------
            % Author(s):
            %   Antoine Valera, Victoria Griffiths
            %---------------------------------------------
            % Revision Date:
            %   18-03-2019
            %
            % See also: start_mc, send_mc_drives, prepare_daq_for_mc,
            %   MCViewer

            %% Stop scan, but not bkg MC
            this.daq_fpga.safe_stop(false);
            this.daq_fpga.capi.stop_background = false; %important to resume bkg MC after sending new drives

            %% Set a few tags
            this.daq_fpga.is_correcting = true;
            fprintf('\t...MC BACKGROUND : background movement correction is now running\n')
            delete(timerfind('Name','background_mc_plot'));

            %% Start logging or background MC live plot
            if (this.viewer.plot_background_mc || this.rig_params.log_bkg_mc)
                this.rig_params.bg_mc_monitoring = MCViewer(this.viewer.plot_background_mc,'bkg_MC');
                this.viewer.bg_mc_measure = timer('TimerFcn', @(src,eventdata)this.rig_params.bg_mc_monitoring.update(),'ExecutionMode','fixedRate','Period',this.mc_timer_refresh_rate,'BusyMode','queue','Name','background_mc_plot');
                start(this.viewer.bg_mc_measure);
                fprintf('\t...MC BACKGROUND : Background MC tracker generated\n')
            end
        end

        function stop_MC(this)
            %% Switch DaQ and Controller MC off, Do not reset drives
            % -------------------------------------------------------------
            % Syntax:
            %   Controller.stop_MC()
            % -------------------------------------------------------------
            % Inputs:
            % -------------------------------------------------------------
            % Outputs:
            % -------------------------------------------------------------
            % Extra Notes:
            % -------------------------------------------------------------
            % Author(s):
            %   Antoine Valera
            %---------------------------------------------
            % Revision Date:
            %   18-03-2019
            %
            % See also: MC_off, MC_reset, stop_mc_logging_or_plotting

            %% Stop any imaging as you need to restart imaging after stopping MC
            this.daq_fpga.safe_stop(true); % Interrupt any bkg MC or live image if running. Includes a FIFO_flush

            %% Switch parameters to no-MC
            this.synth_fpga.toggle_movement_correction(); % inform controller side

            %% Adjust some flags
            this.daq_fpga.controller_mc_ready       = false;
            this.daq_fpga.daq_mc_ready              = false;
            this.daq_fpga.is_ready_to_correct       = false;
            this.daq_fpga.use_movement_correction   = false;
            this.daq_fpga.use_z_movement_correction = false;
            this.daq_fpga.is_correcting             = false;

            %% Reset viewer
            this.daq_fpga.live_rendering_mode = 0;

            %% Stop anylogging or tracking
            this.stop_mc_logging_or_plotting();

            fprintf('\t\t...STOP MC : movement correction fully stopped. You must now re-send MC drives\n')
        end

        function pause_resume_MC(this, new_value)
            %% Pause temporarily or resume MC
            % -------------------------------------------------------------
            % Syntax:
            %   Controller.pause_resume_MC(new_value)
            % -------------------------------------------------------------
            % Inputs:
            %   new_value (BOOL) - Optional - Default is the opposite of
            %       the current status
            %                       If true, use MC, if false, pause MC
            % -------------------------------------------------------------
            % Outputs:
            % -------------------------------------------------------------
            % Extra Notes:
            % -------------------------------------------------------------
            % Author(s):
            %   Antoine Valera
            %---------------------------------------------
            % Revision Date:
            %   18-03-2019

            if nargin == 2
                this.daq_fpga.correct = new_value;
            end

            %% Change feedback state
            this.daq_fpga.capi.use_host_offset_z = ~this.daq_fpga.correct;
            this.daq_fpga.capi.usehostoffset = ~this.daq_fpga.correct;
            this.daq_fpga.mc_auto_relock = this.daq_fpga.correct;
        end

        function start_mc_logging_or_plotting(this, new_plot_status)
            %% Display MC metrics in a live plot or in a log file
            % -------------------------------------------------------------
            % Syntax:
            %   Controller.start_mc_logging_or_plotting(new_plot_status)
            % -------------------------------------------------------------
            % Inputs:
            %   new_plot_status (BOOL) - Optional - Default is false
            %       If true, background MC will be plotted
            % -------------------------------------------------------------
            % Outputs:
            % -------------------------------------------------------------
            % Extra Notes:
            % Plotting function relies on a timer, while logging function
            % read during acquisition only. If plotting is true, logging is
            % false.
            % -------------------------------------------------------------
            % Author(s):
            %   Antoine Valera
            %---------------------------------------------
            % Revision Date:
            %   18-03-2019
            %
            % See also: MCViewer, data_acquisition

            % QQ should logging be in a timer too?

            %% Set viewer plot_background_mc status
            if nargin < 2
                new_plot_status = false;
            end
            this.viewer.plot_background_mc = new_plot_status;

            %% Stop any running tracker. Return existing timers.
            previous_tracker = this.stop_mc_logging_or_plotting();

            %% If we want to plot/log background MC
            if this.viewer.plot_background_mc
                %% Close any MC logging function
                close(figure(1004));

                %% Create a MC plotting object
                this.rig_params.bg_mc_monitoring = MCViewer(true,'bkg_MC');

                %% If we didn't have a timer function to plot MC, make one
                if isempty(previous_tracker)
                    this.viewer.bg_mc_measure = timer('TimerFcn', @(src,eventdata)this.rig_params.bg_mc_monitoring.update(),'ExecutionMode','fixedRate','Period',this.mc_timer_refresh_rate,'BusyMode','queue','Name','background_mc_plot');
                else
                    this.viewer.bg_mc_measure = previous_tracker(1);
                end

                %% Start the plotting
                start(this.viewer.bg_mc_measure);
            elseif this.rig_params.log_live_image_mc
                %% Create a MC logging object
                this.rig_params.bg_mc_monitoring = MCViewer(this.viewer.plot_background_mc, 'live_MC');
            else
                %% Delete any preexisting object
                this.rig_params.bg_mc_monitoring = [];
            end
        end

        function [previous_timers, previous_plot_status] = stop_mc_logging_or_plotting(this)
            %% Stop MC plotting, doesn't destroy the timer
            % -------------------------------------------------------------
            % Syntax:
            %   [previous_timers, previous_plot_status] =
            %           Controller.stop_mc_logging_or_plotting()
            % -------------------------------------------------------------
            % Inputs:
            % -------------------------------------------------------------
            % Outputs:
            %   previous_timers (CELL ARRAY of Timer objects)
            %       Any existing timer object that was already doing some
            %       logging will be listed here.
            %   previous_plot_status (BOOL)
            %       If we were plotting MC, return true
            % -------------------------------------------------------------
            % Extra Notes:
            % -------------------------------------------------------------
            % Author(s):
            %   Antoine Valera
            %---------------------------------------------
            % Revision Date:
            %   18-03-2019
            %
            % See also: start_mc_logging_or_plotting

            %% Read existing objects
            previous_plot_status = this.viewer.plot_background_mc;
            previous_timers = timerfind('Name','background_mc_plot');

            %% Stop existing timers
            if ~isempty(previous_timers)
                stop(previous_timers);
            end
        end

        function set.host_channel(this, host_channel)
            %% Define the channel to use for MC
            % -------------------------------------------------------------
            % Syntax:
            %       Controller.host_channel = host_channel
            % -------------------------------------------------------------
            % Inputs:
            %   host_channel (INT)
            %       for channel 1, set to 0
            %       for channel 2, set to 1
            % -------------------------------------------------------------
            % Outputs:
            % -------------------------------------------------------------
            % Extra Notes:
            % -------------------------------------------------------------
            % Author(s):
            %   Antoine Valera
            %---------------------------------------------
            % Revision Date:
            %   13-03-2020            
            %
            % See also: preview_at_any_z, select_ROI, prepare_MC_miniscan,
            %   get_averaged_data, select_MC_thr 
            
            %% Set the value    
            if host_channel == 1
                this.host_channel = 1;
                this.daq_fpga.capi.select_ref_red = 1;
            elseif host_channel == 2
                this.host_channel = 0;
                this.daq_fpga.capi.select_ref_red = 0;
            else
                error('host channel must be 1 or 2')
            end
        end 
    end
end
