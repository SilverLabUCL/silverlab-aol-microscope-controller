%% Disconnect backplane using NI dll
% This is recommended when stopping the controller to restore initial state
% on the NI board
% -------------------------------------------------------------------------
% Syntax:
% disconnect_backplane(nicaiu_path, nidaqmx_path)
% -------------------------------------------------------------------------
% Inputs: 
%   nicaiu_path(STR) - Optional - Default is 
%                                       'C:\Windows\System32\nicaiu.dll'
%                           Path to the NI dll
%
%   nidaqmx_path(STR) - Optional - Default is 
%       'C:\Program Files (x86)\National Instruments\Shared\...
%                          ...ExternalCompilerSupport\C\include\nidaqmx.h'
%                           Path to the nidaqmx header file
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
%   16-03-2019
%
% See also: Controller, connect_backplane

function disconnect_backplane(nicaiu_path, nidaqmx_path)
    if nargin < 1 || isempty(nicaiu_path)
        nicaiu_path = 'C:\Windows\System32\nicaiu.dll';
    end
    if nargin < 2 || isempty(nidaqmx_path)
        nidaqmx_path = 'C:\Program Files (x86)\National Instruments\Shared\ExternalCompilerSupport\C\include\nidaqmx.h';
    end

    %% First, load the library
    warning('off','MATLAB:loadlibrary:TypeNotFound');
    if ~libisloaded('nicaiu')
        [n, w] = loadlibrary(nicaiu_path,nidaqmx_path);
        %n should be empty
    end
    %libfunctions('nicaiu') % that would test loaded functions
    if ~libisloaded('nicaiu')
        error('Ni library is not loaded. It will be impossible to run hardware triggers')
    end

    %% Now connect backplane for low level triggers
    calllib('nicaiu','DAQmxDisconnectTerms','/PXI1Slot6/PXI_Trig0','/PXI1Slot6/PFI0'); % ?
    calllib('nicaiu','DAQmxDisconnectTerms','/PXI1Slot6/PXI_Trig1','/PXI1Slot6/PFI1'); % Line Trigger; Trigger 1
    calllib('nicaiu','DAQmxDisconnectTerms','/PXI1Slot6/PXI_Trig2','/PXI1Slot6/PFI2'); % Frame Trigger; Trigger 2
    calllib('nicaiu','DAQmxDisconnectTerms','/PXI1Slot6/PXI_Trig3','/PXI1Slot6/PFI3'); % Trial Trigger; Trigger 3
    calllib('nicaiu','DAQmxDisconnectTerms','/PXI1Slot6/PXI_Trig4','/PXI1Slot6/PFI4'); % Expe start Trigger
    calllib('nicaiu','DAQmxDisconnectTerms','/PXI1Slot6/PXI_Trig5','/PXI1Slot6/PFI5'); % Stimulus Trigger; Trigger 5

    %% Unload lib
    unloadlibrary('nicaiu')
    
    warning('on','MATLAB:loadlibrary:TypeNotFound');
end