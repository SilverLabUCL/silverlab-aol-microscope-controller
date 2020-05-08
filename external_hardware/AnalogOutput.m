%% Hardware subclass for creating a matlab daq session for analog outputs
%   Generic AnalogOutput class. Properties are inherited for all
%   AnalagoOutput objects
%
%   AnalogOutput objects Inherits Hardware objects properties.
%   The AO oject is stored in a AnalogOutput.session field (if 
%   AnalogOutput.active is set to true).
%
%   Type doc AnalogOutput.function_name or help AnalogOutput.function_name 
%   to get more details about the function inputs and outputs.
% -------------------------------------------------------------------------
% Syntax: 
%   this = AnalogOutput(active, device, port, min_value, max_value, 
%                       on_value, off_value)
% -------------------------------------------------------------------------
% Class Generation Inputs: 
%   active (BOOL)
%       If true, as session is created
%   device (STR)
%       The device connected to the HW. eg 'PXI1Slot4'
%   port (STR)
%       The channel connected to the HW. eg. 'ao0'
%   min_value (FLOAT)
%       The minimal possible value for the AO device
%   max_value (FLOAT)
%       The maximal possible value for the AO device
%   on_value (FLOAT)
%       The value set if you call AnalogOutput.on()
%   off_value (FLOAT)
%       The value set if you call AnalogOutput.off()
% -------------------------------------------------------------------------
% Outputs: 
%   this (AnalogOutput object)
% -------------------------------------------------------------------------
% Class Methods (ignoring get()/set() methods):
%
% * Execute Device function. Usually not used directly, but called from the
%   Parent Hardware class to pass specific values.
%   AnalogOutput.func(new_value)     
% -------------------------------------------------------------------------
% Extra Notes:
% * This object is inheriting properties and methods from hardware.
%   AnalogOut func() call is outputSingleScan
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
% See also: Hardware, HardShutter, Pmt, PockelsCell

classdef AnalogOutput < Hardware
    properties
        type    
        device  % The NI device to use
        port    % the NI port to use
    end
    
    methods
        function this = AnalogOutput(active, device, port, min_value, max_value, on_value, off_value)
            %% AnalogOutput Object Constructor. 
            % -------------------------------------------------------------
            % Syntax: 
            %   this = AnalogOutput(active, device, port, min_value,
            %                       max_value, on_value)
            % -------------------------------------------------------------
            % Inputs:
            %   active (BOOL)
            %       If true, as session is created
            %   device (STR)
            %       The device connected to the HW. eg 'PXI1Slot4'
            %   port (STR)
            %       The channel connected to the HW. eg. 'ao0'
            %   min_value (FLOAT)
            %       The minimal possible value for the AO device
            %   max_value (FLOAT)
            %       The maximal possible value for the AO device
            %   on_value (FLOAT)
            %       The value set if you call AnalogOutput.on()
            %   off_value (FLOAT)
            %       The value set if you call AnalogOutput.off()
            % -------------------------------------------------------------
            % Outputs: 
            %   this (Daq session)
            %   a valid daq session with standard AnalogOutput functions
            %   plus the specific functions defined in the corresponding
            %   subclass
            % -------------------------------------------------------------
            % Extra Notes:
            % -------------------------------------------------------------
            % Author(s):
            %   Geoffrey Evans, Boris Marin, Antoine Valera. 
            %---------------------------------------------
            % Revision Date:
            %   16-05-2018 
            
            %% Fix contraints
            if nargin < 3 || isempty(on_value)
                on_value = '';
            end
            if nargin < 3 || isempty(off_value)
                off_value = '';
            end
            this.set_HW_limits(min_value, max_value, on_value, off_value);
            
            %% Prepare session
            this.active = active;
            this.device = device;
            if ischar(port)
                port = strip(port);
            end
            this.port = port;

            %% Create session if the active flag is true
            this.session = daq.createSession('ni');
            if this.active
                this.session.addAnalogOutputChannel(this.device, this.port, 'Voltage');
            end
            
            %% Set up the ouput function handle
            this.output_fcn = @func;
            this.off();
        end

        function status = func(this, new_value)
            %% Generic output function for AnalogOutput objects
            % This function define what to do with Hardware.on() or
            % Hardware.off()
            % -------------------------------------------------------------
            % Syntax: 
            %   AnalogOutput.on()
            %   AnalogOutput.off()
            %   AnalogOutput.func(new_value)
            % -------------------------------------------------------------
            % Inputs:
            %   new_value(FLOAT)
            %       The new value for the device
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
            
            if this.active
                this.session.outputSingleScan(new_value);
            end
            status = new_value;
        end
    end
end