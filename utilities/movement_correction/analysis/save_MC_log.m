%% Load temporary MC logs and format then in struct
%   Use this function to post-process multiple trials. The function is used
%   internally in timed_image
%
% -------------------------------------------------------------------------
% Syntax: 
%   mc_log = save_MC_log(source_folder, rendering, keep_raw)
%
% -------------------------------------------------------------------------
% Inputs: 
%   source_folder(STR Path) - Optional - default is current folder
%
%   rendering(BOOL) - Optional - default is false:  
%                       If true, each loaded MC plot is displayed (see
%                       import_MC_log.m for details) 
%
%   keep_raw(BOOL) - Optional - default is false:    
%                       If true, the raw MC logs are not deleted after
%                       processing. This can cause some conflicts if you do
%                       not delete the files from previous trials.
% -------------------------------------------------------------------------
% Outputs:
%   mc_log             (STRUCT of [1 X M] CELL ARRAYS)
%                       struct object containing the MC log, one cell per
%                       trial. The following fields are extracted
%                       - X_correction = Correction in the x axis
%                       - Y_correction = Correction in the y axis
%                       - Z_correction = Correction in the z axis or NaN
%                       - X_difference = Error in the x
%                       - Y_difference = Error in the y
%                       - Z_difference = Error in the z axis or NaN
%                       - Time         = System timestamps of read time.
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
%   05-02-2019
%
% See also: import_MC_log, timed_image, load_mc_log


function mc_log = save_MC_log(source_folder, rendering, keep_raw)
    if nargin < 2 || isempty(source_folder)
        source_folder = '';
    end
    if nargin < 3 || isempty(rendering)
        rendering = true;
    end
    if nargin < 4 || isempty(keep_raw)
        keep_raw = false;
    end
    
    if ~keep_raw
        cleanupObj = onCleanup(@() clear_logs()); %run on normal completion, or a forced exit, such as an error or CTRL+C
    end
    
    %% Initialise cells (one per trial)
    X_correction = {};
    Y_correction = {};
    Z_correction = {};
    X_difference = {};
    Y_difference = {};
    Z_difference = {};
    Time = {};
    
    %% List temp files
    files = dir([source_folder, '*MC_log_timed_image_repeat_*.txt']);
    %files = dir('*MC_log_*.txt'); qq deal with this for generic log loading

    %% Load and format data from temp files
    initial_time = [];
    for r = 1:numel(files)
        try
            f_name = files(r).name;
            [x, y, z, x_diff, y_diff, z_diff, MCTime, initial_time] = ...
                import_MC_log(f_name, initial_time, rendering);
            X_correction{r} = x';
            Y_correction{r} = y';
            Z_correction{r} = z';
            X_difference{r} = x_diff';
            Y_difference{r} = y_diff';
            Z_difference{r} = z_diff';
            Time{r} = MCTime';
            if ~keep_raw
                force_delete([files(r).folder,'/',f_name]); % delete temporary file if processed
            end
        end
    end
    
    %% Create struct output
    mc_log = {};
    mc_log.X_correction = X_correction;
    mc_log.Y_correction = Y_correction;
    mc_log.Z_correction = Z_correction;
    mc_log.X_difference = X_difference;
    mc_log.Y_difference = Y_difference;
    mc_log.Z_difference = Z_difference;
    mc_log.Time = Time;
end

function clear_logs()
    %% Finally, bkp any unprocessed
    files = dir('*MC_log_*.txt');
    for idx = 1:numel(files)
        movefile([files(idx).folder,'/',files(idx).name],strrep([files(idx).folder,'/',files(idx).name],'.txt','.mcbkp'));
    end
end