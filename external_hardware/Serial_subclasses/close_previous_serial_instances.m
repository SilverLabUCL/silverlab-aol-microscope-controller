%% If you start/restart the Controller, serial port can stay open
%   Function enables clean start and avoid some Serial-Port related errors
% -------------------------------------------------------------------------
% Syntax: 
%   close_previous_serial_instances(name, port)
% -------------------------------------------------------------------------
% Inputs: 
%   name(STR) - Optional - default is '': 
%                                   Name of the serial instance to close
%                                   (typically, the name of the one you are
%                                   going to open). uses instrfindall()
%
%   port(STR) - Optional - default is '': 
%                                   Port of the serial instance to close
%                                   (typically, the name of the one you are
%                                   going to open). uses instrfindall()
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
% See also: SerialOutput

function close_previous_serial_instances(name, port)
    if nargin < 1 || isempty(name)
        name = '';
    end
    if nargin < 2 || isempty(port)
        port = '';
    end
    
    %% Search by name
    any_previous = instrfindall('Name',name);
    if ~isempty(any_previous)
        for el = 1:size(any_previous,2)
            fclose(any_previous(el));
        end
    end

    %% Search by port
    any_previous = instrfindall('Port',port);
    if ~isempty(any_previous)
        for el = 1:size(any_previous,2)
            fclose(any_previous(el));
        end
    end
end

