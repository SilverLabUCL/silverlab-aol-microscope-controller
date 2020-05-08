%% AnalogOutput subclass for Pmt objects.
%   PMT session controls the Photomutiplier gain, if the device allows
%   external control. Please see your hardware documentation for more
%   details about remote control
%
%   Pmt objects Inherits Hardware & AnalogOutput objects properties.
%   The Pmt oject is stored in a Pmt.session field (if Pmt.active is set to
%   true).
%
%   Type doc Pmt.function_name or help Pmt.function_name to get more 
%   details about the function inputs and outputs
% -------------------------------------------------------------------------
% Syntax: 
%   this = Pmt(active, device, port)
% -------------------------------------------------------------------------
% Class Generation Inputs: 
%   active (BOOL)
%       If true, as session is created
%   device (STR)
%       The device connected to the HW. eg 'PXI1Slot4'
%   port (STR)
%       The channel connected to the HW. eg. 'ao2' or 'ao3'
% -------------------------------------------------------------------------
% Outputs: 
%   this (Pmt object)
% -------------------------------------------------------------------------
% Class Methods: 
% -------------------------------------------------------------------------
% Extra Notes:
%   The objects can be used independently, but in the microscope controller,
%   they are stored in Controller.red_pmt or Controller.green_pmt. They are
%   generated when the controller is created
%
%   more scientifica info at http://www.scientifica.uk.com/customer-downloads
%
%   In the Controller rig_params, default fields are set in 
%   "DAQmx Chan.PMT AOs"
% -------------------------------------------------------------------------
% Examples:
%
% * Create a standalone PMT control system
%   pmt1 = Pmt(true, 'PXI1Slot4', 'ao2');
%
% * Set PMT gain to 1
%   pmt1.on_value = 1;   % Set target control voltage
%   pmt1.on();           % Set target
%
% * Set PMT gain 0
%   pmt1.off();          % Actually set value to off_value, whic is 0
%                        % by default
%
% * Delete session
%   pmt1.delete();
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

classdef Pmt < AnalogOutput
    methods
        function this = Pmt(active, device, port)
            %% Pmt Object Constructor. 
            % -------------------------------------------------------------
            % Syntax: 
            %   this = Pmt(active, device, port, min_value, max_value, on_value)
            % -------------------------------------------------------------
            % Inputs:
            %   active (BOOL)
            %       If true, as session is created
            %   device (STR)
            %       The device connected to the HW. eg 'PXI1Slot4'
            %   port (STR)
            %       The channel connected to the HW. eg. 'ao2' or 'ao3'
            % -------------------------------------------------------------
            % Outputs: 
            %   this (Pmt session)
            %   a object to control the Pmt connected to device/port
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
            device = 'ao2'; %or ao3
            min_value = 0;
            max_value = 1;
            on_value = 1;
            off_value = 0;
            
            %% Creating the session
            this@AnalogOutput(active, device, port, min_value, max_value, on_value, off_value);
            
            this.name  = 'PMT';
        end
    end
end