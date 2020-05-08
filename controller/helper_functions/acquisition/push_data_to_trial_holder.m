%% Push the data from the viewer into the right data holder
% -------------------------------------------------------------------------
% Syntax: 
%   all_data = push_data_to_trial_holder(this, all_data, trial)
%
% -------------------------------------------------------------------------
% Inputs: 
%   controller(Controller object) - Optional - Default is main Controller:
%                                   Contains information about the
%                                   microscope setup such as FOV, dwell
%                                   time etc...
%
%   parameters(timing_params object AND/OR {'Argument',Value} pairs):  
%                                   Any pair of 'argument' and value from 
%                                   timing_params.m See function
%                                   documentation for details
%   ---------
% 
%       {'reuse_viewer’ (BOOL)}: Default is 
%                           If ...
%
% -------------------------------------------------------------------------
% Outputs:
% all_data ([R x 1] CELL ARRAY OF [N x 2] UINT16 MATRIX) :
%                                   The cell array contains one cell per
%                                   trial R. Each trial is of size N_points
%                                   (as predicted by estimate_points) and
%                                   2 (two channels).
% -------------------------------------------------------------------------
% Extra Notes:
% * The way data is pushed depends on your acquisition method :
%   - If frame_cycle is set and dump_data is false, the holder should have
%   the exact right size, so we diractly push the data at the right
%   location.
%   - If you use a recording timer instead of a set number of cycles, the
%   amount of data can vary from trial to trial, so we use the viewer 
%   counter to push the right amount of data
%   - If you use dump_data, the files are stored in a file called data1.bin
%   and data2.bin. We rename these files to add the repeat number to the
%   name. A post-processing step is done at the end of the recording to 
%   read these files and delete temporary data
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
%   24-03-2018
%
% See also: imaging

function all_data = push_data_to_trial_holder(controller, all_data, trial)
    if nargin < 1 || isempty(controller)
        controller = get_existing_controller_name(true);
    end

    if size(all_data{1}, 1) < controller.daq_fpga.buffer_min
        controller.viewer.data0 = controller.viewer.data0(1:size(all_data{1}, 1));
        controller.viewer.data1 = controller.viewer.data1(1:size(all_data{1}, 1));
    end

    if ~controller.daq_fpga.dump_data && isnumeric(controller.frame_cycles)
        %% For when you don't use a timer
        all_data{trial}(:,1) = controller.viewer.data0;
        all_data{trial}(:,2) = controller.viewer.data1;
    elseif ~controller.daq_fpga.dump_data && ~isnumeric(controller.frame_cycles)
        %% For when you use a timer
        all_data{trial}(1:(controller.viewer.counter_ch1_pre),1) = controller.viewer.data0(1:controller.viewer.counter_ch1_pre);
        all_data{trial}(1:(controller.viewer.counter_ch2_pre),2) = controller.viewer.data1(1:controller.viewer.counter_ch2_pre);
    else
        %% For when you use HD dump
        FileRename('data2.bin', ['Repeat_',num2str(trial),'_channel_1.bin']); % 30-50 % faster than movefile
        FileRename('data1.bin', ['Repeat_',num2str(trial),'_channel_2.bin']); % 30-50 % faster than movefile
    end
end

