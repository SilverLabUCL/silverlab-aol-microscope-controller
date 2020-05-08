%% Prechiper connection is sometimes lost
% If you didn't activate prechiper remote mode on startup or the connection
% got lost, you can safely reenable it with this function
% -------------------------------------------------------------------------
% Syntax: 
%   reset_prechirper(controller)
% -------------------------------------------------------------------------
% Inputs: 
%   controller(Controlelr object) - Optional - default is current 
%               Controller: 
%                                   Handle to current controller, where
%                                   prechirper will be regenerated
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
%   30-03-2020
%
% See also: Prechirper

function reset_prechirper(controller)
    if nargin < 1 || isempty(controller)
        controller = get_existing_controller_name(true);
    end

    %% Call this function if the generation initially failed and you want to recreate the object
    delete(controller.prechirper);
    controller.prechirper = Prechirper(controller.rig_params.is_prechirper, controller.rig_params.prechirper_com_port, controller.rig_params.prechirper_baudrate);
end

