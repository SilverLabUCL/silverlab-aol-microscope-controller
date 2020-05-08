%% Correct file or folder path for all platforms
%   You can alway pass this function by safetly every time you are loading
%   some file or testing folder/files existance
% -------------------------------------------------------------------------
% Syntax: 
%   [filepath, folder_path, file, n_plus1, n_plus2] = adjust_pathnames(path)
%
% -------------------------------------------------------------------------
% Inputs:
%   path (STR) 
%                                   The folder or file path to check and
%                                   fix
%
% -------------------------------------------------------------------------
% Outputs:
%   filepath (STR) :
%                                   The full path to the file you indicated
%
%   folder_path (STR) :
%                                   The path to the folder containing the
%                                   file set as input, or the path set as
%                                   input itself if it was a folder.
%
%   file (STR) :
%                                   The filename on its own, if your input
%                                   was pointing to a file.
%
%   n_plus1 (STR) :
%                                   The parent path to the current input
%                                   location
%
%   n_plus2 (STR) :
%                                   The grand-parent path to the current 
%                                   input location
%
% -------------------------------------------------------------------------
% Extra Notes:
% -------------------------------------------------------------------------
% Examples: 
%
% * Get the filepath, data folder and expe_folder for a known file
%   [filepath, ~, data_folder, expe_folder, day_folder] =...
%           adjust_pathnames('\some\data\file.mat')
%
% * Get the experiment and day folder name for a data_folder
%   [~, ~, ~, expe_folder, day] = adjust_pathnames('\some\data\folder\')
%
% * Fix an incorrect folder path
%   [~, corrected_path, ~, ~, ~] = adjust_pathnames('/some\\data\folder');
%   corrected_path --> '\some\data\folder\'
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
%   partially done on 08-04-2019 - Needs linking to other path functions
%
% See also 
%

function [filepath, folder_path, file, n_plus1, n_plus2] = adjust_pathnames(path)
    %% Quick correction if you used '\', which you should never use anyway
    % This also removes double //
    path = strrep(path,'\','/'); % Correct folder name for mac compatibility
    path = strrep(path,'//','/');
    parts = strsplit(path, '/');
    
    %% Check if we have a file or folder path
    if contains(parts(end),'.')  && ~exist(parts{end}, 'dir') 
        %% File
        % Will only fail if the last foldername contains a '.' and does
        % not already exist. Anyway, don't put dot in foldernames.
        file = parts{end};
        filepath = strjoin(parts,'/');  
        parts = parts(1:end-1);
    else
        %% Folder
        file = '';
        filepath = '';
        if isempty(parts{end})
            parts = parts(1:end-1);
        end
    end
    
    %% Now get folder N, N-1 and N-2 for absolute path. Do nothing for relative paths
    if ~isempty(parts) && ~contains(parts{1},'~')
        folder_path = strcat(strjoin(parts,'/'),['/']); % data folder
        n_plus1 = strcat(strjoin(parts(1:end-1),'/'),['/']); % expe folder
        n_plus2 = strcat(strjoin(parts(1:end-2),'/'),['/']); % parent folder
    else
        folder_path = strjoin(parts,''); % relative data folder
        n_plus1 = ''; % expe folder
        n_plus2 = ''; % parent folder
    end
end
