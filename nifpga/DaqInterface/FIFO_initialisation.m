%% Superclass for DaqFpga FIFO configuration
% DaqFpga class inherits these methods and properties
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
% * Get the optimal buffer size to read the data.
%   DaqFpga.expected_total = 
%   optimise_buffer_size(num_voxels, number_of_cycles)
%
% * Empty FIFO before any new imaging, and prepare triggers.
%   bg_mc_monitoring = 
%   DaqFpga.flush_FIFO_and_setup_triggers(aol_params, scan_params, viewer,
%   number_of_cycles)
%
% * Flush FIFO and set Daq Fixed and variable settings 
%   DaqFpga.prepare_daq_for_scan(aol_params, scan_params, number_of_cycles)
%
% * Empty FIFO if there is any remaining data
%   DaqFpga.fifo_flush()
%
% * Check how much data there is in the FIFOs
%   DaqFpga.available = poll_fifos()
% 
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
%   16-03-2019
%
% See also: DaqFpga, data_acquisition, update_daq_parameters, 
%   single_record, timed_image


classdef FIFO_initialisation < handle
    properties
        MC_start_delay_s            = 0.1           ;   % Delay to send the start MC - QQ 
        points_to_read              = [0, 0, 0]     ;   % Number of points to read each time, for channel 0, 1 and Host
        buffer_min                  = 2048          ;   % The lower bound for the FIFO-read buffer (both for regular and c-pipe read)
        buffer_max                  = 2^15          ;   % The lower bound for the FIFO-read buffer (both for regular and c-pipe read)
                                                        % --> values > 40000 break pointing mode, and values over 2^17-1 break imaging
        auto_optimise_buffer_size   = true          ;   % If true, the buffer is adjusted to the combination of divisor the closest to buffer_max, and above buffer min
    end
    
    methods
        function expected_total = optimise_buffer_size(obj, num_voxels, number_of_cycles, pointing)
            %% Get the optimal buffer size to read the data.
            % Buffer size is set to some pseudo-optimal values between
            % obj.buffer_min and obj.buffer_max. 
            % -------------------------------------------------------------
            % Syntax: 
            %   expected_total =
            %       DaqFpga.optimise_buffer_size(num_voxels, number_of_cycles)
            % -------------------------------------------------------------
            % Inputs: 
            %   num_voxels (INT)
            %       The number of voxels in a single frame
            %   
            %   number_of_cycles (INT)
            %       The number of scan cycle
            % -------------------------------------------------------------
            % Outputs: 
            % -------------------------------------------------------------
            % Extra Notes:
            % Small buffers make more regular calls to viewer.update. This
            % can cause data loss or c pipe crashes if the viewer cannot
            % keep up. Large buffer size are safer but cause less buffer
            % updates.
            % For live viewing optimisation, if the buffer size is a
            % divisor of the frame size, it will make the processing
            % easier. This is not mandatory but it can help.
            % set daq_fpga.auto_optimise_buffer_size to true to set the
            % buffer size to a divisor of the frame size.
            %
            % WARNING : When using C pipe, there is definitely a max value
            % above which one the system crashes. This should be solved at
            % one point
            %
            % Some more benchmarking is necessary
            % -------------------------------------------------------------
            % Author(s):
            %   Antoine Valera
            %---------------------------------------------
            % Revision Date:
            %   13-03-2019

            %% Get the total number of points
            expected_total                      = num_voxels * number_of_cycles         ;       % Total points to read
            
            if pointing % QQ Pointing mode doesn't handle well big buffer size (NI error -50400). a buffer of ~20000 seems to work
                best_factor_comb                = ceil(obj.buffer_max/2)                ;       % Set buffer somewhere nead 16000 ; QQ - NON DETERMINISTIC
            else
                %% If true, find the largest valid divisor for a frame size
                if obj.auto_optimise_buffer_size && ~obj.skip_flush_and_triggers                % When doing skip_flush_and_triggers, we don't want to waste time on that function
                    %% Get largest divisor below buffer_max
                    candidates                  = divisors(expected_total)              ;       % Find factors that would allow to finish frames
                    best_factor_comb            = (candidates - obj.buffer_max)         ;       % Find the first divisor smaller than buffer max 1/2
                    best_factor_comb            = max(candidates(best_factor_comb <= 0));       % Find the first divisor smaller than buffer max 2/2
                else
                    best_factor_comb            = obj.buffer_max                        ;       % Without optimization, just use buffer max                 
                end

                %% Get the buffer size (> min size, < max size, except if the  
                best_factor_comb = max(obj.buffer_min, min(best_factor_comb, expected_total));  % Number of points to read is between buffer_min and buffer_max)
            end
            obj.points_to_read = uint32([best_factor_comb, best_factor_comb])           ;       % set points to read for each channel; QQ small FOV seem to crash the code
        end
        
        function bg_mc_monitoring = flush_FIFO_and_setup_triggers(obj, aol_params, scan_params, viewer, number_of_cycles)
            %% Empty FIFO before any new imaging, and prepare triggers.
            % Call that function before any scan, to clear any remaining 
            % data in the buffer, prepare daq, start MC, fire triggers
            % -------------------------------------------------------------
            % Syntax: 
            %   bg_mc_monitoring = 
            %       obj.flush_FIFO_and_setup_triggers(aol_params, 
            %       scan_params, viewer, number_of_cycles, use_live_scan)
            % -------------------------------------------------------------
            % Inputs: 
            %   aol_params (AolParams object)
            %       Some key information from AolParams will be set on the
            %       daq side. See update_daq_parameters.set_fixed_params()
            %       and update_daq_parameters.set_variable_params() for
            %       more details.
            %
            %   scan_params (ScanParams object)
            %       Some key information from ScanParams will be set on the
            %       daq side. The read buffer size can also be optimised 
            %       if obj.auto_optimise_buffer_size is true. See 
            %   `   update_daq_parameters.set_variable_params() and 
            %       obj.optimise_buffer_size() for more details.
            %
            %   viewer (Viewer object)
            %       A member of the viewer class that should have at least
            %       an .update() function. The function is called every
            %       time obj.points_to_read data were collected. Data from
            %       multiple FIFO channels are pushed into the viewer
            %       object.
            %
            %   number_of_cycles (INT)
            %       The number of cycles to collect. Set the value to 0 for
            %       live imaging. 
            % -------------------------------------------------------------
            % Outputs: 
            %   bg_mc_monitoring (MCViewer handle OR [])
            %       if we are logging background MC, we return a hanlde to
            %       the object located in Controller.rig_params.bg_mc_monitoring
            % -------------------------------------------------------------
            % Extra Notes: 
            % -------------------------------------------------------------
            % Author(s):
            %   Geoffrey Evans, Boris Marin, Antoine Valera.
            %---------------------------------------------
            % Revision Date:
            %   23-03-2018

            %% Clear any data left in the current viewer.
            viewer.reset()                              ;                   % Clear any remaining data in the viewer           
            
            %% Adjust live_scan mode. True for open-ended live scan. False when repeats is set.
            obj.update_live_can_status(true, ~number_of_cycles);            % Update status file to True (= imaging). Live scan boolean is true only if number_of_cycles == 0
            
            %% Flush FIFO and update DAQ with drives - can be skipped during stacks (except first plane)
            obj.prepare_daq_for_scan(aol_params, scan_params, number_of_cycles);
            
            %% Unless skip_flush_and_triggers is true (eg. Z stacks), prepare MC and triggers 
            if ~obj.skip_flush_and_triggers                
                %% Start MC, with a 100ms delay so that it happens while imaging
                start(timer('StartDelay', obj.MC_start_delay_s, 'TimerFcn', @obj.start_mc, 'Name', 'Start_MC')) ; % QQ I DO NOT LIKE THIS APPROACH --> Maybe use aqstate or soemthing like that instead?, a bit later on
                
                %% If a MC tracker exists, get it here
                bg_mc_monitoring                = evalin('base',[get_existing_controller_name(),'.rig_params.bg_mc_monitoring']);
                
                %% Setup General trigger settings
                obj.setup_general_hardware_triggers()   ;                   % Set up triggers for functional and live imaging
                
                %% Fire any session based trigger/timer set up in the viewer
                viewer.trial_start_triggers()           ;                   % This is as close from acquisition start as it can get. Probably less than a ms

                obj.acq_clock = tic();                
            else
                bg_mc_monitoring                = []    ;                   % Clear MC monitoring object 
                obj.capi.EnableTrigger1         = 0     ;                   % Disable "Encoder trigger/line trigger" (PXI_Trig2)
                obj.capi.EnableTrigger4         = 0     ;                   % Disable "Start of exp" trigger (PXI_Trig4)
                obj.capi.Enablestimulusfunct    = 0     ;                   % Disable trigger for function acquisition
                obj.capi.Enablestimuluslive     = 0     ;                   % Disable trigger for live image
                % Frame trigger (EnableTrigger2 ; PXI_Trig2) and Trial
                % trigger (EnableTrigger3 ; PXI_Trig3) unaffected??
            end
        end
        
        function prepare_daq_for_scan(obj, aol_params, scan_params, number_of_cycles)
            %% Flush FIFO and set Daq Fixed and variable settings 
            % (resolution, dwell time etc...). This is an Internal function
            % -------------------------------------------------------------
            % Syntax: 
            %   obj.prepare_daq_for_scan(aol_params, scan_params, number_of_cycles)
            % -------------------------------------------------------------
            % Inputs: 
            %   aol_params (AolParams object)
            %       Some key information from AolParams will be set on the
            %       daq side. See update_daq_parameters.set_fixed_params()
            %       and update_daq_parameters.set_variable_params() for
            %       more details.
            %
            %   scan_params (ScanParams object)
            %       Some key information from ScanParams will be set on the
            %       daq side. The read buffer size can also be optimised 
            %       if obj.auto_optimise_buffer_size is true. See 
            %   `   update_daq_parameters.set_variable_params() and 
            %       obj.optimise_buffer_size() for more details.
            %
            %   number_of_cycles (INT)
            %       The number of cycles to collect. If we are in live
            %       image mode, number_of_cycles is ignored
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
            
            obj.fifo_flush()                                                    ;   % Make Sure there is no data left in FIFO
            obj.set_fixed_params(aol_params)                                    ;   % Set DaQ params for HW
            obj.set_variable_params(scan_params, aol_params, number_of_cycles)  ;   % Set DaQ params for scan
            obj.poll_fifos()                                                    ;   % QQ WHY WOULD WE DO THAT???
        end
        
        function fifo_flush(obj)
            %% Empty FIFO if there is any remaining data
            % Call that function before any scan, to clear any remaining 
            % data in the buffer, prepare daq, start MC, fire triggers
            % -------------------------------------------------------------
            % Syntax: 
            %   obj.fifo_flush()
            % -------------------------------------------------------------
            % Inputs: 
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
            
            available = obj.poll_fifos()                                    ;   % Check how much data available per channel
            while any(available)                
                obj.capi.Channel0.read(0 , available(1), obj.timeout, obj)  ;   % Read as many data in Channel 1 as possible (and discard)
                obj.capi.Channel1.read(0 , available(2), obj.timeout, obj)  ;   % Read as many data in Channel 2 as possible (and discard)
                obj.capi.FIFOREFHOSTFRAME.read(0 , available(3), 5, obj)    ;   % Read as many data in HOST Channel as possible (and discard)
                available               = obj.poll_fifos()                  ;   % Update number of available data left
            end  
        end
       
        function available = poll_fifos(obj)
            %% Check how much data there is in the FIFOs
            % -------------------------------------------------------------
            % Syntax: 
            %   available = obj.poll_fifos()
            % -------------------------------------------------------------
            % Inputs: 
            % -------------------------------------------------------------
            % Outputs: 
            %   available (1 X 3 INT)
            %       The number of points in each FIFO (channel0, Channel1
            %       and MC FIFO)
            % -------------------------------------------------------------
            % Extra Notes: 
            % -------------------------------------------------------------
            % Author(s):
            %   Geoffrey Evans, Boris Marin, Antoine Valera.
            %---------------------------------------------
            % Revision Date:
            %   23-03-2018

            available                   = [0, 0, 0]                                                 ;   % Channel1 is index 1 and Channel0 is index 2. FIFOREFHOSTFRAME for MC 
            [~, ~, available(1)]        = obj.capi.Channel0.read(0 , 0, obj.timeout, obj)           ;   % Check how much data available in Channel 1 FIFO
            [~, ~, available(2)]        = obj.capi.Channel1.read(0 , 0, obj.timeout, obj)           ;   % Check how much data available in Channel 2 FIFO  
            [~, ~, available(3)]        = obj.capi.FIFOREFHOSTFRAME.read(0 , 0, obj.timeout, obj)   ;   % Check how much data available in HOST FIFO
        end
    end
end