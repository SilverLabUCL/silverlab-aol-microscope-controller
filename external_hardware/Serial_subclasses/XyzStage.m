%% SerialOutput subclass for XyzStage objects.
%   Serial Object to interface with the stage. In our case we use a
%   scientifica stage, but this can be changed easily. You would probably
%   have to change the commands
%
%   XyzStage objects Inherits Hardware & SerialOutput & StackAndTiles
%   objects properties. The XyzStage oject is stored in a XyzStage.session
%   field (if XyzStage.active is set to true).
%
%   Type doc XyzStage.function_name or help XyzStage.function_name to
%   get more details about the function inputs and outputs
% -------------------------------------------------------------------------
% Syntax: 
%   this = XyzStage(active, port, baudrate)
%   	Generates a XyzStage object
% -------------------------------------------------------------------------
% Class Generation Inputs: 
%   active (BOOL)
%       If true, the serial object is created
%   port (STR)
%       The port connected to the HW. eg. 'COM6'
%   BaudRate (INT or STR)
%       The baudrate to use.
%   XY_swapped (BOOL) - Optional - Default is false
%       If X and Y axes of the microscope platform are swapped, set X as Y
%       and Y as X for all the get_position, set_position and move_* 
%       functions.
% -------------------------------------------------------------------------
% Outputs: 
%   this (XyzStage object)
% -------------------------------------------------------------------------
% Class Methods (ignoring get()/set() methods):
% 
% * Wrapper to send serial commands to the stage
%   output = XyzStage.send_command(command, wait_for_response, minBytes)  
% 
% * Asynchronous call to read stage position           
%   XyzStage.disp_position()
%          
% * Callback for the asynchronous call       
%   out = XyzStage.async_read(~, ~)
%         
% * Get current stage speed   
%   speed = XyzStage.get_speed()
%         
% * Set new stage speed        
%   XyzStage.set_speed(speed)
% 
% * Get current stage acceleration
%   acc = XyzStage.get_acc()
%     
% * Set new stage acceleration         
%   XyzStage.set_acc(acc)
% 
% * Get stage position for all or one axis
%   xyz = XyzStage.get_position(ax)
%            
% * XyzStage.set_position(xyz)        
%   XyzStage.set_position(xyz, ax)
%          
% * Zero the stage position        
%   XyzStage.zero_position()
% 
% * Move the stage by x,y and z um        
%   XyzStage.move_rel(xyz)
% 
% * Move the stage to position xyz 
%   XyzStage.move_abs(xyz)
%             
% * flip axes as specified in XY_swapped, swap_XDir, swap_YDir swap_ZDir
%   xyz = XyzStage.correct_axes(xyz)
%          
% * Check for stage issue 
%   active = check_stage_validity()
%
% -------------------------------------------------------------------------
% Extra Notes:
% * The object can be used independently, but in the microscope controller,
%   they are stored in Controller.xyz_stage. It is generated when the 
%   controller is created.
%
% * In the Controller setup.ini, default fields are set in 
%   "XY Stage.Available?", "XY Stage.Baudrate", "XY Stage.COM port",
%   "Z Stage.Baudrate", "Z Stage.COM port" and "XY Stage.Swapped". 
%   
% * FOR NOW, Z STAGE MUST BE THE SAME THAN XY
%
% * The XYZ stage inherits functions from StackAndTiles which is the class
%   dealing with stack, tiles etc...
%
% * The current settings are for   Stage controller for Scientifica 
%   motorized stage, using the COM port defined in rig_params.m.
%   Please refer to themanufacturer manual for the commands
%   More scientifica stuff at http://www.scientifica.uk.com/customer-downloads
%
% * Initial calibration
%   - You want X stage motion to match X-axis rendering. If, on the screen,
%   you want to move to an object located on the right, the stage must
%   return positive offsets.
%   --> If not, stage sign can be swapped using linlab (best option) or
%   this.swap_XDir = true (but there will be a mismatch between stage
%   values and internal software coordinate system)
%
% -------------------------------------------------------------------------
% Examples:
% * Create a stage control object
%   stage = XyzStage(true, 'COM6', 9600);
%
% * Move the stage by 20um in Y
%   stage.move_rel([0, 20, 0])
%
% * Move the stage to [0, 0, 0]
%   stage.move_abs([0, 0, 0])
%
% -------------------------------------------------------------------------
%                               Notice
%
% Author(s): Antoine Valera, Geoffrey Evans, Boris Marin, Pierre Pinson 
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
%   25-05-2018
%
% See also: SerialOutput, Hardware, StackAndTiles

%TODO :  set limits to prevent accidents with LIMITS
%        set initial speed with FIRST

classdef XyzStage < StackAndTiles & SerialOutput
    properties
        current_pos         % the X Y Z current position of the stage
        tolerance  = 0.1;   % the acceptable error in um when moving the stage
        XY_swapped = false; % If motor X and Y axis are inverted, change this value
        swap_XDir  = false; % Ideally, you should invert the direction of values on the stage software
        swap_YDir  = false; % Ideally, you should invert the direction of values on the stage software
        swap_ZDir  = false; % Ideally, you should invert the direction of values on the stage software
    end
    
    methods
        function this = XyzStage(active, port, BaudRate, XY_swapped)
            if nargin < 4 || isempty(XY_swapped)
                XY_swapped = false;
            end
                
            %% Device specific settings
            device = 'XYZ_Stage';
            if ~isnumeric(BaudRate)
                BaudRate = str2double(BaudRate);
            end
            Parity = 'none';
            DataBits = 8;
            StopBits = 1;
            Terminator = 'CR';
            Timeout = 10;
            
            %% Creating the session
            this@SerialOutput(active, device, port, BaudRate, Parity, DataBits, StopBits, Terminator, Timeout);
            
            this.XY_swapped = XY_swapped;
        end

        function output = send_command(this, command, wait_for_response, minBytes)  
            %% Wrapper to send serial commands to the stage
            % Bypass default SerialOutput.send_command() to get better stage
            % performances
            % -------------------------------------------------------------
            % Syntax: 
            %   output = XyzStage.send_command(command, wait_for_response, minBytes) 
            % -------------------------------------------------------------
            % Inputs:
            %   command(STR) : The Command to pass to the serial port
            %   wait_for_response(BOOL) : if the command requires an
            %               output, set to true
            %   minBytes(INT) - Optional - default is 6 : number of bytes
            %               to expect in the output
            % -------------------------------------------------------------
            % Outputs:
            %   minBytes(STR) - Optional - if wait_for_response is true,
            %   then it is the output of the call
            % -------------------------------------------------------------
            % Extra Notes:
            % -------------------------------------------------------------
            % Author(s):
            %   Antoine Valera, Geoffrey Evans
            %---------------------------------------------
            % Revision Date:
            %   30-03-2020

            if nargin < 4
                minBytes = 6;
            end
            
            %% Detect stage issues
            check_stage_validity(this);
            
            %% Send comamnd
            if this.active
                flushinput(this.session);
                output = [];
                fprintf(this.session, command);

                if wait_for_response %% average response time is 60ms
                    while isempty(output) || ~strcmp(output(end),sprintf('\r')) || numel(str2num(output)) ~= wait_for_response
                        if this.session.BytesAvailable >= minBytes
                            output = fscanf(this.session,'%c',this.session.BytesAvailable);
                        end
                        if ~isempty(output) && ~strcmp(output(end),sprintf('\r')) %then retry
                            flushinput(this.session);
                            output = [];
                            fprintf(this.session, command);
                        end
                    end
                    output = str2num(output);
                else    
                    while isempty(output)% || contains(output,'A')
                        if this.session.BytesAvailable >= 2
                            output = fscanf(this.session,'%c',this.session.BytesAvailable);
                            busy = true;
                            while busy
                                fprintf(this.session, 'S');
                                if this.session.BytesAvailable >= 2
                                    busy = str2num(fscanf(this.session,'%c',this.session.BytesAvailable));
                                end
                            end
                        end
                    end
                end 
            else
                output = NaN;
            end
        end
        
        function disp_position(this)
            %% Asynchronous call to read stage position
            % Use when you click on a button
            % -------------------------------------------------------------
            % Syntax: 
            %   XyzStage.disp_position() 
            % -------------------------------------------------------------
            % Inputs:
            % -------------------------------------------------------------
            % Outputs:
            %   print current position in command window
            % -------------------------------------------------------------
            % Extra Notes:
            % -------------------------------------------------------------
            % Author(s):
            %   Antoine Valera, Geoffrey Evans
            %---------------------------------------------
            % Revision Date:
            %   30-03-2020
            
            fprintf(this.session, 'POS');
            t = timerfindall('Name', 'posreader');
            
            %% Create a function at first launch
            if size(t,2) == 0 
                t = timer('Name','posreader','TimerFcn', @this.async_read);
            end

            start(t(1));
            stop(t(1));
        end
        
        function out = async_read(this, ~, ~)
            %% Callback for the asynchronous call
            % Internal function
            
            out = fscanf(this.session,'%c',this.session.BytesAvailable);
            output = round(0.1*str2num(out));
            this.current_pos = output;
            fprintf('[%f, %f, %f]\n', output)
        end
    
    	function speed = get_speed(this)            
            %% Get current stage speed
            % -------------------------------------------------------------
            % Syntax: 
            %   speed = XyzStage.get_speed() 
            % -------------------------------------------------------------
            % Inputs:
            % -------------------------------------------------------------
            % Outputs:
            %   speed(FLOAT) : Current stage speed
            % -------------------------------------------------------------
            % Extra Notes:
            % -------------------------------------------------------------
            % Author(s):
            %   Antoine Valera, Geoffrey Evans
            %---------------------------------------------
            % Revision Date:
            %   30-03-2020
            
            speed = ['max speed : ',num2str(this.send_command('TOP', 1)/10), ' um per sec'];
        end
        
    	function set_speed(this, speed)
            %% Set new stage speed
            % -------------------------------------------------------------
            % Syntax: 
            %   XyzStage.set_speed(speed) 
            % -------------------------------------------------------------
            % Inputs:
            %   speed(FLOAT) : New stage speed
            % -------------------------------------------------------------
            % Outputs:
            % -------------------------------------------------------------
            % Extra Notes:
            % -------------------------------------------------------------
            % Author(s):
            %   Antoine Valera, Geoffrey Evans
            %---------------------------------------------
            % Revision Date:
            %   30-03-2020
            
            this.send_command(sprintf('FIRST %d', speed*10), 0);
            this.send_command(sprintf('TOP %d', speed*10), 0);
        end

    	function acc = get_acc(this)
            %% Get current stage acceleration
            % -------------------------------------------------------------
            % Syntax: 
            %   acc = XyzStage.get_acc() 
            % -------------------------------------------------------------
            % Inputs:
            % -------------------------------------------------------------
            % Outputs:
            %   speed(FLOAT) : Current stage acceleration
            % -------------------------------------------------------------
            % Extra Notes:
            % -------------------------------------------------------------
            % Author(s):
            %   Antoine Valera, Geoffrey Evans
            %---------------------------------------------
            % Revision Date:
            %   30-03-2020
            
            acc = ['max acceleration : ',num2str(this.send_command('ACC', 1, 4)/10)]; %ACC is encoded on 4 bytes
        end
        
    	function set_acc(this, acc)
            %% Set new stage acceleration 
            % -------------------------------------------------------------
            % Syntax: 
            %   XyzStage.set_acc(acc) 
            % -------------------------------------------------------------
            % Inputs:
            %   speed(FLOAT) : New stage acceleration
            % -------------------------------------------------------------
            % Outputs:
            % -------------------------------------------------------------
            % Extra Notes:
            % -------------------------------------------------------------
            % Author(s):
            %   Antoine Valera, Geoffrey Evans
            %---------------------------------------------
            % Revision Date:
            %   30-03-2020
            
            this.send_command(sprintf( 'ACC %d', acc*10), 0);
            this.send_command(sprintf('JACC %d', acc*10), 0);
        end
        
        function xyz = get_position(this, ax)
            %% Get stage position for all or one axis
            % -------------------------------------------------------------
            % Syntax: 
            %   xyz = XyzStage.get_position(ax) 
            % -------------------------------------------------------------
            % Inputs:
            %   ax(INT) - Optional - Default is [];
            %       If 1, 2, or 3, returns only x, y or z position
            %       repectively
            % -------------------------------------------------------------
            % Outputs:
            %   xyz([1 x 3] FLOAT) : [X, Y, Z] position of the stage if ax
            %                           was [] or not provided, otherwise 
            %                           X, Y or Z position only
            % -------------------------------------------------------------
            % Extra Notes:
            % -------------------------------------------------------------
            % Author(s):
            %   Antoine Valera, Geoffrey Evans
            %---------------------------------------------
            % Revision Date:
            %   30-03-2020
            
            %% Get position
            if this.active && check_stage_validity(this)
                xyz = this.send_command('POS', 3) * 0.1;
            else
                xyz = [0,0,0];
            end
            
            %% Correct for inversion etc...
            xyz = this.correct_axes(xyz);
            
            %% If 1, 2 or 3, return the value for the specified axis
            if nargin > 1 && ~isempty(ax)
                xyz = xyz(ax);
            end
        end
        
        function set_position(this, xyz, ax)
            %% Set current position to this value (doesn't move the stage)
            % -------------------------------------------------------------
            % Syntax: 
            %   xyz = XyzStage.set_position(xyz, ax) 
            % -------------------------------------------------------------
            % Inputs:
            %   xyz(FLOAT or [1 x 3] FLOAT) : [X, Y, Z] position of the stage
            %   ax(INT) - Optional - Default is [];
            %       If 1, 2, or 3, set only x, y or z position
            % -------------------------------------------------------------
            % Outputs:
            %   xyz([1 x 3] FLOAT) : [X, Y, Z] position of the stage if ax
            %                           was [] or not provided, otherwise 
            %                           X, Y or Z position only
            % -------------------------------------------------------------
            % Examples:
            % * Set a new position
            %   c.xyz_stage.set_position([-5.4,-14,-4]) 
            % * To set a specific axis only (axis 2 here)
            %   c.xyz_stage.set_position(-14, 2)
            % -------------------------------------------------------------
            % Author(s):
            %   Antoine Valera, Geoffrey Evans
            %---------------------------------------------
            % Revision Date:
            %   30-03-2020
            
            if nargin < 3 || isempty(ax)
                ax = [];
            elseif numel(xyz) == 1
                current_xyz = this.get_position();
                current_xyz(ax) = xyz;
                xyz = current_xyz;
            end
            
            %% Correct for inversion etc...
            xyz = this.correct_axes(xyz);

            %% Update
            this.send_command(sprintf('POS %d %d %d', round(xyz * 10)), 0);
        end
        
        function zero_position(this)
            %% Zero the stage position
            % -------------------------------------------------------------
            % Syntax: 
            %   XyzStage.zero_position() 
            % -------------------------------------------------------------
            % Inputs:
            % -------------------------------------------------------------
            % Outputs:
            % -------------------------------------------------------------
            % Extra Notes:
            % -------------------------------------------------------------
            % Author(s):
            %   Antoine Valera, Geoffrey Evans
            %---------------------------------------------
            % Revision Date:
            %   30-03-2020
            
            this.send_command('ZERO', 0); % equivalent to this.set_position([0,0,0])
        end
        
    	function move_rel(this, xyz)
            %% Move the stage by x, y and z um
            % -------------------------------------------------------------
            % Syntax: 
            %   XyzStage.move_rel(xyz) 
            % -------------------------------------------------------------
            % Inputs:
            %   xyz([1 x 3] FLOAT) : [X, Y, Z] displacement to do (in um)
            % -------------------------------------------------------------
            % Outputs:
            % -------------------------------------------------------------
            % Extra Notes:
            % -------------------------------------------------------------
            % Author(s):
            %   Antoine Valera, Geoffrey Evans
            %---------------------------------------------
            % Revision Date:
            %   30-03-2020
            
            xyz = this.correct_axes(xyz);
            this.send_command(sprintf('REL %d %d %d', round(xyz*10)), 0);
        end
 
        function move_abs(this, xyz)
            %% Move the stage to position xyz
            % -------------------------------------------------------------
            % Syntax: 
            %   XyzStage.move_abs(xyz) 
            % -------------------------------------------------------------
            % Inputs:
            %   xyz([1 x 3] FLOAT) : go to position [X, Y, Z]
            % -------------------------------------------------------------
            % Outputs:
            % -------------------------------------------------------------
            % Extra Notes:
            % -------------------------------------------------------------
            % Author(s):
            %   Antoine Valera, Geoffrey Evans
            %---------------------------------------------
            % Revision Date:
            %   30-03-2020
            
            xyz = this.correct_axes(xyz);
            this.send_command(sprintf('ABS %d %d %d', round(xyz*10)), 0);
        end
   
        function xyz = correct_axes(this, xyz)
            %% Correct for axes swapping / inversions
            % -------------------------------------------------------------
            % Syntax: 
            %   XyzStage.correct_axes(xyz) 
            % -------------------------------------------------------------
            % Inputs:
            %   xyz([1 x 3] FLOAT) : [X, Y, Z] poistion set
            % -------------------------------------------------------------
            % Outputs:
            % -------------------------------------------------------------
            % Extra Notes:
            %   depending on your configuration, what is commonly 
            %   attributed to x, y or z caan be mirrored or swapped. See
            %   class extra notes for more information
            % -------------------------------------------------------------
            % Author(s):
            %   Antoine Valera, Pierre Pinson
            %---------------------------------------------
            % Revision Date:
            %   30-03-2020

            if this.XY_swapped
                xyz = [xyz(2),xyz(1),xyz(3)];
            end
            
            if this.swap_XDir
                xyz(1) = -xyz(1);
            end
            
            if this.swap_YDir
                xyz(2) = -xyz(2);
            end
            
            if this.swap_ZDir
                xyz(3) = -xyz(3);
            end
        end
        
        function active = check_stage_validity(this)
            %% Under developpement
            
            %             if ~strcmp(this.session.Status, 'open') && this.active
            %                 warning(['Stage connection not found / lost / deleted. Stage command will be ignored from now on. You need to regenerate a new stage',...
            %                       'c.xyz_stage  = XyzStage(c.rig_params.is_xy_stage, c.rig_params.xy_stage_com_port, c.rig_params.xy_stage_baudrate, c.rig_params.xy_stage_swapped)']); %Stage control and stack/tiles limits
            %                 this.active = false;
            %             end
            active = this.active;
        end
    end
end