%% SerialOutput subclass for Prechirper objects.
%   The prechirper is required to precompensate for chromatic dispersion in
%   the AOL. You have to calibrate the prechiper values for a few
%   wavelength to get optimal results on a rig.
%
%   Prechirper objects Inherits Hardware & SerialOutput objects properties.
%   The Prechirper oject is stored in a Prechirper.session field (if Prechirper.active is
%   set to true).
%
%   Type doc Prechirper.function_name or help Prechirper.function_name to
%   get more details about the function inputs and outputs
% -------------------------------------------------------------------------
% Syntax: 
%   this = Prechirper(active, port, baudrate)
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
%   this (Prechirper object)
% -------------------------------------------------------------------------
% Class Methods (ignoring get()/set() methods):
%
% * Compute prechiper position for a given wavelength
%   prism_value = Prechirper.get_prechirper_value(a, b, c, wavelength)
%       
% * Update prechirper position of a given wavelength and returns optimal
%   prism vales
%   [p1, p2] = Prechirper.update_prechirper_postion(wavelength)
%
% * Set prism value
%   success = Prechirper.set_prism_value(prism, value)
% -------------------------------------------------------------------------
% Extra Notes:
% * The object can be used independently, but in the microscope controller,
%   they are stored in Controller.prechirper. They are generated when the 
%   controller is created.
%
% * In the Controller setup.ini, default fields are set in 
%   "Prechirper.Available?", "Prechirper.COM port" and "Prechirper.Baudrate"
%
% * Prechirper controller for APE FemtoControl prechirper
%   Commands are sent through the COM port defined in rig_params.m.
%   rig-specific prechirper values (a.b.c) are stored in setup.ini
%
%   from their instruction email (16.08.2017)
%               ----------------------------
%   #Annnnnnnn (Prism 1 read)
%   #Bnnnnnnnn (Prism 1 set)
%   #Cnnnnnnnn (Prism 2 read)
%   #Dnnnnnnnn (Prism 2 set)
%   #Ennnnnnnn (wavelength read)
%   #Fnnnnnnnn (wavelength Femto set)
%   #Gnnnnnnnn (wavelength Femto and Prechirper set)
%   #Innnnnnnn (GVD curve number read)
%   #Jnnnnnnnn (GVD curve number set)
% 
%   Please consider that you have to send always 10 characters also for 
%   read operation. For reading the prism 1 position send the command 
%   “#A00000000”. For parameter setting use hexadecimal values. For setting 
%   the Femtocontrol to 800 nm send the command “#G00000320”. I hope this 
%   information help you along. Don’t hesitate to contact me for further 
%   questions. Peter Staudt 
%               ----------------------------
%
% * If you cannot send command, but the session was created without any error
%   message, make sure that ./microscope_controller/testing/ is not in the
%   Matlab path
%
% * You need to setup the values for the prechirper in Calibration.ini
%   Example of calibration curve. The max brigthness can be meaured with a
%   power meter or some imaging script. You need to find which prechirper 
%   value returns the optimal brightness for a range of wavelenghts. From 
%   there, you can get the ax2+bx+c equations for each prism. 
%   wl = [950,920,900,880,850,820,800];
%   lb = [70,245,388,470,883,1222,1476];
%   ub = [114,1370,1578,1749,1992,2300,2574];
%   max_r = [930,800,856,850,1022,1600,2000];
% -------------------------------------------------------------------------
% Examples:
% * Create a prechirper control object and change wavelength
%   p = Prechirper(true, "COM5", "115200")
%
% * Set manually the prisms to specific values
%   p.set_prism_value(1,1200);              % Set prism 1 value to 1200
%   p.set_prism_value(2,1600);              % Set prism 2 value to 1600
%
% * Set automatically the prisms for a given wavelength. This requires
%   prechirper calibration	
%   p.update_prechirper_postion(800)        % Update all values for 800nm
%
% * Delete object and close session
%   p.delete();                             % Close session and delete
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

classdef Prechirper < SerialOutput
    properties
        prism_1
        prism_2
        a1
        b1
        c1
        a2
        b2
        c2
        wlmin % Unused for now
        wlmax % Unused for now
    end
    
    methods
        function this = Prechirper(active, port, BaudRate)
            %% Device specific settings
            device = 'Prechirper';
            if ~isnumeric(BaudRate)
                BaudRate = str2double(BaudRate);
            end
            Parity = 'none';
            DataBits = 8;
            StopBits = 1;
            Terminator = '';
            Timeout = 1;
            
            %% Creating the session
            this@SerialOutput(active, device, port, BaudRate, Parity, DataBits, StopBits, Terminator, Timeout);

            %% Update rig_specific code using calibration.ini
            C = load_ini_file([],'[Calibration File]');
            this.a1 = read_ini_value(C,  'a1', 0);
            this.b1 = read_ini_value(C,  'b1', 1.33);
            this.c1 = read_ini_value(C,  'c1', 23.3);
            this.a2 = read_ini_value(C,  'a2', 0.1048);
            this.b2 = read_ini_value(C,  'b2', -190.2);
            this.c2 = read_ini_value(C,  'c2', 87090);
            this.wlmin = read_ini_value(C,  'lmin', 680);
            this.wlmax = read_ini_value(C,  'lmax', 1080);
        end

        function prism_value = get_prechirper_value(this, a, b, c, wavelength)
            %% Update laser calibration values for a given objective
            % -------------------------------------------------------------
            % Syntax: 
            %   prism_value = Prechirper.get_prechirper_value(a, b, c, wavelength)
            % -------------------------------------------------------------
            % Inputs:
            %  a(FLOAT) : a parameter of the polynomial ax2+bx+c
            %  b(FLOAT) : b parameter of the polynomial ax2+bx+c
            %  c(FLOAT) : c parameter of the polynomial ax2+bx+c
            %  wavelength(FLOAT) : in nm, the target wavelength
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
            
            prism_value = round(a*wavelength^2 + b*wavelength + c);
        end
        
        function [p1, p2] = update_prechirper_postion(this, wavelength)
            %% Update prism position - Needs refactoring
            % -------------------------------------------------------------
            % Syntax: 
            %   [p1, p2] = Prechirper.update_prechirper_postion(wavelength)
            % -------------------------------------------------------------
            % Inputs:
            %  wavelength(FLOAT) : in nm, the target wavelength
            % -------------------------------------------------------------
            % Outputs:
            %  p1(INT) : prism 1 setting value for the input wavelength
            %  p2(INT) : prism 2 setting value for the input wavelength
            % -------------------------------------------------------------
            % Extra Notes:
            % The prechirper must be in "remote control" mode for this to
            % work
            % -------------------------------------------------------------
            % Author(s):
            %   Antoine Valera
            %---------------------------------------------
            % Revision Date:
            %   30-03-2020
            
            if nargin < 1
                wavelength = 0;
            end

            this.prism_1 = this.get_prechirper_value(this.a1,this.b1,this.c1,wavelength);
            this.prism_2 = this.get_prechirper_value(this.a2,this.b2,this.c2,wavelength);
            
            p1 = this.prism_1;
            p2 = this.prism_2;
            
            %% If possible, set the prism value. When not available, the
            % Timeout delay is super long, but I couldn't dfind a way to
            % fix it
            if this.active && this.port_open
                success = this.set_prism_value(1, p1);
                if success
                    this.set_prism_value(2, p2);
                else
                    % error_box('Prechirper cannot be found. Try to reset the connection, or set "Prechirper.active = false"', 1) 
                end
            elseif this.active && ~this.port_open
                % error_box('Prechirper cannot be found. Try to reset the connection, or set "Prechirper.active = false"', 1)
            end
        end

    	function success = set_prism_value(this, prism, value)
            %% Set Prism to specific value
            % -------------------------------------------------------------
            % Syntax: 
            %   sucess = Prechirper.set_prism_value(prism, value)
            % -------------------------------------------------------------
            % Inputs:
            %  prism(INT) : prism index
            %  value(INT) : value to set to prism
            % -------------------------------------------------------------
            % Outputs:
            %  sucess(BOOL) : true if value could be set
            % -------------------------------------------------------------
            % Extra Notes:
            % The prechirper must be in "remote control" mode for this to
            % work
            % -------------------------------------------------------------
            % Author(s):
            %   Antoine Valera
            %---------------------------------------------
            % Revision Date:
            %   30-03-2020
            
            success = false;
            if ~isempty(this.session)
                %% Flush buffer
                flushinput(this.session);

                %% Prepare command
                if prism == 1
                    prism_cmd = '#B';
                elseif prism == 2
                    prism_cmd = '#D';
                end
                hexnumber = dec2hex(value,8); %32 bits hex for INT value
                command = [prism_cmd, hexnumber];

                %% Send command
                try
                    %% When Prechirper is on but not in remote mode,
                    % connection is very slow
                    fprintf(this.session, command, 'async');
                   
                    %% Read value
                    %a = fscanf(this.session,'%10c');
                    a = fread(this.session,10,'char')';

                    returned_value = num2str(hex2dec(a(3:end)));

                    %% Print result     
                    fprintf(['Prism ',num2str(prism),' set to ',returned_value,'\n']);
                    success = true;
                catch
                    if this.active
                        error_box('Prechirper connection issue. Reset the connection with the prechirper and regenerate the prechirper object', 1)
                    end
                end
            end
        end    
    end
end