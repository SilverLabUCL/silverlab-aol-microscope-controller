%% AnalogOutput subclass for HardShutter objects.
%   The hardshutter will completely block the laser output. Laser should 
%   always be blocked whe looking at the sample with your ayes, or when
%   laser reflection could reach your eyes. Device is controlled by 
%   using a 0V(open) or 5V(close) voltage.
%
%   HardShutter objects Inherits Hardware & AnalogOutput objects properties.
%   The HardShutter oject is stored in a HardShutter.session field (if
%   HardShutter.active is set to true).
%
%   Type doc HardShutter.function_name or help HardShutter.function_name to
%   get more details about the function inputs and outputs
% -------------------------------------------------------------------------
% Syntax: 
%   this = HardShutter(active, device, port)
% -------------------------------------------------------------------------
% Class Generation Inputs: 
%   active (BOOL)
%       If true, as session is created
%   device (STR)
%       The device connected to the HW. eg 'PXI1Slot4'
%   port (STR)
%       The channel connected to the HW. eg. 'ao1'
% -------------------------------------------------------------------------
% Outputs: 
%   this (HardShutter object)
% -------------------------------------------------------------------------
% Class Methods: 
% -------------------------------------------------------------------------
% Extra Notes:
%   The objects can be used independently, but in the microscope controller,
%   they are stored in Controller.shutter . They are generated when
%   the controller is created
%
%   In the Controller rig_params, default fields are set in 
%   "DAQmx Chan.Hard Shutter AO"
%
%   Please note that 'on' is 0V and 'off' is 5V
% -------------------------------------------------------------------------
% Examples:
% * Create a standalone Hard Shutter control system
%   shutter = HardShutter(true, 'PXI1Slot4', 'ao1');
%
% * Open Shutter
%   shutter.on();          
%
% * Close shutter
%   shutter.off();          
%
% * Delete session
%   shutter.delete();
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
% See also: AnalogOutput, Hardware, rig_params

classdef HardShutter < AnalogOutput & Hardware
    methods
        function this = HardShutter(active, device, port)
            %% HardShutter Object Constructor. 
            % -------------------------------------------------------------
            % Syntax: 
            %   this = HardShutter(active, device, port)
            % -------------------------------------------------------------
            % Inputs:
            %   active (BOOL)
            %       If true, as session is created
            %   device (STR)
            %       The device connected to the HW. eg 'PXI1Slot4'
            %   port (STR)
            %       The channel connected to the HW. eg. 'ao1'
            % -------------------------------------------------------------
            % Outputs: 
            %   this (HardShutter session)
            %   a object to control the HardShutter connected to device/port
            % -------------------------------------------------------------
            % Extra Notes:
            %   Min and Max values are hardcoded
            % -------------------------------------------------------------
            % Author(s):
            %   Geoffrey Evans, Boris Marin, Antoine Valera. 
            %---------------------------------------------
            % Revision Date:
            %   02-06-2018 
            
            %% Device specific settings
            min_value = 0;
            max_value = 5;
            on_value  = 0;
            off_value = 5;
            
            %% Creating the session
            this@AnalogOutput(active, device, port, min_value, max_value, on_value, off_value);
            
            %% Close shutter at startup
            this.name  = 'Hardshutter';
        end
    end
end