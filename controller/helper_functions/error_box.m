%% Popup error/information message
%   Popup window displaying a message. It can be used to catch an error or
%   for any message. Chose a value for carry on to sue different symbols
%
% -------------------------------------------------------------------------
% Syntax: 
%   error_box(error_msg, carry_on)
%
% -------------------------------------------------------------------------
% Inputs: 
%   message(STR) : 
%                                   The message to display in the popup
%                                   window
%
%   carry_on(INT) - Optional - default is true:  
%                                   If 0, raises an error message and
%                                   interrupt function
%                                   If 1, messge is a warning.
%                                   If 2, messge is a help dialog.
%                                   If 3, messge is a simple popup message.
%                                   otherwise the function will resume
%                                   after the popup closure.
%
% -------------------------------------------------------------------------
% Outputs:
% -------------------------------------------------------------------------
% Extra Notes:
% -------------------------------------------------------------------------
% Examples:
% -------------------------------------------------------------------------
%                               Notice
%
% Author(s): Antoine Valera
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
%   19-05-2018
%
% See also:


function error_box(message, carry_on)
    if nargin < 2
        carry_on = 2;
    end

    
    if isempty(getCurrentTask())
        %% Prompt message
        if ~carry_on
            uiwait(errordlg(message));   
        elseif carry_on == 1
            uiwait(warndlg(message)); 
        elseif carry_on == 2
            uiwait(helpdlg(message)); 
        elseif carry_on == 3
            uiwait(msgbox(message)); 
        end

        drawnow; pause(0.1);

        %% If carry_on is 0, interrupt running processes
        if ~carry_on
            error(sprintf([message,'\nProcess aborted']));
        end
    elseif ~carry_on
        error(sprintf([message,'\nProcess aborted in parfor loop']));
    end
end

