%% DigitalOutput subclass for Trigger objects.
%   Trigger objects can be used to control external devices. You can setup
%   trigger to obtain different voltage steps or duration (including
%   constant voltage)
%
%   Trigger objects Inherits Hardware & DigitalOutput objects properties.
%   The Trigger oject is stored in a Trigger.session field (if 
%   Trigger.active is set to true).
%
%   Type doc Trigger.function_name or help Trigger.function_name to get
%   more details about the function inputs and outputs
% -------------------------------------------------------------------------
% Syntax: 
%   this = Trigger(active, device, port)
% -------------------------------------------------------------------------
% Class Generation Inputs: 
%   active (BOOL)
%       If true, as session is created
%   device (STR)
%       The device connected to the HW. 
%   port (STR)
%       The channel connected to the HW. 
% -------------------------------------------------------------------------
% Outputs: 
%   this (Trigger object)
% -------------------------------------------------------------------------
% Class Methods: 
% -------------------------------------------------------------------------
% Extra Notes:
% * The objects can be used independently, but in the microscope controller,
%   a default trigger is stored in stored in Controller.ttl_trigger. They 
%   are generated when the controller is created
%
% * In the Controller rig_params, default fields are set in 
%   "Encoder.Trigger" for the encoder trigger and
%   "Trigger.AvailableDeviceList" and "Trigger.Device1" for TTL triggers.
%
% * Because triggers need sometimes flexibility, but sometimes need to to 
%   be tighly coupled with imaging, there are 2 way to control the trigger
%   system. You can either have a software-based session control, which
%   enable you to use any DO line, but may have some software delays.
%   Alternatively, the triggering system can be controlled using the
%   backplane of the NI board. See examples section below for the 2 cases.
%
% * To know what is the name of a specific DO line, you can find more 
%   details about line names on 
%   http://zone.ni.com/reference/en-XX/help/371893D-01/6536and6537help/digital_lines/
%    -------------------------------------------------------------------
%   |Port	NI-DAQmx Physical       NI-DAQmx Physical                   |   
%   |       Channel Name (Lines)    Channel Name (Ports)*               |   
%   |-------------------------------------------------------------------|
%   |Port 0	Dev1/port0/line0        - Dev1/port0/line7	Dev1/port0      |
%   |Port 1	Dev1/port1/line0        - Dev1/port1/line7	Dev1/port1      |
%   |Port 2	Dev1/port2/line0        - Dev1/port2/line7	Dev1/port2      |
%   |Port 3	Dev1/port3/line0        - Dev1/port3/line7	Dev1/port3      |
%   |Port 4$Dev1/port4/line0        - Dev1/port4/line5	Dev1/port4      |
%   |-------------------------------------------------------------------|
%   |*This physical channel name refers to all eight lines in a port    |
%   | at once.                                                          |
%   |$Port 4 is composed of the six PFI lines. Refer to the PFI Lines   |
%   |section for more information about these lines.                    |
%    -------------------------------------------------------------------
%
% * For now, software Triggers are sent from flush_FIFO_and_setup_triggers()
%   in FIFO_initialisation.m, at the last moment before the c pipe starts.
%   However, there might be a few ms delay between that and the real start 
%   of the acqusition. 
%
% * If this delay is constant, we could correct it with a simple timing 
%   offset (not done, but possible). If you need higher precision, use the
%   hardware trigger
%
% * In the Controller rig_params, default fields are set in 
%   "DAQmx Chan.Pockels AO"
% -------------------------------------------------------------------------
% Examples:
% * Create a standalone Trigger control system
%   trigger = Trigger(true, 'PXI1Slot6','port4/line5');
%
% * Fire the trigger for 1ms
%   trigger.on();
%
% * Fire the trigger for 100ms
%   trigger.default_duration = 0.1;
%   trigger.on();
%
% * Set the Trigger on continuously, the switch if off
%   trigger.default_duration = inf;
%   trigger.on();
%   %% Do something
%   trigger.off();  
%
% * Delete session
%   pockels.delete();
%
% * Create a multiple standalone Triggers (Option 1)
%   triggers = Trigger(true, ['PXI1Slot6'  ;'PXI1Slot6']  ,...
%                            ['port4/line5';'port4/line4']);
%
%
% * Create a multiple standalone Triggers (Option 2)
%   triggers = Trigger(true, 'PXI1Slot6','port4/line5');
%   triggers.add_digital_output('PXI1Slot6','port4/line4');
%
% * Fire only the second trigger (by default all chanels are fired)
%   triggers.channet_to_use = [0, 1];
%   triggers.on();
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
%   30-03-2020
%
% See also: DigitalOutput, Hardware, rig_params

classdef Trigger < DigitalOutput
    properties
        use_trigger = 0;
        TTL_delay   = 0;
        TTL_period  = 0; % set to > 0 in s for periodic stim. This will set TTL delay to 0;
    end
    
    methods
        function this = Trigger(active, device, channel)
            %% Trigger Object Constructor. 
            % -------------------------------------------------------------
            % Syntax: 
            %   this = Trigger(active, device, channel)
            % -------------------------------------------------------------
            % Inputs:
            %   active (BOOL)
            %       If true, as session is created
            %   device (STR)
            %       The device connected to the HW. 
            %   channel (STR)
            %       The channel connected to the HW.
            % -------------------------------------------------------------
            % Outputs: 
            %   this (Trigger session)
            %   a object to control the Trigger connected to device/channel
            % -------------------------------------------------------------
            % Extra Notes:
            %   Default Trigger duration is 1ms
            % -------------------------------------------------------------
            % Author(s):
            %   Geoffrey Evans, Boris Marin, Antoine Valera. 
            %---------------------------------------------
            % Revision Date:
            %   02-06-2018 
            
            %% Device specific settings
            min_value = 0;
            max_value = 1;
            default_duration = 0.001; %1 ms
            
            %% Creating the session
            this@DigitalOutput(active, device, channel, min_value, max_value, default_duration)
            
            this.name  = 'Trigger';
        end
    end
end