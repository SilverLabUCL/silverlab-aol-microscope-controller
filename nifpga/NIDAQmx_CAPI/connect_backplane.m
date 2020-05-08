%% Connect backplane using NI dll, to access some specific features
% Some controls are not possible through the the NI CAPI, such as the
% initial setup of the Triggers. We use the NI dll for this instead.
%
% -------------------------------------------------------------------------
% Syntax:
% status = connect_backplane(nicaiu_path, nidaqmx_path, 
%                           use_hw_start_trigger, use_hw_stim_trigger)
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
%
%   use_hw_start_trigger(BOOL) - Optional - Default is true
%                           If true, Hardware start trigger will be
%                           available. This is recommended for any precise
%                           synchronization between imaging and the
%                           start trigger
%
%   use_hw_stim_trigger(BOOL) - Optional - Default is true
%                           If true, stim trigger lines will be available
% -------------------------------------------------------------------------
% Outputs:
%   status(BOOL)
%                           true is setup was sucessful
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
% See also: Controller, Trigger, disconnect_backplane

function status = connect_backplane(nicaiu_path, nidaqmx_path, use_hw_start_trigger, use_hw_stim_trigger)
    if nargin < 1 || isempty(nicaiu_path)
        nicaiu_path = 'C:\Windows\System32\nicaiu.dll';
    end
    if nargin < 2 || isempty(nidaqmx_path)
        nidaqmx_path = 'C:\Program Files (x86)\National Instruments\Shared\ExternalCompilerSupport\C\include\nidaqmx.h';
    end
    if nargin < 3 || isempty(use_hw_start_trigger)
        use_hw_start_trigger = true;
    end
    if nargin < 4 || isempty(use_hw_stim_trigger)
        use_hw_stim_trigger = true;
    end

    warning('off','MATLAB:loadlibrary:TypeNotFound');
    
    %% First, load the library
    if ~libisloaded('nicaiu')
        [n, w] = loadlibrary(nicaiu_path,nidaqmx_path);
        %n should be empty
    end
    %libfunctions('nicaiu') % that would test loaded functions
    if ~libisloaded('nicaiu')
        error('Ni library is not loaded. It will be impossible to run hardware triggers')
    end

    %% Now connect backplane for low level triggers
    t0 = calllib('nicaiu','DAQmxConnectTerms','/PXI1Slot6/PXI_Trig0','/PXI1Slot6/PFI0',0); % ?
    t1 = calllib('nicaiu','DAQmxConnectTerms','/PXI1Slot6/PXI_Trig1','/PXI1Slot6/PFI1',0); % Line Trigger; Trigger 1
    t2 = calllib('nicaiu','DAQmxConnectTerms','/PXI1Slot6/PXI_Trig2','/PXI1Slot6/PFI2',0); % Frame Trigger; Trigger 2
    t3 = calllib('nicaiu','DAQmxConnectTerms','/PXI1Slot6/PXI_Trig3','/PXI1Slot6/PFI3',0); % Trial Trigger; Trigger 3

    %% Connect backplane for Experiment start Trigger
    if use_hw_start_trigger
        t4 = calllib('nicaiu','DAQmxConnectTerms','/PXI1Slot6/PXI_Trig4','/PXI1Slot6/PFI4',0); % Start Exp Trigger; Trigger 4
    else
        t4 = calllib('nicaiu','DAQmxDisconnectTerms','/PXI1Slot6/PXI_Trig4','/PXI1Slot6/PFI4');
    end

    %% Connect backplane for Stimulus Trigger
    if use_hw_stim_trigger
        t5 = calllib('nicaiu','DAQmxConnectTerms','/PXI1Slot6/PXI_Trig5','/PXI1Slot6/PFI5',0); % Stimulus Trigger; Trigger 5
    else
        t5 = calllib('nicaiu','DAQmxDisconnectTerms','/PXI1Slot6/PXI_Trig5','/PXI1Slot6/PFI5');
    end
    
    status = ~any([t0,t1,t2,t3,t4,t5]); % should all be 0's

    %% Unload lib
    unloadlibrary('nicaiu')
    
    warning('on','MATLAB:loadlibrary:TypeNotFound');
end