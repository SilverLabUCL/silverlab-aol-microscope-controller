%% Finalise a timed image recording
% This is a helper function for Controller.timed_image(). This is used now
% to convert binary files (if dump_data is true) back into the classicl 
% all_data cell array, so that using dump_data can be used in a transparent 
% way
% -------------------------------------------------------------------------
% Syntax: 
%   all_data = finalise_timed_image(controller, parameters, all_data)
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
% Partial Revision Date:
%   24-03-2018
%
% See also: timing_params, estimate_points, DataHolder, MCViewer
%


function all_data = finalise_timed_image(controller, parameters, all_data)
    if nargin < 1 || isempty(controller)
        controller = get_existing_controller_name(true);
    end

    %% In case there was a timer, delete it.
    delete(controller.viewer.timer);

    %% Post processing dumped_data
    if controller.daq_fpga.dump_data
        controller.daq_fpga.dump_data = false;
        for trial = 1:parameters.repeats
            for channel = [1,2]
                fileID = fopen(['Repeat_',num2str(trial),'_channel_',num2str(channel),'.bin']);
                trial_data = fread(fileID,'uint32');
                all_data{trial}(1:size(trial_data,1),channel) = uint16(trial_data / controller.daq_fpga.scan_cycles);
                fclose(fileID);
                delete(['Repeat_',num2str(trial),'_channel_',num2str(channel),'.bin']);
            end
        end
    end
end

