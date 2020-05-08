%% Hardware subclass for creating a matlab daq session for digital outputs
%   Generic DigitalOutput class. Properties are inherited for all
%   DigitalOutput objects
%
%   DigitalOutputs objects Inherits Hardware objects properties.
%   The DO oject is stored in a DigitalOutput.session field (if 
%   DigitalOutput.active is set to true).
%
%   Type doc DigitalOutput.function_name or help DigitalOutput.function_name 
%   to get more details about the function inputs and outputs.
% -------------------------------------------------------------------------
% Syntax: 
%   this = DigitalOutput(active, device, channel, min_value, max_value, 
%                        duration)
% -------------------------------------------------------------------------
% Class Generation Inputs:  
%   active (BOOL)
%       If true, as session is created
%   device (STR)
%       The device connected to the HW.
%   channel (STR)
%       The channel connected to the HW
%   min_value (FLOAT)
%       The minimal possible value for the DO device
%   max_value (FLOAT)
%       The maximal possible value for the DO device
%   duration (FLOAT)
%       The duration of a pulse if you call DigitalOutput.on().
%       Set value to Inf for a permanent change.
% -------------------------------------------------------------------------
% Outputs: 
%   this (DigitalOutput object)
% -------------------------------------------------------------------------
% Class Methods (ignoring get()/set() methods):
%
% * Execute Device function. Usually not used directly, but called from the
%   Parent Hardware class to pass specific values (typically 
%   DigitalOutput.on() or DigitalOutput.off()).
%   DigitalOutput.func(new_value)  
%
% * Add a channels to the same session if you want to fire multiple TTLs
%   DigitalOutput.add_digital_output(device, channel, name)   
% -------------------------------------------------------------
% Extra Notes:
% * This object is inheriting properties and methods from hardware.
%   DigitalOutput func() call is outputSingleScan
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
%   31-03-2020
%
% See also: Hardware, Trigger

classdef DigitalOutput < Hardware
    properties
        type = 'Generic Digital Output'
        duration % duration of pulses in seconds. Set to inf for permanent change
        channels_to_use % list of booleans matching the number of DO to use.
    end
    
    methods
        function this = DigitalOutput(active, device, channel, min_value, max_value, duration)
            %% DigitalOutput Object Constructor. 
            % -------------------------------------------------------------
            % Syntax: 
            %   this = DigitalOutput(DO_outputtype, device, channel, min_value, max_value, duration)
            % -------------------------------------------------------------
            % Inputs:
            %   device (STR)
            %       The device connected to the HW. 
            %   channel (STR)
            %       The channel connected to the HW.
            %   min_value (FLOAT)
            %       The minimal possible value for the DO device
            %   max_value (FLOAT)
            %       The maximal possible value for the DO device
            %   duration (FLOAT)
            %       The duration of a pulse if you call DigitalOutput.on().
            %       Set value to Inf for a permanenet change.
            % -------------------------------------------------------------
            % Outputs: 
            %   this (daq session)
            %       a valid daq session with standard DigitalOutput 
            %       functions plus the specific functions defined in the 
            %       corresponding subclass
            % -------------------------------------------------------------
            % Extra Notes:
            % -------------------------------------------------------------
            % Author(s):
            %   Geoffrey Evans, Boris Marin, Antoine Valera. 
            %---------------------------------------------
            % Revision Date:
            %   16-05-2018 
            
            %% No intermediate on or off values for DigitalOutputs
            off_value = min_value;
            on_value = max_value;

            %% Fix contraints
            this.set_HW_limits(min_value, max_value, on_value, off_value);
            
            %% Set pulse duration
            if nargin < 6 || isempty(duration)
                this.duration = 0.001; 
            else
                this.duration = duration;
            end
            
            %% Prepare and Create session if the active flag is true
            this.active = active;
            if this.active && ~strcmpi(device, 'hardware')
                this.session = daq.createSession('ni');
                for ch = 1:size(device,1)
                    add_digital_output(this, device(ch,:), channel(ch,:), '');
                end
            elseif strcmpi(device, 'hardware')
                this.session = 'hardware';
            end
            
            %% Set up the ouput function handle
            this.output_fcn = @func;
            this.off();
        end

        function status = func(this, ~)
            %% Generic output function for DigitalOutput objects
            %   Change the device value to that new value. The function
            %   is called with DigitalOutput.on() or DigitalOutput.off()
            %   A pulse of duration this.duration is applied. If
            %   this.duration is Inf, then the device keep the on_value
            % -------------------------------------------------------------
            % Syntax: 
            %   DigitalOutput.on()
            %   DigitalOutput.off()
            %   DigitalOutput.func(new_value)
            % -------------------------------------------------------------
            % Inputs:
            % -------------------------------------------------------------
            % Outputs: 
            %	status (BOOL)
            %       true if the value is now this.on_value, false if we 
            %       reverted it to this.off_value
            % -------------------------------------------------------------
            % Extra Notes:
            % -------------------------------------------------------------
            % Author(s):
            %   Antoine Valera, Geoffrey Evans, Boris Marin. 
            %---------------------------------------------
            % Revision Date:
            %   25-05-2018 

            %% List the channels to use (if more than one)
            if ~strcmpi(this.session, 'hardware')
                on_bool = ones(1,size(this.session.Channels,2)) .* this.channels_to_use * this.on_value;
                off_bool = ones(1,size(this.session.Channels,2)) * this.off_value; % all set to off state

                %% Change output state or do a pulse of fixed duration 
                this.session.outputSingleScan(on_bool); 
                if ~isinf(this.duration)
                    pause(this.duration);
                    this.session.outputSingleScan(off_bool);
                    this.status = 0; % we set it here because DigitalOutput.off is not called
                end
                status = this.status;
            else
                if ~isinf(this.duration)  %% Maybe this should be ignored.
                    pause(this.duration);
                end
                status = this.status;
            end 
        end
        
        function add_digital_output(this, device, channel, name)
            %% Add a digital channel to DigitalOutput.session
            % -------------------------------------------------------------
            % Syntax: 
            %   DigitalOutput.add_digital_output(device, channel, name)
            % -------------------------------------------------------------
            % Inputs:
            %   device (STR)
            %       The device connected to the HW.
            %   channel (STR)
            %       The channel connected to the HW. 
            %   channel (STR) - Optional - Default is 'NoName'
            %       The name of the channel
            % -------------------------------------------------------------
            % Outputs: 
            % -------------------------------------------------------------
            % Extra Notes:
            % -------------------------------------------------------------
            % Author(s):
            %   Antoine Valera, Geoffrey Evans, Boris Marin. 
            %---------------------------------------------
            % Revision Date:
            %   25-05-2018 
            
            if isempty(this.session) && this.active
                this.session = daq.createSession('ni');
            end
            if nargin < 4
                name = 'NoName';
            end
            
            %% Add channel
            this.session.addDigitalChannel(device, channel, 'OutputOnly');
            this.channels_to_use = [this.channels_to_use, 1];
            this.type = [this.type,{name}];
        end
    end
end