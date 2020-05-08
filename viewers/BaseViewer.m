%% SuperClass for all Viewer classes. Contains Triggers-related methods
%   Creating a Base() object requires an existing controller.
%
%   Type doc function_name or help function_name to get more details about
%   the function inputs and outputs.
% -------------------------------------------------------------------------
% Syntax: 
%   this = Base()
% -------------------------------------------------------------------------
% Class Generation Inputs: 
% -------------------------------------------------------------------------
% Outputs: 
%   this (BaseViewer object)
%       The object containing a basic viewer with handles for Triggers.
% -------------------------------------------------------------------------
% Class Methods: 
%
% * Prepare all triggers where Trigger.use_trigger is true
%   BaseViewer.setup_triggers(controller)
%
% * Start all valid triggers.
%   BaseViewer.trial_start_triggers()
%
% * Stop all valid triggers.
%   BaseViewer.trial_end_triggers()
%
% * Class destructor.
%   BaseViewer.delete()
% -------------------------------------------------------------------------
% Extra Notes:
%
% * The object is usually not used on its own, although it should work to
%   trigger TTL.
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
%   16-07-2018
%
% See also
%   BaseViewer.setup_triggers, PointsViewer, LiveViewer, MCViewer,
%   DataHolder

classdef BaseViewer < handle

    properties
        timer = [];
        ttl_trigger = [];   % send a 100ms pulse
        encoder = []; % Use for the wheel speed encoder, zero times 
                      % when triggered
        bg_mc_measure = [];
        plot_background_mc = false;
        %type = 'base_viewer';
        
        ttl_timer;
        encoder_timer;
    end 
    
    methods
        function this = Base()
            %% Base Object Constructor
            % -------------------------------------------------------------
            % Syntax: 
            %   this = Base();
            % -------------------------------------------------------------
            % Inputs:      
            % -------------------------------------------------------------
            % Outputs: 
            %   this (Base object)
            %       The object containing a basic viewer with handles for
            %       Triggers.
            % -------------------------------------------------------------
            % Extra Notes:
            %   Find the controller name on its own, associate triggers  
            % with the viewer, and include all the triggers in which
            % controller.type_of_trigger.use_trigger is true.
            % -------------------------------------------------------------
            % Author(s):
            %   Antoine Valera
            %---------------------------------------------
            % Revision Date:
            %   16-07-2018
            
            %% Generate Triggers when creating viewer
            controller = get_existing_controller_name(true);
            if ~isempty(controller) && ~strcmp(this.type, 'live_image') %not live image prevent every raster reset to trigger Encoder logging
                % If there was a controller before but it was deleted,
                % and you are in the creation phase of the controller,
                % there is still a invalid handle in the 'base' workspace.
                if isvalid(controller)
                    this.setup_triggers(controller);
                end
            end
        end

        function setup_triggers(this, controller)
            %% Prepare all triggers where Trigger.use_trigger is true
            % -------------------------------------------------------------
            % Syntax: 
            %   Base.setup_triggers(controller)
            % -------------------------------------------------------------
            % Inputs:      
            %   controller (Controller object) - Optional - default finds
            %       the controller in the main workspace on its own
            % -------------------------------------------------------------
            % Outputs: 
            % -------------------------------------------------------------
            % Extra Notes:
            %   Find the controller name on its own, associate triggers with 
            % the viewer, and include all the triggers in which
            % controller.type_of_trigger.use_trigger is true
            %
            %   This should be called every time you regenerate a viewer,  
            % as the default trigger value is []. If the .use_trigger value   
            % of a trigger is true, a handle will be added to the viewer, 
            % copying the value currently in the controller.
            %
            %   The code looks for
            %   - Controller.ttl_trigger.use_trigger
            %   - Controller.encoder.trigger.use_trigger (unused here for now)
            % Then, if the Trigger is 'harware', we just toggle the right
            % capi.EnableTriggerx. Otherwise, we create attach the trigger
            % daq session that was generated when the controller was
            % created.
            % -------------------------------------------------------------
            % Author(s):
            %   Antoine Valera
            %---------------------------------------------
            % Revision Date:
            %   16-07-2018

            %% Identify Controller if not passed as an input
            if nargin < 2
                controller = get_existing_controller_name(true);
            end
            
            warning('off','daq:Session:onDemandOnlyChannelsAdded')
           
            %% Logger is created here. Time is zeroed.
            if controller.online && ~isempty(controller.encoder) && isfield(controller.encoder, 'active') && controller.encoder.active && controller.encoder.trigger.use_trigger && ~strcmpi(controller.encoder.trigger.session, 'hardware')
                this.encoder = controller.encoder;   
                this.encoder_timer = timer('StartDelay', 0, 'TimerFcn', @(~,~) start_encoder(this), 'Name', 'Start_Encoder');
            elseif controller.online && ~isempty(controller.encoder) && isfield(controller.encoder, 'active') && controller.encoder.active && strcmpi(controller.encoder.trigger.session, 'hardware')
                this.encoder = controller.encoder;  
                this.encoder_timer = [];
                controller.daq_fpga.capi.EnableTrigger4 = controller.encoder.trigger.use_trigger;
                if ~this.encoder.is_running
                    this.encoder.start();  % Encoder starts running (trials start will zero time)
                end
            end
            
            %% Set handle for TTL trigger
            if ~isempty(controller.ttl_trigger) && controller.ttl_trigger.use_trigger &&  ~strcmpi(controller.ttl_trigger.session, 'hardware')
                this.ttl_trigger = controller.ttl_trigger;
                this.ttl_timer = timer('StartDelay', this.ttl_trigger.TTL_delay, 'TimerFcn', @(~,~) start_ttl(this), 'Name', 'Start_TTL');
            elseif ~isempty(controller.ttl_trigger) && isfield(controller.ttl_trigger, 'session') && strcmpi(controller.ttl_trigger.session, 'hardware')
                this.ttl_trigger = controller.ttl_trigger;
                this.ttl_timer = [];
                live_image = strcmp(this.type, 'live_image');
                controller.daq_fpga.capi.live_scantriggersmodule = live_image; % --> Check with Vicky/Sameer ; to enable for live_scan trigger
                controller.daq_fpga.capi.PulseWidthlive80MhzCycles = round(80000000 * controller.ttl_trigger.duration); % 80000000 cycles per s
                controller.daq_fpga.capi.PulseWidthfunct80MhzCycles2 = round(80000000 * controller.ttl_trigger.duration); % 80000000 cycles per s
                controller.daq_fpga.capi.TriggerDelay80MhzCycles = 80000000 * this.ttl_trigger.TTL_delay;
                if this.ttl_trigger.TTL_period > ((2^32-1) / 80000000)
                    error('Maximum allowed period is 53.6871 s')
                end
                controller.daq_fpga.capi.useperiodicfunctional = logical(this.ttl_trigger.TTL_period) & ~logical(this.ttl_trigger.TTL_delay); % Period only if delay is false
                controller.daq_fpga.capi.TriggerPeriod80MhzCycles = round(80000000 * (this.ttl_trigger.TTL_period) * double(~logical(this.ttl_trigger.TTL_delay))); % 0 if any TTL delay. Max at 53s
                controller.daq_fpga.capi.Enablestimuluslive = live_image && controller.ttl_trigger.use_trigger;  % Airpuff TTL  / PXI_Trig4 / Trigger 5       
                controller.daq_fpga.capi.Enablestimulusfunct = controller.ttl_trigger.use_trigger; % 0 for now  / PXI_Trig4 / Trigger 5   
            end

            warning('on','daq:Session:onDemandOnlyChannelsAdded')
        end
        
        function trial_start_triggers(this)
            %% Start all valid triggers.
            % -------------------------------------------------------------
            % Syntax: 
            %   Base.trial_start_triggers()
            % -------------------------------------------------------------
            % Inputs:      
            % -------------------------------------------------------------
            % Outputs: 
            % -------------------------------------------------------------
            % Extra Notes:
            %   The function is internally called from
            % Controller.daq_fpga.flush_FIFO_and_setup_triggers() but can
            % be called externally too
            %
            % -------------------------------------------------------------
            % Author(s):
            %   Antoine Valera
            %---------------------------------------------
            % Revision Date:
            %   16-07-2018

            %% Switch TTL trigger to on. 
            % pulse duration/baheviour is controlled directly by the
            % Trigger object properties
            if ~isempty(this.ttl_timer) && ~isempty(this.ttl_trigger) && this.ttl_trigger.use_trigger
                start(this.ttl_timer);
            end
            
            %% Start Logger trigger
            if  ~isempty(this.encoder_timer) && ~isempty(this.encoder) && this.encoder.trigger.use_trigger% && ~strcmp(this.type,'live_image')
                start(this.encoder_timer);
            end

            if ~isempty(this.timer)
                start(this.timer);
            end  
        end

        function start_encoder(this)
            this.encoder.start();
            this.encoder.reset();
        end
        
        function start_ttl(this)
            this.ttl_trigger.on();
        end
        
        function trial_end_triggers(this)
            %% Stop all valid triggers.
            % -------------------------------------------------------------
            % Syntax: 
            %   Base.trial_start_triggers()
            % -------------------------------------------------------------
            % Inputs:      
            % -------------------------------------------------------------
            % Outputs: 
            % -------------------------------------------------------------
            % Extra Notes:
            % The function is internally called from the end of the
            %   acquisition loop
            % -------------------------------------------------------------
            % Author(s):
            %   Antoine Valera
            %---------------------------------------------
            % Revision Date:
            %   16-07-2018
            
            %% Reset Encoder time
            if ~isempty(this.encoder_timer) && ~isempty(this.encoder) && this.encoder.trigger.use_trigger% && ~strcmp(this.type,'live_image')
                this.encoder.reset(); % we always need a second zero to surround the recording period
                %delete(this.encoder_timer);
            end
            
            %% Delete TTL timer
            if ~isempty(this.ttl_timer) && ~isempty(this.ttl_trigger) && this.ttl_trigger.use_trigger
                %delete(this.ttl_timer);
            end
        end

        function delete(this)
            %% Class destructor. 
            % -------------------------------------------------------------
            % Syntax: 
            %   Base.delete()
            % -------------------------------------------------------------
            % Inputs:
            % -------------------------------------------------------------
            % Outputs: 
            % -------------------------------------------------------------
            % Extra Notes:
            %   This will also stop the encoder
            % -------------------------------------------------------------
            % Author(s):
            %   Antoine Valera
            %---------------------------------------------
            % Revision Date:
            %   16-07-2018
            
            %% Stop Encoder
            if ~isempty(this.encoder) && isfield(this.encoder.trigger,'stop')
                this.encoder.stop();
            end           
        end
    end
end
