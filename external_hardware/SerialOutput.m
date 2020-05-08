%% Hardware subclass for creating a matlab daq session for serial outputs
%   SerialOutput objects Inherits Hardware objects properties.
%   The serial oject is stored in a SerialOutput.session field (if 
%   SerialOutput.active is set to true).
%
%   Type doc SerialOutput.function_name or help SerialOutput.function_name 
%   to get more details about the function inputs and outputs.
% -------------------------------------------------------------------------
% Syntax: 
%   this = SerialOutput(active, device, port, BaudRate, Parity, DataBits,
%                       StopBits, Terminator, Timeout, ByteOrder)
% -------------------------------------------------------------------------
% Class Generation Inputs:  
%   active (BOOL)
%       If true, the serial object is created. Contrary to NI AO or DO
%       object, there must really be some Hardware for this to work
%   device (STR)
%       The device connected to the HW. eg 'PXI1Slot4'
%   port (STR)
%       The port connected to the HW. eg. 'COM6'
%   BaudRate (INT or STR) - Optional - Default is 9600
%       Rate at which bits are transitted
%   Parity {'none', 'odd', 'even', 'mark', 'space'} - Optional - Default is
%           'none'
%       Type of parity checking
%   DataBits (INT) - Optional - Default is 8
%       number of data bits to transmit
%   StopBits {1, 1.5, 2} - Optional - Default is 1
%       Number of bits used to indicate the end of a byte
%   Terminator (STR) - Optional - Default is ''
%       Terminator character
%   Timeout (FLOAT) - Optional - Default is 0
%       Time before aborting call
%   ByteOrder {'littleEndian','bigEndian'} - Optional - Default is
%               'littleEndian'
%       Byte order of the device
% -------------------------------------------------------------------------
% Outputs: 
%   this (SerialOutput object)
% -------------------------------------------------------------------------
% Class Methods (ignoring get()/set() methods):
%
% * Send the command to the serial object. If the first symbol of the
%   command matches SerialOutput.wait_for_response_symbol, then the
%   code will wait for the SerialOutput to return a response.
%   SerialOutput.func(command)
%
% * Send a command and attach SerialOutput.wait_for_response_symbol if
%   wait_for_response is true
%   SerialOutput.send_command(command, wait_for_response) 
% -------------------------------------------------------------
% Extra Notes:
% * This object is inheriting properties and methods from hardware.
%   SerialOutput func() call is fprintf on the serial session.
%
% * If you wait for a response fro the serial object, you need to specifcy 
%   SerialOutput.wait_for_response_symbol. Type help 
%   SerialOutput.send_command for more info about wait_for_response 
%   behaviour.
% -------------------------------------------------------------------------
% Examples:
% * Send command 'mycommand' to serial object.
%   SerialOutput.func(mycommand) 
%
% * Send command 'mycommand' to serial object, and expect an answer
%   SerialOutput.wait_for_response_symbol = '@' % can be any symbol
%   output = SerialOutput.send_command(command, true)  
%
% * Close port if active and open
%   SerialOutput.close() 
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
% See also: Laser, Prechirper, XyzStage

classdef SerialOutput < Hardware
    properties
        device                          % the serial object name
        port                            % The COM port to use
        port_open = false;              % true if port was opened, false otherwise
        wait_delay_for_commands = 0.1   % time in s between two attempt to read output
        wait_for_response_symbol = '@'; % the symbol used internally to signal a command waiting for an output
    end
    
    methods
        function this = SerialOutput(active, device, port, BaudRate, Parity, DataBits, StopBits, Terminator, Timeout, ByteOrder)
            %% SerialOutput Object Constructor. 
            % -------------------------------------------------------------
            % Syntax: 
            %   this = SerialOutput(active, device, port, BaudRate, Parity,
            %                       DataBits, StopBits, Terminator, Timeout
            %                       ByteOrder)
            % -------------------------------------------------------------
            % Inputs:
            %   active (BOOL)
            %       If true, the serial object is created
            %   device (STR)
            %       The device name
            %   port (STR)
            %       The port connected to the HW. eg. 'COM6'
            %   BaudRate (INT or STR) - Optional - Default is 9600
            %       Rate at which bits are transitted
            %   Parity {'none', 'odd', 'even', 'mark', 'space'} - Optional
            %           - Default is 'none'
            %       Type of parity checking
            %   DataBits (INT) - Optional - Default is 8
            %       number of data bits to transmit
            %   StopBits {1, 1.5, 2} - Optional - Default is 1
            %       Number of bits used to indicate the end of a byte
            %   Terminator (STR) - Optional - Default is ''
            %       Terminator character
            %   Timeout (FLOAT) - Optional - Default is 0
            %       Time before aborting call
            %   ByteOrder {'littleEndian','bigEndian'} - Optional - Default
            %                is 'littleEndian'
            %       Byte order of the device
            % -------------------------------------------------------------
            % Outputs: 
            %   this (Daq session)
            %   a valid daq session with standard AnalogOutput functions
            %   plus the specific functions defined in the corresponding
            %   class
            % -------------------------------------------------------------
            % Extra Notes:
            % -------------------------------------------------------------
            % Author(s):
            %   Geoffrey Evans, Boris Marin, Antoine Valera. 
            %---------------------------------------------
            % Revision Date:
            %   16-05-2018 

            if nargin < 4 || isempty(BaudRate)
                BaudRate = 9600;
            end
            if nargin < 5 || isempty(Parity)
                Parity = 'none';
            end
            if nargin < 6 || isempty(DataBits)
                DataBits = 8;
            end
            if nargin < 7 || isempty(StopBits)
                StopBits = 1;
            end
            if nargin < 8 || isempty(Terminator)
                Terminator = '';
            end
            if nargin < 9 || isempty(Timeout)
                Timeout = 0;
            end
            if nargin < 10 || isempty(ByteOrder)
                ByteOrder = 'littleEndian';
            end

            %% Preliminary cleanup
            close_previous_serial_instances(device, port);
            
            %% Create new serial object
            this.name = device;
            if ischar(BaudRate)
                BaudRate = str2double(BaudRate);
            end

            %% Prepare session
            this.active = active;
            this.session = serial(   port,...
                                    'Name'      ,device,...
                                    'BaudRate'  ,BaudRate,...
                                    'Parity'    ,Parity,...
                                    'DataBits'  ,DataBits,...
                                    'StopBits'  ,StopBits,...
                                    'Terminator',Terminator,...
                                    'Timeout'   ,Timeout,...
                                    'ByteOrder' ,ByteOrder);
       
            %% Create session if the active flag is true
            if this.active && ~this.port_open   
                try
                    fopen(this.session);
                    this.port_open = true;
                catch
                    this.port_open = false;
                    error_box([this.name ,' Com port not accessible. Close any running app that could use the port. Object was not created'], 1);
                end
            end
            
            %% Set up the ouput function handle
            this.output_fcn = @func;
        end

        function output = func(this, command)
            %% Generic output function for SerialOutput objects
            %	Send the command set in command
            % -------------------------------------------------------------
            % Syntax: 
            % 	SerialOutput.output_func(command)
            % -------------------------------------------------------------
            % Inputs:
            %	command (STR)
            %       The command to send to the serial object
            % -------------------------------------------------------------
            % Outputs: 
            %  output (STR)
            %       The output if SerialOutput.wait_for_response is true
            % -------------------------------------------------------------
            % Extra Notes:
            % -------------------------------------------------------------
            % Author(s):
            %   Antoine Valera, Geoffrey Evans, Boris Marin. 
            %---------------------------------------------
            % Revision Date:
            %   25-05-2018
            
            output = [];
            if this.active && ~isempty(this.session) && ~strcmp(this.session.Status,'closed')
                %% Flush buffer and send command
                flushinput(this.session);

                %% Update the command depending in case we edited it
                if ~isempty(command) && command(1) == this.wait_for_response_symbol
                    command = command(2:end);
                    wait_for_response = true;
                else
                    wait_for_response = false;
                end

                %% Send command
                fprintf(this.session, command);
                
                %% If we wait for an ouput, loop
                if wait_for_response
                    while isempty(output)
                        pause(this.wait_delay_for_commands);
                        if this.session.BytesAvailable > 0
                            output = fscanf(this.session,'%c',this.session.BytesAvailable);
                        end
                    end
                end 
            end
        end
        
        function output = send_command(this, command, wait_for_response)  
            %% Workaround to use the generic Hardware.on() method 
            % -------------------------------------------------------------
            % Syntax: 
            %	output = SerialOutput.send_command(command, wait_for_response)
            % -------------------------------------------------------------
            % Inputs:
            %  command (STR)
            %       The command to send to the serial object
            %  wait_for_response (BOOL) - Optional - Default is false
            %       If true, the code will wait for the SerialOutput to
            %       return some text before carying on.
            % -------------------------------------------------------------
            % Outputs: 
            %  output (STR)
            %       The characters retuned by the serial object
            % -------------------------------------------------------------
            % Extra Notes:
            %  Hardware.on() callback uses a single argument, but we need 2
            %  if we have to wait for the serial object for a response. The
            %  trick is to add a special symbol as first argument. Default
            %  symbol is @. This symbol can be kept unless the serial 
            %  object you are using uses a command starting with that 
            %  symbol. in that case, you can update 
            %  this.wait_for_response_symbol with anything else.
            %  Once func is called, if the symbol is detected in first
            %  position, then the symbol is removed from the command, and
            %  the code will wait for a response before carrying on.
            % -------------------------------------------------------------
            % Author(s):
            %   Antoine Valera, Geoffrey Evans, Boris Marin. 
            %---------------------------------------------
            % Revision Date:
            %   25-05-2018

            if nargin < 3 || isempty(wait_for_response)
                wait_for_response = false;
            end
            
            %% Add a prefix this.wait_for_response_symbol to the command 
            if wait_for_response
                command = [this.wait_for_response_symbol, command];
            end
            
            %% Now we can use the generic Hardware.on() function;
            this.on_value = command;
            output = this.on();
        end

        
        function close(this)
            %% Close port if active and open
            % -------------------------------------------------------------
            % Syntax: 
            %   SerialOutput.close()
            % -------------------------------------------------------------
            % Inputs:
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
            
            if this.port_open && this.active  
                fclose(this.session);
                this.port_open = false;
            end
        end
    end
end