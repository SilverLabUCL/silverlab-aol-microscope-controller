%% AnalogOutput subclass for PockelsCell objects.
%   Pockel Cell controls the laser power. They are controlled by applying a
%   0-2 V voltage.
%
%   PockelsCell objects Inherits Hardware & AnalogOutput objects properties.
%   The PockelsCell oject is stored in a PockelsCell.session field (if 
%   PockelsCell.active is set to true).
%
%   Type doc PockelsCell.function_name or help PockelsCell.function_name to
%   get more details about the function inputs and outputs
% -------------------------------------------------------------------------
% Syntax: 
%   this = PockelsCell(active, device, port)
% -------------------------------------------------------------------------
% Class Generation Inputs: 
%   active (BOOL)
%       If true, as session is created
%   device (STR)
%       The device connected to the HW. eg 'PXI1Slot4'
%   port (STR)
%       The channel connected to the HW. eg. 'ao0'
% -------------------------------------------------------------------------
% Outputs: 
%   this (PockelsCell object)
% -------------------------------------------------------------------------
% Class Methods: 
% -------------------------------------------------------------------------
% Extra Notes:
%   The objects can be used independently, but in the microscope controller,
%   they are stored in Controller.pockels . They are generated when
%   the controller is created
%
%   In the Controller rig_params, default fields are set in 
%   "DAQmx Chan.Pockels AO"
% -------------------------------------------------------------------------
% Examples:
% * Create a standalone Pockel Cell control system
%   pockels = PockelsCell(true, 'PXI1Slot4', 'ao0');
%
% * Set Pockel Voltage to 0.5
%   pockels.on_value = 0.5; % Set target
%   pockels.on();           % Set target
%
% * Set Pockel Voltage to 0
%   pockels.off();          % Actually set value to off_value, whic is 0
%                           % by default
%
% * Delete session
%   pockels.delete();
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

classdef PockelsCell < AnalogOutput
    properties
        use_pockel_mod          % unused for now
    end
    
    methods
        function this = PockelsCell(active, device, port)
            %% PockelsCell Object Constructor. 
            % -------------------------------------------------------------
            % Syntax: 
            %   this = PockelsCell(active, device, port)
            % -------------------------------------------------------------
            % Inputs:
            %   active (BOOL)
            %       If true, as session is created
            %   device (STR)
            %       The device connected to the HW. eg 'PXI1Slot4'
            %   port (STR)
            %       The channel connected to the HW. eg. 'ao0'
            % -------------------------------------------------------------
            % Outputs: 
            %   this (PockelsCell session)
            %   a object to control the PockelsCell connected to device/port
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
            max_value = 2;
            on_value  = 0; % so we start at 0;
            off_value = 0;

            %% Creating the session
            this@AnalogOutput(active, device, port, min_value, max_value, on_value, off_value);

            %% Switch pockels off at startup
            this.name  = 'Pockels';
            this.use_pockel_mod = false;
        end
    end
end