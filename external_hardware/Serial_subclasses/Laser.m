%% SerialOutput subclass for Laser objects.
%   This class will help controlling your 2p laser. It was designed to
%   control a Chameleon Device from scientifica, howver, you can probably
%   adjust the commands in each function for the device you are urrently
%   using.
%
%   Laser objects Inherits Hardware & SerialOutput objects properties.
%   The Laser oject is stored in a Laser.session field (if Laser.active is
%   set to true).
%
%   Type doc Laser.function_name or help Laser.function_name to
%   get more details about the function inputs and outputs
% -------------------------------------------------------------------------
% Syntax: 
%   this = Laser(active, port, baudrate)
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
%   this (Laser object)
% -------------------------------------------------------------------------
% Class Methods (ignoring get()/set() methods):
%
% * Get calibration Values for a given objective
%   Laser.update_laser_calibration_values(non_default_reference)
%
% * Open or Close shutter
%   Laser.shutter(open)
%       
% * Check if shutter is open or closed
%   shutter_open = Laser.get_shutter_state()
%
% * Check if the laser is still changing the wavelength
%   tuning_status = Laser.get_tuning_status()
%
% * Set a new laser wavelength
%   Laser.set_laser_wavelength(wavelength)
%
% * Read current wavelength
%   wavelength = Laser.get_laser_wavelength()
%
% * Read current laser power value
%   power = Laser.get_laser_power()
% -------------------------------------------------------------------------
% Extra Notes:
% * The object can be used independently, but in the microscope controller,
%   they are stored in Controller.laser. They are generated when the 
%   controller is created.
%
% * In the Controller setup.ini, default fields are set in 
%   "Laser.Available?", "Laser.COM port" and "Laser.Baudrate"
%
% * Laser controller functions are for a Coherent Chameleon Laser
%   Commands are sent through the COM port defined in rig_params.m.
%   More commands available in the manufacturer manual
%
% * Set command shouldn't need to wait for a response, but I set the
%   wait toggle as true to make sure commands are passed correctly.
%   Otherwise, 2 successive commands to close to each other may cancel
%   each other.
% -------------------------------------------------------------------------
% Examples:
% * Create a laser control object and change wavelength
%   laser = Laser(true, "COM4", "19200");
%   laser.set_laser_wavelength(820);
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
% See also: SerialOutput, Hardware

classdef Laser < SerialOutput
    properties
        wavelength_range        = '';
        pockel_range            = '';
        calibration_matrix      = '';
        max_power               = 1;
        non_default_reference   = '';
    end
    
    methods
        function this = Laser(active, port, BaudRate)
            %% Device specific settings
            device = 'Chameleon_Laser';
            if ~isnumeric(BaudRate)
                BaudRate = str2double(BaudRate);
            end
            Parity = 'none';
            DataBits = 8;
            StopBits = 1;
            Terminator = 'CR/LF';
            Timeout = 10;

            %% Creating the session
            this@SerialOutput(active, device, port, BaudRate, Parity, DataBits, StopBits, Terminator, Timeout)
            
            if active
                this.update_laser_calibration_values(this.non_default_reference);
            end
        end
        
        function update_laser_calibration_values(this, non_default_reference)
            %% Update laser calibration values for a given objective
            % -------------------------------------------------------------
            % Syntax: 
            %   Laser.update_laser_calibration_values(non_default_reference)
            % -------------------------------------------------------------
            % Inputs:
            %   non_default_reference(STR) : The objective to use
            % -------------------------------------------------------------
            % Outputs:
            % -------------------------------------------------------------
            % Extra Notes:
            % Under developpement
            % -------------------------------------------------------------
            % Author(s):
            %   Geoffrey Evans, Antoine Valera
            %---------------------------------------------
            % Revision Date:
            %   30-03-2020
            
            %% Laser Calibration Settings
            [C,~] = load_ini_file([],'[Laser Calibration File]');
            
            %% Read values from laser_calibration.ini file
            if nargin < 1 || isempty(non_default_reference) %then we load the default non_default_objective
                non_default_reference = ['[Reference.',read_ini_value(C,  'Current Reference'),']'];
            else
                if ~contains(non_default_reference,'[Reference.')
                    non_default_reference = ['[Reference.',non_default_reference,']'];
                end
            end
    
            %% Load values
            wlr = load(read_ini_value(C,  'Wavelength Range Name', [], non_default_reference));
            n = fieldnames(wlr);
            this.wavelength_range = wlr.(n{1});
            pr = load(read_ini_value(C,  'Pockel Range Name', [], non_default_reference));
            n = fieldnames(pr);
            this.pockel_range = pr.(n{1});
            cm = load(read_ini_value(C,  'Calibration Matrix Name', [], non_default_reference));
            n = fieldnames(cm);
            this.calibration_matrix = cm.(n{1});
            this.max_power = read_ini_value(C,  'Max Power', 1);   
            
            this.non_default_reference = non_default_reference;            
        end
        
        function shutter(this, open)
            %% Open or Close the laser shutter
            % -------------------------------------------------------------
            % Syntax: 
            %   Laser.shutter(open)
            % -------------------------------------------------------------
            % Inputs:
            %   open(BOOL) : True to open, false to close
            % -------------------------------------------------------------
            % Outputs:
            % -------------------------------------------------------------
            % Extra Notes:
            % -------------------------------------------------------------
            % Author(s):
            %   Geoffrey Evans, Antoine Valera
            %---------------------------------------------
            % Revision Date:
            %   30-03-2020

            command = ['S=',num2str(open)];
            this.send_command(command, true);
        end
       
        function shutter_open = get_shutter_state(this)
            %% Check if shutter is open or closed
            % -------------------------------------------------------------
            % Syntax: 
            %   shutter_open = Laser.get_shutter_state()
            % -------------------------------------------------------------
            % Inputs:
            % -------------------------------------------------------------
            % Outputs:
            %   shutter_open(BOOL) : True to open, false to close
            % -------------------------------------------------------------
            % Extra Notes:
            % -------------------------------------------------------------
            % Author(s):
            %   Geoffrey Evans, Antoine Valera
            %---------------------------------------------
            % Revision Date:
            %   30-03-2020
            
            command = '?S';
            shutter_open = this.send_command(command, true);
            shutter_open = any(strfind(shutter_open,'1'));
        end
        
        function tuning_status = get_tuning_status(this)
            %% Check if the laser is still changing the wavelength
            % -------------------------------------------------------------
            % Syntax: 
            %   tuning_status = Laser.get_tuning_status()
            % -------------------------------------------------------------
            % Inputs:
            % -------------------------------------------------------------
            % Outputs:
            %   tuning_status(BOOL) : 0 when tuned, other values if not
            %                         tuned (see manual)
            % -------------------------------------------------------------
            % Extra Notes:
            % -------------------------------------------------------------
            % Author(s):
            %   Antoine Valera
            %---------------------------------------------
            % Revision Date:
            %   30-03-2020
            
            command = '?TS';
            tuning_status = this.send_command(command, true);
            tuning_status = ~any(strfind(tuning_status,'0')); % 0 means tuned, can be 1,2,3. see manual
        end
        
    	function set_laser_wavelength(this, wavelength, aol_params)
            %% Set a new laser wavelength
            % -------------------------------------------------------------
            % Syntax: 
            %   Laser.get_tuning_status(wavelength, aol_params)
            % -------------------------------------------------------------
            % Inputs:
            %   wavelength(INT) : in nm, the new wavelength (eg. 920)
            %
            %	aol_params(AolParams handle) - Optional: 
            %                           if passed, the current_wavelength
            %                           propertie of AolParams is updated
            % -------------------------------------------------------------
            % Outputs:
            % -------------------------------------------------------------
            % Extra Notes:
            % -------------------------------------------------------------
            % Author(s):
            %   Antoine Valera
            %---------------------------------------------
            % Revision Date:
            %   30-03-2020
            
            command = ['VW=',num2str(wavelength)];
            this.send_command(command, true); %
            if nargin < 3
                fprintf(['You must now set aol_params.current_wavelength to  ', num2str(wavelength), 'E-9 \n']);
            else
                aol_params.current_wavelength = wavelength*1e-9;
            end
        end
        
        function wavelength = get_laser_wavelength(this)
            %% Read current wavelength
            % -------------------------------------------------------------
            % Syntax: 
            %   wavelength = Laser.get_laser_wavelength()
            % -------------------------------------------------------------
            % Inputs:
            % -------------------------------------------------------------
            % Outputs:
            %   wavelength(DOUBLE) : in nm, the current wavelength (eg. 920)
            % -------------------------------------------------------------
            % Extra Notes:
            % -------------------------------------------------------------
            % Author(s):
            %   Antoine Valera
            %---------------------------------------------
            % Revision Date:
            %   30-03-2020
            
            command = '?VW';
            wavelength = this.send_command(command, true);
            idx = strfind(wavelength,' ');
            wavelength = str2double(wavelength(idx:end));
        end

        function power = get_laser_power(this)
            %% Read current laser power value
            % -------------------------------------------------------------
            % Syntax: 
            %   power = Laser.get_laser_power()
            % -------------------------------------------------------------
            % Inputs:
            % -------------------------------------------------------------
            % Outputs:
            %   power(DOUBLE) : The current laser power
            % -------------------------------------------------------------
            % Extra Notes:
            % -------------------------------------------------------------
            % Author(s):
            %   Antoine Valera
            %---------------------------------------------
            % Revision Date:
            %   30-03-2020
            
            command = '?UF';
            power = this.send_command(command, true);
            idx = strfind(power,' ');
            power = str2double(power(idx:end));
        end
        
        function dither_hold_fix(this)
            %% Fix suggested by Coherent for removing stripes.
            % -------------------------------------------------------------
            % Syntax: 
            %   Laser.dither_hold_fix()
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
            %   30-03-2020
            
            this.send_command('?VW', true)
            this.send_command('?st', true)
            this.send_command('?PHLDP', true)
            this.send_command('PHLDP=1', true)
            this.send_command('?PHLDP', true)
            this.send_command('?UF', true)
        end
    end
end