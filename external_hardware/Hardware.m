%% Abstract Superclass for all external Controller Hardware.
%   Hardware properties are inherited from another  a subclass
%
%   Type doc Hardware.method_name or help Hardware.method_name to get more 
%   details about the function inputs and outputs.
% -------------------------------------------------------------------------
% Syntax:
%   No Direct instantiation. Properties are inherited by a subclass. see
%   Extra Notes
% -------------------------------------------------------------------------
% Class Generation Inputs:  
% -------------------------------------------------------------------------
% Outputs: 
%   this (DigitalOutput object)
% -------------------------------------------------------------------------
% Class Methods (ignoring get()/set() methods):
%
% * Set Harware limits and default behaviour (typically called during 
%   subclass initialisation).
%   Hardware.set_HW_limits(min_value, max_value, on_value, off_value)
%       
% * Set Hardware.on_value by calling @output_fcn
%   Hardware.on()
%   	 
% * Set Hardware.off_value by calling @output_fcn
%   Hardware.off()
%
% *	Delete session and close connection.
%   Hardware.delete()
% -------------------------------------------------------------------------
% Extra Notes:
% * Hardware objects cannot be directly generated. 
%
% * You must define a @output_fcn in each children classes. This function
%   is called to set the hardware new_value when you call Hardware.on().
%   the type of function depends on the nature of you hardware. It can be
%   sending a serial command, or setting the dive to a specific value. Find
%   more details in classes inheriting from Hardware, such as SerialOutput
%   or DigitalOutput.
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
% See also: AnalogOutput, DigitalOutput, SerialOutput

classdef (Abstract = true) Hardware < handle
    properties
        active = 0          % if false, session is not created
        name = 'NoName'     % the name of the object
        session             % typically a ni session or a serial port   
        
        max_value           % max value allowed for the Hardware
        min_value           % min value allowed for the Hardware
        on_value            % The value set if you call Hardware.on()
        off_value           % The value set if you call Hardware.off()
        status = []         % The current status of the device.      

        output_fcn = ''     % Handle called when changing the device value
        user_settings = {}; % Any user-defined variables can attached here
        
        cleanup_handle = onCleanup(@() delete(this)); %run on controller deletion
    end
    
    methods
        function set_HW_limits(this, min_value, max_value, on_value, off_value)
            %% Called on object generation to limit value range.
            % -------------------------------------------------------------
            % Syntax: 
            %   this = Hardware(min_value, max_value, on_value, off_value)
            % -------------------------------------------------------------
            % Inputs:
            %   min_value (FLOAT)
            %       The minimal valid value for the device
            %   max_value (FLOAT)
            %       The maximum valid value for the device. Be careful as
            %       setting a wrong value can destroy the device.
            %   on_value (FLOAT) - Optional - Default is max_value
            %       The value set if you call Hardware.on()
            %   off_value (FLOAT) - Optional - Default is min_value
            %       The value set if you call Hardware.off()
            % -------------------------------------------------------------
            % Outputs: 
            % -------------------------------------------------------------
            % Extra Notes:
            % If you don't pass any value for 
            % -------------------------------------------------------------
            % Author(s):
            %   Antoine Valera. 
            %---------------------------------------------
            % Revision Date:
            %   16-05-2018 
            
            %% Check inputs
            if ~all(isnumeric([min_value, max_value, on_value])) || min_value > max_value
                error('Your inputs are not valid')
            end
            
            %% Set value limits
            this.min_value = min_value;
            this.max_value = max_value;
            if nargin < 4 || isempty(off_value)
                this.on_value = max_value;
            else
                this.on_value = on_value;
            end
            if nargin < 4 || isempty(off_value)
                this.off_value = min_value;
            else
                this.off_value = off_value;
            end

            %% Safety checks if you call the function a second time
            if isempty(this.on_value) || this.on_value < this.min_value || this.on_value > this.max_value
                if ~isempty(this.on_value) && (this.on_value < this.min_value || this.on_value > this.max_value)
                    fprintf('On value was ending outside allowed limits and was set to max_value\n')
                end
                this.on_value = this.min_value;
            end
            if isempty(this.off_value) || this.off_value < this.min_value || this.off_value > this.max_value
                if ~isempty(this.off_value) && (this.off_value < this.min_value || this.off_value > this.max_value)
                    fprintf('Off value was ending outside allowed limits and was set to min_value\n')
                end
                this.off_value = this.min_value;
            end
        end
       
        function set.min_value(this, new_value)
            %% Set min_value. Min value has the absolute priority on all others
            % -------------------------------------------------------------
            % Syntax: 
            %   Hardware.min_value = new_value
            % -------------------------------------------------------------
            % Inputs:
            %   new_value (FLOAT)
            %       Any value between Hardware.min_value and 
            %       Hardware.max_value
            % -------------------------------------------------------------
            % Outputs: 
            % -------------------------------------------------------------
            % Extra Notes:
            % -------------------------------------------------------------
            % Author(s):
            %   Antoine Valera. 
            %---------------------------------------------
            % Revision Date:
            %   24-05-2018  
            
            if ~isempty(this.max_value) && new_value > this.max_value
                this.min_value = new_value;
            else
                this.min_value = new_value;
            end
            
            %% Safety checks if any value is changed
            if this.on_value < this.min_value
                this.on_value = this.min_value;
                fprintf('on_value was ending below min limit and was set to the new min_value\n')
            end
            if this.off_value < this.min_value
                this.off_value = this.min_value;
                fprintf('off_value was ending below min limit and was set to the new min_value\n')
            end
        end
        
        function set.max_value(this, new_value)
            %% Set max_value (unless < to min value)
            % -------------------------------------------------------------
            % Syntax: 
            %   Hardware.max_value = new_value
            % -------------------------------------------------------------
            % Inputs:
            %   new_value (FLOAT)
            %       Any value between min_value and max_value
            % -------------------------------------------------------------
            % Outputs: 
            % -------------------------------------------------------------
            % Extra Notes:
            % -------------------------------------------------------------
            % Author(s):
            %   Antoine Valera. 
            %---------------------------------------------
            % Revision Date:
            %   24-05-2018 
            
            if new_value < this.min_value
                this.max_value = this.min_value;
            else
                this.max_value = new_value;
            end
            
            %% Safety checks if any value is changed
            if this.on_value > this.max_value
                this.on_value = this.max_value;
                fprintf('on_value was ending above max limit and was set to the new max_value\n')
            end
            if this.off_value > this.max_value
                this.off_value = this.max_value;
                fprintf('off_value was ending above max limit and was set to the new max_value\n')
            end
        end
        
        function set.on_value(this, new_value)
            %% Change the on_value. 
            %   If you call Hardware.on(), device is set to this.on_value.
            % -------------------------------------------------------------
            % Syntax: 
            %   Hardware.on_value = new_value
            % -------------------------------------------------------------
            % Inputs:
            %   new_value (FLOAT)
            %       Any value between min_value and max_value. Value is set
            %       when you call Hardware.on
            % -------------------------------------------------------------
            % Outputs: 
            % -------------------------------------------------------------
            % Extra Notes:
            % -------------------------------------------------------------
            % Author(s):
            %   Antoine Valera. 
            %---------------------------------------------
            % Revision Date:
            %   24-05-2018 
            
            if isempty(new_value)
                % pass, happens when reloading old sessions
            elseif ~ischar(new_value) && (new_value > this.max_value || new_value < this.min_value)
                error(['new value too extreme, value was not changed. Limits are ', num2str(this.min_value), ' and ', num2str(this.max_value)])
            else
                this.on_value = new_value;
            end
        end 
        
        function set.off_value(this, new_value)
            %% Change the off_value.
            %   If you call Hardware.off(), device is set to this.off_value
            % -------------------------------------------------------------
            % Syntax: 
            %   Hardware.off_value = new_value
            % -------------------------------------------------------------
            % Inputs:
            %   new_value (FLOAT)
            %       Any value between min_value and max_value. Value is set
            %       when you call Hardware.off
            % -------------------------------------------------------------
            % Outputs: 
            % -------------------------------------------------------------
            % Extra Notes:
            % -------------------------------------------------------------
            % Author(s):
            %   Antoine Valera. 
            %---------------------------------------------
            % Revision Date:
            %   24-05-2018 
            
            
            if isempty(new_value)
                % pass, happens when reloading old sessions
            elseif ~ischar(new_value) && (new_value > this.max_value || new_value < this.min_value)
                error(['new value too extreme, value was not changed. Limits are ', num2str(this.min_value), ' and ', num2str(this.max_value)])
            else
                this.off_value = new_value;
            end
        end  

        function output = on(this)
            %% Call @output_fcn and set Hardware.on_value.
            % -------------------------------------------------------------
            % Syntax: 
            %   Hardware.on()
            % -------------------------------------------------------------
            % Inputs:
            % -------------------------------------------------------------
            % Outputs: 
            % -------------------------------------------------------------
            % Extra Notes:
            %   Change Hardware.on_value to change Hardware.on() behaviour
            %   Hardware.Status is set to 1
            % -------------------------------------------------------------
            % Author(s):
            %   Antoine Valera.
            %---------------------------------------------
            % Revision Date:
            %   24-03-2018
            
            output = [];
            if ~isempty(this.output_fcn) %&& this.active %% empty on startup
                this.status = 1;
                output = this.output_fcn(this, this.on_value);
            end 
        end    

        function output = off(this)
            %% Call @output_fcn and set Hardware.off_value.
            % -------------------------------------------------------------
            % Syntax: 
            %   Hardware.off()
            % -------------------------------------------------------------
            % Inputs:
            % -------------------------------------------------------------
            % Outputs: 
            % -------------------------------------------------------------
            % Extra Notes:
            %   Change Hardware.off_value to change Hardware.off() behaviour
            %   Harware.Status is set to 0
            % -------------------------------------------------------------
            % Author(s):
            %   Antoine Valera.
            %---------------------------------------------
            % Revision Date:
            %   24-03-2018

            output = [];
            if ~isempty(this.output_fcn) && this.active && ~check_caller({'uiimport','uiopen','load'})  %% empty on startup and dont try to close if you reoad an old session
                output = this.output_fcn(this, this.off_value);
                this.status = 0;
            end 
        end
        
        function delete(this)
            %% Close daq and serial sessions, delete object
            % -------------------------------------------------------------
            % Syntax: 
            %   Hardware.delete()
            % -------------------------------------------------------------
            % Inputs:
            % -------------------------------------------------------------
            % Outputs: 
            % -------------------------------------------------------------
            % Extra Notes:
            % The destructor is ignored if destruction is called from a 
            % specific set of function. This is to prevent the reloading of
            % a previous object to delete the currenty session.
            % -------------------------------------------------------------
            % Author(s):
            %   Geoffrey Evans, Boris Marin, Antoine Valera.
            %---------------------------------------------
            % Revision Date:
            %   24-03-2018
            
            if ~check_caller({'uiimport','uiopen','load'})  % prevent current session destruction when reloading previous sessions
                
                %% Deactivate HW before closing session
                if ~isempty(this.on_value)
                    this.off();
                end

                %% Close sessions that support fclose
                if ismethod(this.session,'close')
                    this.session.close();
                    fprintf('closes Port from %s\n', char(this.name))
                end

                %% Delete object
                if ismethod(this.session,'delete')
                    delete(this.session);
                    fprintf('disconnected from %s\n', char(this.name))
                end
            end
        end
    end
end