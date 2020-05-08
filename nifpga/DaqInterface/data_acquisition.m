%% Superclass for DaqFpga imaging function.
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
% * Main data collection function.
%   DaqFpga.get_data(viewer, aol_params, scan_params, number_of_cycles, 
%   read_mode, skip_flush_and_triggers)
%
% * Set unused channels to retun 0's
%   DaqFpga.adjust_unused_channels()
%
% * Read data at every call and update viewer at every call
%   [points_read_ch1, points_read_ch2] = 
%   DaqFpga.read_and_update(viewer, fast_read) 
%
% * Collect data from FIFO or C++ Pipe
%   [points_read_ch1, points_read_ch2] = 
%   DaqFpga.get_data_from_main_channels(fast_read)
%
% * Set the imaging toggle to true
%   DaqFpga.start_imaging()
%
% * Check if a scan is running, and stop it if it is.
%   DaqFpga.safe_stop(stop_bkg_mc_if_any) 
%
% * Clean data_acqusition closure
%   DaqFpga.clean_stop(viewer, bg_mc_monitoring)  
%   
% * Set a CAPI flag about current live scan status
%   DaqFpga.update_live_can_status(status, capi_live_scan_status)
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
% See also: DaqFpga, FIFO_initialisation, update_daq_parameters, 
%   single_record, timed_image, CTargetToHostFifo

classdef data_acquisition < handle
    properties
        %% Data-related variables
        data0                       = []            ;   % First Channel data
        data1                       = []            ;   % Second Channel data
        data2                       = []            ;   % FIFO Channel data
        points_left_ch1             = 0             ;   % The (expected) number of points left in channel 1. Value is capped at uint32(2^32-1) for live image
        points_left_ch2             = 0             ;   % The (expected) number of points left in channel 2. Value is capped at uint32(2^32-1) for live image
        
        %% Acqusition System settings
        timeout                     = 1000          ;   % Delay before acqusition timeout. Can be reduced, but then you must reduce buffer size for pointing mode otherwise you will not get full frames
        stopping                    = false         ;   % If true, the system is currently stopping. The stopping flag prevents multipe calls to the stopping function
        scan_finished               = false         ;   % This indicates good completion of a scan
        skip_flush_and_triggers     = false         ;   % If true, calls to data acqusition will skip FIFO flush and Triggers setup to speed up repeated acquisition. They must be set up once in a first place
        acq_clock                   = []            ;   % tic-toc function returning the data acqusition duration
        scan_cycles                 = 10            ;   % The number of 5 ns clock cycle per pixel * 2 (used for normalizing FIFO data)
        dump_data                   = false         ;   % If true, c pipe will write collected data on a file on HD, otherwise data is held in memory   
    end
    
    methods
        function get_data(obj, viewer, aol_params, scan_params, number_of_cycles, read_mode, skip_flush_and_triggers)
            %% Main data collection function.
            % This function prepare the DaQFPGA settings, flush the FIFOs,
            % setup the triggers, start the
            % pipe, collect the data and update the viewer. Once done, it
            % sends the stop_triggers. If interrupted, it terminates
            % imaging in a clean way
            % -------------------------------------------------------------
            % Syntax: 
            %   obj.get_data(viewer, aol_params, scan_params, 
            %       number_of_cycles, read_mode, skip_flush_and_triggers)
            % -------------------------------------------------------------
            % Inputs: 
            %   viewer (Viewer object) - Optional - Default is current
            %           viewer
            %       A member of the viewer class that should have at least
            %       an .update() function. The function is called every
            %       time obj.points_to_read data were collected. Data from
            %       multiple FIFO channels are pushed into the viewer
            %       object.
            %
            %   aol_params (AolParams object) - Optional - Default is 
            %           current aol_params
            %       Some key information from AolParams will be set on the
            %       daq side. See update_daq_parameters.set_fixed_params()
            %       and update_daq_parameters.set_variable_params() for
            %       more details.
            %
            %   scan_params (ScanParams object) - Optional - Default is 
            %           current scan_params
            %       Some key information from ScanParams will be set on the
            %       daq side. The read buffer size can also be optimised 
            %       if obj.auto_optimise_buffer_size is true. See 
            %   `   update_daq_parameters.set_variable_params() and 
            %       obj.optimise_buffer_size() for more details.
            %
            %   number_of_cycles (INT) - Optional - Default is 1
            %       The number of cycles to collect. Set the value to 0 or
            %       Inf for live imaging. 
            %
            %   read_mode (STR) - Optional - Any in {'fast','safe'} -
            %           Default is 'safe'
            %       If read_mode is 'safe', FIFO is read step by step. If
            %       read_mode is 'fast', we use a an intermediate C++
            %       thread to read the FIFO. See extra notes for more
            %       details. 
            %
            %   skip_flush_and_triggers(BOOL) - Optional - Default is false
            %       If true, the system will ignore all the procedures
            %       specific to the beginning and end of trials (triggers
            %       preparation, switching to background MC, end triggers, 
            %       background MC monitoring etc...). Use this when you
            %       need to chain very quickly multiple acqusition. The
            %       data holder must be of the right size, so typically,
            %       the first call would have skip_flush_and_triggers =
            %       false, while successive one would have it true.
            %
            % -------------------------------------------------------------
            % Outputs: 
            % -------------------------------------------------------------
            % Extra Notes:
            % There are 2 methods to read the buffer, which is defined by
            % 'read_mode' 
            %   - if read_mode = 'safe' (default), the FIFO buffer is read 
            % directly using direct CAPI calls, reading obj.points_to_read
            % points every time, and data is then pushes to the viewer
            % object, which must have an .update() method.
            % Small buffers or processing-intensive functions may 
            % perturbate the acquisition, which can result in data loss.
            %   - if read_mode = 'fast', the buffer is read in an
            % independent C++ thread (see pipe.c) which is considerably 
            % faster. The c pipe running outside matlab, it has to be 
            % started and stopped properly, or matlab could crash. pipe 
            % closure is handled by the safe_stop function, but very
            % occasional crashes can still occur when normal processing is
            % interrupted.
            %
            % There is no output since data is stored in the viewer.data0
            % and viewer.data1 fields
            %
            % bg_mc_monitoring rate depends on the rate at which we 
            % read the buffer
            %
            % Examples:
            %
            % * Get one cycle of data from the current settings
            %   controller.daq_fpga.get_data();
            %   data = controller.viewer.data;
            %
            % * Start live image with current scan_params. Note that if the
            %   viewer is not shaped correctly, data con't be represented
            %   correctly either
            %   controller.daq_fpga.get_data('','','',0); 
            %
            % -------------------------------------------------------------
            % Author(s):
            %   Geoffrey Evans, Boris Marin, Antoine Valera.
            %---------------------------------------------
            % Revision Date:
            %   13-03-2019

            if nargin < 2 || isempty(viewer)
                controller                  = get_existing_controller_name(true)    ;   % Get Controller from base workspace
                viewer                      = controller.viewer                     ;   % Get current controller viewer
            end
            if nargin < 3 || isempty(aol_params)
                controller                  = get_existing_controller_name(true)    ;   % Get Controller from base workspace
                aol_params                  = controller.aol_params                 ;   % Get current controller aol_params
            end
            if nargin < 4 || isempty(scan_params)
                controller                  = get_existing_controller_name(true)    ;   % Get Controller from base workspace
                scan_params                 = controller.scan_params                ;   % Get current controller scan_params
            end

            %% Get the number of cycles. 0 or Inf for live image
            if nargin < 5 || isempty(number_of_cycles) || isinf(number_of_cycles)
                number_of_cycles            = 1                                     ;   % If undefined, get a single cycle
            end
            live_scan                       = ~number_of_cycles                     ;   % Live scan if number_of_cycles is 0

            %% Get the read_mode right
            if nargin < 6 || isempty(read_mode)
                read_mode                   = 'safe'                                ;   % If undefined, do not use C pipe
            end
            
            %% If no interrupt, we don't flush and don't send triggers
            if nargin < 7 || isempty(skip_flush_and_triggers)                           % Skip_flush_and_triggers is no_interrupt
                skip_flush_and_triggers     = false                                 ;   % If undefined, flush FIFO and setup triggers (you want to skip this step for fast chaining of repeated scans, as in Z-stacks or holograms)
            end
            obj.skip_flush_and_triggers     = skip_flush_and_triggers               ;   % Set up the skip_flush_and_triggers
            
            %% Makes sure the daq is not already acquiring
            if ~obj.skip_flush_and_triggers                                             % Ignore all trigger. no_interrupt can be called in Z stacks for example so you don't have a trigger at each plane
                obj.safe_stop(false)                                                ;   % Stop any running scan, but not MC if any
                viewer.setup_triggers()                                             ;   % Setup triggers (camera, TTL, Encoder... ) see BaseViewer
            end
            
            %% Update obj.points_to_read
            pointing                        =  scan_params.voxels_for_ramp(1) == 1 &&...
                                               all(unique(scan_params.voxels_for_ramp) == 1) ;   % Detect Pointing mode (2 steps for efficiency)
            if ~live_scan
                expected_total              = obj.optimise_buffer_size(scan_params.num_voxels, number_of_cycles, pointing)  ; % Calculate how many points to collect & optimize buffer size to get full frames
            else
                obj.optimise_buffer_size(scan_params.num_voxels, viewer.refresh_limit+1, pointing)                          ; % Just optimize buffer size to get full frames (faster)
            end
            
            %% Prepare blank data holder for the data channels we won't use
            obj.adjust_unused_channels()                                            ;   % Blank unnecessary channels

            %% Detect the type of scan and set a bool (increase efficiency later in the while loops)
            fast_read                       = strcmp(read_mode, 'fast')             ;   % Generate fast_read boolean (we don't want to use strcmp all the time leter on)
            
            %% Prepare scan, variables and MC. Start acquisition on the daq side
            bg_mc_monitoring                = obj.flush_FIFO_and_setup_triggers(aol_params, scan_params, viewer, number_of_cycles);
            
            %% Create a cleanup object
            if ~obj.skip_flush_and_triggers
                cleanupObj                  = onCleanup(@() clean_stop(obj, viewer, bg_mc_monitoring))      ; % Run on normal completion, or a forced exit, such as an error or CTRL+C
            elseif fast_read
                % Not absolutely required for ~obj.skip_flush_and_triggers. 
                % However, with fast read, is is too risky to not at least
                % stop the pipes until the c++ pipe is stable enough
                cleanupObj                  = onCleanup(@() safe_stop(obj, false))  ;   % Run on normal completion, or a forced exit, such as an error or CTRL+C
            end
            
            %% Start imaging
            obj.start_imaging()                                                     ;   % Indicate to the Acqusition DAQ to begin acqusition (and same for the triggering system) 
            
            %% In 'fast' mode, start the c pipe to read the FIFO
            if fast_read
                %% WARNING - C pipe started here - do not put any matlab breakpoints between next line and stop pipe  
                obj.capi.Channel0.start_pipes(obj.points_to_read(1), obj.timeout, obj.dump_data, obj.capi, ~skip_flush_and_triggers)
            end

            %% Collect data while live_scan, or until all points are collected
            if live_scan                                                                % Then scan is interrupted by switching live_scan to false
                obj.points_left_ch1         = uint32(2^32-1)                        ;   % will never change. Will always be > points to read
                obj.points_left_ch2         = uint32(2^32-1)                        ;   % will never change. Will always be > points to read
                fprintf('\t\t...GET DATA : live imaging started ; use a c.stop_image() callback or ctrl-c to stop\n');
                while obj.capi.live_scan && obj.capi.flag1_read || (~obj.capi.Session && obj.is_imaging)
                    %% If tracking MC, read value from CAPI and store/display
                    if ~isempty(bg_mc_monitoring)                                       % If there is a background MC tracker...
                        bg_mc_monitoring.update()                                   ;   % Update the background MC logger if any
                    end

                    %% Read FIFO until live_scan is set to false, or CTRL-C
                    obj.read_and_update(viewer, fast_read)                          ;   % Update the viewer with the new data
                end
            else                                                                        % Then scan is interrupted once all expected data is read
                obj.scan_finished           = false                                 ;   % Stays false until all points are collected
                obj.points_left_ch1         = expected_total                        ;   % Initial set-up of the number of points to collect for channel 1
                obj.points_left_ch2         = expected_total                        ;   % Initial set-up of the number of points to collect for channel 1
                
                while obj.points_left_ch1 > 0 || obj.points_left_ch2 > 0
                    %% If tracking MC, read value from CAPI and store/display
                    if ~isempty(bg_mc_monitoring)                                       % If there is a background MC tracker...
                        bg_mc_monitoring.update()                                   ;   % Update the background MC logger if any
                    end
                    
                    %% Read FIFO until all cycles are done, or CTRL-C
                    [points_read_ch1, points_read_ch2] = obj.read_and_update(viewer, fast_read);
                    obj.points_left_ch1     = obj.points_left_ch1 - points_read_ch1 ;   % Update the number of points to collect for channel 1
                    obj.points_left_ch2     = obj.points_left_ch2 - points_read_ch2 ;   % Update the number of points to collect for channel 2
                end
                
                if obj.skip_flush_and_triggers 
                    obj.update_live_can_status(false)                               ; % Prevent going into safe_start_stop if there was no interrupt
                    obj.is_imaging          = false                                 ; % Done with imaging
                end
    
                obj.scan_finished           =  ~(obj.capi.Mode == 1 || obj.capi.Mode == 2); % Prevent another pause in safe_stop and force safe_stop in Pointing_Mode
            end  
        end
        
        function adjust_unused_channels(obj)
            %% Set unused channels to retun 0's
            % -------------------------------------------------------------
            % Syntax: 
            %   obj.adjust_unused_channels()
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
            %   13-03-2019

            %% Prepare empty arrays for non-displayed channels
            if obj.live_rendering_mode == 1 % because we will only display FIFOREFHOSTFRAME so we create a black frame for channel 1 & 2
                obj.data0                   = zeros(obj.mc_roi_size(1),obj.mc_roi_size(2),'uint16'); 
                obj.data1                   = zeros(obj.mc_roi_size(1),obj.mc_roi_size(2),'uint16'); 
            end
            if obj.live_rendering_mode == 2 
                obj.data2                   = uint16(zeros(obj.mc_roi_size(1),obj.mc_roi_size(2)));
            end   
        end
               
        function [points_read_ch1, points_read_ch2] = read_and_update(obj, viewer, fast_read) 
            %% Read data at every call and update viewer at every call
            % -------------------------------------------------------------
            % Syntax: 
            %   [points_read_ch1, points_read_ch2] =
            %           DaqFpga.read_and_update(viewer, fast_read) 
            % -------------------------------------------------------------
            % Inputs: 
            %   viewer (Viewer object)
            %       A member of the viewer class that should have at least
            %       an .update() function. The function is called every
            %       time obj.points_to_read data were collected. Data from
            %       multiple FIFO channels are pushed into the viewer
            %       object. See extra notes for more details
            %
            %   fast_read (BOOL)
            %       If true, reads data on the C++ pipe instead on the FIFO
            % -------------------------------------------------------------
            % Outputs: 
            %   points_read_ch1 ([1 X N UINT16])
            %       Data from channel 0 of the FIFO. We collect
            %       obj.points_to_read points, unless there are less in the
            %       FIFO. Data is scaled by dwell time
            %
            %   points_read_ch2 ([1 X N UINT16])
            %       Data from channel 1 of the FIFO. We collect
            %       obj.points_to_read points, unless there are less in the
            %       FIFO. Data is scaled by dwell time
            % -------------------------------------------------------------
            % Extra Notes:
            %   obj.live_rendering_mode defines which channel are read and
            %   updated.
            %   - live_rendering_mode = 0 : We read channel 0 and 1
            %   - live_rendering_mode = 1 : We read MC channel
            %   - live_rendering_mode = 2 : We read channel 0 and 1 and MC
            %                               channel
            % -------------------------------------------------------------
            % Author(s):
            %   Antoine Valera, Boris Marin, Geoffrey Evans
            %---------------------------------------------
            % Revision Date:
            %   13-03-2019
            
            %% Check if we are imaging (or in simulation mode)
            ok_to_read = (obj.capi.flag1_read && obj.capi.Session) || (~obj.capi.Session && obj.is_imaging);% ~obj.capi.Session means simulation mode
            
            %% Read data and update viewer 
            if (obj.live_rendering_mode == 0 || ~obj.is_correcting) && ok_to_read 
                %% Normal mode, No FIFOREFHOSTFRAME tracking 
                [points_read_ch1, points_read_ch2]  = get_data_from_main_channels(obj, fast_read)       ;   % Get channel 1:2 data
                if ~obj.dump_data && points_read_ch1 %% QQ What about points_read_ch2 ?!!!!
                    viewer.update(obj.data0(1:points_read_ch1), obj.data1(1:points_read_ch2))           ;   % If pushing data to memory (LiveViewer of DataHolder), call the viewer update function
                end
            elseif obj.live_rendering_mode == 1 && ok_to_read
                %% Check FIFOREFHOSTFRAME only (data0 and data1 blanked), Quite slow
                [~, obj.data2, ~]                   = obj.capi.FIFOREFHOSTFRAME.read(0, prod(obj.mc_roi_size), obj.MC_rate * obj.capi.ref_framedilute, obj); % Get FIFO channel data
                if any(obj.data2(:))
                    if ~obj.dump_data && any(obj.data2)
                        viewer.update(obj.data0, obj.data1, uint16(obj.data2  * 100), obj.mc_roi_size)  ;   % Update channel 2 (obj.data0 and obj.data1 are blanked)
                    end
                else % QQ hacky solution - set small signal so we now if we are still scanning
                    obj.data0(:)                    = 150                                               ;   % Set a non-0 value 
                    obj.data1(:)                    = 150                                               ;   % Set a non-0 value 
                    viewer.update(obj.data0, obj.data1, uint16(obj.data2  * 100), obj.mc_roi_size)      ;   % Update viewer
                end
            elseif obj.live_rendering_mode == 2 && ok_to_read
                %% Check FIFOREFHOSTFRAME and data0 and data1. Very slow
                [points_read_ch1, points_read_ch2]  = get_data_from_main_channels(obj, fast_read)       ;   % Get channel 1:2 data
                [~, obj.data2, ~]                   = obj.capi.FIFOREFHOSTFRAME.read(0 , prod(obj.mc_roi_size), obj.MC_rate, obj); % Get FIFO channel data
                if ~obj.dump_data
                    viewer.update(  obj.data0(1:points_read_ch1),...
                                    obj.data1(1:points_read_ch2),...
                                    uint16(obj.data2 > 0) * 2^16, obj.mc_roi_size)                      ;   % Update all 3 channels
                end
            end
        end

        function [points_read_ch1, points_read_ch2] = get_data_from_main_channels(obj, fast_read)
            %% Collect data from FIFO or C++ Pipe
            % -------------------------------------------------------------
            % Syntax: 
            %   [points_read_ch1, points_read_ch2] = 
            %           DaqFpga.get_data_from_main_channels(fast_read)
            % -------------------------------------------------------------
            % Inputs: 
            %   fast_read (BOOL)
            %       If true, reads data on the C++ pipe instead on the FIFO
            % -------------------------------------------------------------
            % Outputs: 
            %   points_read_ch1 ([1 X N UINT16])
            %       Data from channel 0 of the FIFO. We collect
            %       obj.points_to_read points, unless there are less in the
            %       FIFO. Data is scaled by dwell time
            %
            %   points_read_ch2 ([1 X N UINT16])
            %       Data from channel 1 of the FIFO. We collect
            %       obj.points_to_read points, unless there are less in the
            %       FIFO. Data is scaled by dwell time
            % -------------------------------------------------------------
            % Extra Notes:
            %   Output signal is normalised using scan cycles (currently,
            %   one scan cycle is 5 ms) so if you increase the dwell time,
            %   the absolute intensity remains the same.
            % -------------------------------------------------------------
            % Author(s):
            %   Antoine Valera, Boris Marin, Geoffrey Evans
            %---------------------------------------------
            % Revision Date:
            %   13-03-2019
            %
            % See also: CTargetToHostFifo
            
            %% Read either what is left or the designed nb of points to read
            % uint32 may clip the value to 2^32-1 but it doesn't matter
            points_to_read                  = min(obj.points_to_read(1:2), uint32([obj.points_left_ch1, obj.points_left_ch2]));

            %% Collect data from main channels FIFO
            [~, obj.data0, points_read_ch1] = obj.capi.Channel0.read(fast_read , points_to_read(1), obj.timeout, obj);  % Read "points_to_read" data from channel 1
            [~, obj.data1, points_read_ch2] = obj.capi.Channel1.read(fast_read , points_to_read(2), obj.timeout, obj);  % Read "points_to_read" data from channel 2
            obj.data0                       = uint16(obj.data0 / (2 * obj.scan_cycles));                                % Labview-style normalization. Normalise intensity with scan time
            obj.data1                       = uint16(obj.data1 / (2 * obj.scan_cycles));                                % Labview-style normalization. Normalise intensity with scan time
        end
        
        
        function start_imaging(obj)
            %% Set the imaging toggle to true
            % Internal function. Once called, the Daq starts reading data.
            % -------------------------------------------------------------
            % Syntax: 
            %   obj.start_imaging()
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
            %   23-03-2018
            
            %% Real start signal for the DAQ - FIFO start to fill
            obj.capi.start                  = true  ;   % Start signal for DAQ. Automatically switched to back 0;
            obj.acq_clock                   = tic() ;   % Used to get an estimate of the acqusition duration
            if ~obj.skip_flush_and_triggers
                obj.capi.Experimentstart    = 1     ;   % Start signal for the Trigger system
            end
            
            %% Set the imaging flag to true
            obj.is_imaging                  = 1     ;   % Control flag  
            obj.scan_finished               = false ;   % Flag controlling the final fifo flush specifically
        end
        
        function safe_stop(obj, stop_bkg_mc_if_any) 
            %% Check if a scan is running, and stop it if it is.
            % This function should be called before any scan to prevent
            % conflicts. It is always called when exiting a get_data
            % function, whether it is after completion (In which case it is
            % called by clean_stop), or following code interruption.
            % -------------------------------------------------------------
            % Syntax: 
            %   DaqFpga.safe_stop(stop_bkg_mc_if_any) 
            % -------------------------------------------------------------
            % Inputs: 
            %   stop_bkg_mc_if_any (BOOL) - Optional - default is false
            %       If movement correction is running, stopping a scan
            %       would switch the system automatically to background MC,
            %       unless stop_bkg_mc_if_any is set to true.
            % -------------------------------------------------------------
            % Outputs: 
            % -------------------------------------------------------------
            % Extra Notes:
            % As the function is executed at normal function completion
            % too, and since mc_background can already be running at this 
            % stage (because stop_image() calls will always happen in the
            % middle of live_image execution, start background movement 
            % correction if set up, and terminate live_image execution
            % after that), there is an extra tag that explicitly say which 
            % function can stop background_mc
            % -------------------------------------------------------------
            % Author(s):
            %   Antoine Valera, Geoffrey Evans, Boris Marin.
            %---------------------------------------------
            % Revision Date:
            %   13-03-2019
            if nargin < 2
                stop_bkg_mc_if_any          = false ;   % Unless specified, background MC will keep running
            end            
            pausing                         = false ;   % No pausing unless there is something to stop
            %% Stop any current live imaging. That should trigger function interrupt
            if ~obj.stopping && (obj.capi.flag1_read || obj.capi.flag2_read) || (~obj.capi.Session && obj.is_imaging)
                obj.stopping                = true  ;   % Indicate that the stopping process has started so we don't do it twice          

                %% Set live_scan to false so we stop reading FIFO in any case
                obj.update_live_can_status(false)   ;   % Interrupt imaging on the daq side if it was still running (live imaging) 
                obj.capi.ABORTTrigloop      = 1     ;   % Make sure we stop any running trigger, step 1/2
                obj.capi.ABORTTrigloop      = 0     ;   % Make sure we stop any running trigger, step 2/2
                
                %% Stop running C Pipes if any
                try
                    obj.acq_clock       = toc(obj.acq_clock); % this will slightly underestimate acquisition time (by stop_pipe execution time)
                end
                obj.capi.Channel0.stop_pipes(obj.dump_data, obj.capi, ~obj.skip_flush_and_triggers);    % Closure for C-pipe thread
                
                obj.is_imaging              = false ;   % At this stage, all imaging system have been stopped
                pausing                     = true  ;   % We are stopping, so we want to finish the current frame -> QQ NON DETERMINISTIC
            end
    
            %% If stop_bkg_mc_if_any = true, interrupt any running background MC
            if obj.capi.background_mc && stop_bkg_mc_if_any
                fprintf('\t\t...SAFE STOP : Background MC stopping\n')
                obj.capi.stop_background    = true  ;   % If you wanted to stop background MC, this will do it
                pausing                     = true  ;   % We are stopping, so we want to finish the current frame -> QQ NON DETERMINISTIC
            end

            %% If any of the stop image or stop mc was triggered, add a delay to finish current frame
            if pausing && ~obj.scan_finished
                obj.scan_finished           = true  ; % At this stage scan is completed, imaging is stopped, except potentially a last frame
                while obj.capi.aqstate > 1            % Make sure no more data enters FIFO from the last frame (7 or 4 while still reading data)
                end
                obj.fifo_flush(); % QQ IS THIS NECESSARY?
            end
            obj.stopping                    = false ; % All done!
        end
        
        function clean_stop(obj, viewer, bg_mc_monitoring)    
            %% Clean data_acqusition closure
            % Makes sure that final triggers are always fired and that
            % bg_mc_monitoring logs are closed
            % -------------------------------------------------------------
            % Syntax: 
            %   DaqFpga.clean_stop(viewer, bg_mc_monitoring)    
            % -------------------------------------------------------------
            % Inputs: 
            %   viewer (Viewer object)
            %       A member of the viewer class where the Triggers are
            %       stored.
            %   
            %   bg_mc_monitoring (MCViewer object)
            %       The MC log object to stop at the end of the recording
            % -------------------------------------------------------------
            % Outputs: 
            % -------------------------------------------------------------
            % Extra Notes:
            % -------------------------------------------------------------
            % Author(s):
            %   Antoine Valera
            %---------------------------------------------
            % Revision Date:
            %   13-03-2019
            
            %% Send all the end-of-trial triggers
            viewer.trial_end_triggers()                             ;   
            
            %% Close background MC log (if any)
            if ~isempty(bg_mc_monitoring) %&& isfield(viewer, 'fig') && ~isempty(viewer.fig) % close file, don't stop plot
                bg_mc_monitoring.delete()                           ;   % Delete Background MC monitor
            end   
            
            %% Stop live_imaging and pipes. Keep background MC
            obj.safe_stop(false)                                    ;   
        end

        function update_live_can_status(obj, status, capi_live_scan_status)
            %% Set a CAPI flag about current live scan status
            % Write in a CAPI memory address the current status of the 
            % scan. This is to make sure that the scanning status is not
            % ambiguous. Value should be true for any running scan (live 
            % scan or number of cycles). This is required when you
            % interrupt a function for example, so that matlab doesn't try
            % to read the C pipe.
            % -------------------------------------------------------------
            % Syntax: 
            %   duration = DaqFpga.get_frame_duration()    
            % -------------------------------------------------------------
            % Inputs: 
            % -------------------------------------------------------------
            % Outputs: 
            %   duration (FLOAT)
            %       single frame duration in s
            % -------------------------------------------------------------
            % Extra Notes:
            % -------------------------------------------------------------
            % Author(s):
            %   Antoine Valera
            %---------------------------------------------
            % Revision Date:
            %   13-03-2019
            %
            % See also: flush_FIFO_and_setup_triggers

            if nargin < 3
                capi_live_scan_status   = status                    ;   % Set live_scan_status to false if you don't want live_scan to start (eg : single frame imaging)
            end
            obj.capi.live_scan          = capi_live_scan_status     ;   % Set live_scan to "status" (reading or not reading data live)
            obj.capi.flag1_write        = status                    ;   % Set flag1 to "status" (reading or not reading data)
        end
    end
end