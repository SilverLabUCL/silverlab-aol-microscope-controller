%% Display a stack, 3D timelapses or video in the defined viewer
%   Display 3D stacks, 3D timeseries or single/multichannel Z stack in a
%   matlab or vaa3d 3D viewer.
%
%   Timelapses are automatically detected using this function, however if
%   you require smoothing, use show_vaa3d_3D_timelapse() instead
% -------------------------------------------------------------------------
% Syntax: 
%   show_stack(data, viewer, vaa3D_folder)
%
% -------------------------------------------------------------------------
% Inputs: 
%   data(STR Path OR [X * Y * C] OR [X * Y * Z_or_T * C] OR 
%        [X * Y * Z * T * C] FLOAT):
%                                   - If STR Path, it must be a path to a
%                                   datatype that can be loaded by
%                                   load_stack. Mostly tif, v3draw or avi
%                                   files.
%                                   - If you prove a matrix, it will be
%                                   display with the appropriate rendering
%                                   options. 3D timelapses need vaa3d for
%                                   rendering
%                                   
%   viewer(STR) - Optional - default is 'matlab', any in
%           {'matlab', 'gui', 'vaa3d'}
%                                   Defines the viewer used for data
%                                   rendering. If you use 'vaa3d' you must
%                                   provide the pat to the executable. £D
%                                   timelapses require vaa3d
%                                   
%   viewer(STR) - Required if viewer == 'vaa3d'
%                                   The path to the vaa3d excutable
% -------------------------------------------------------------------------
% Outputs:
%	data([X_res * Y_res * Z_res * timepoints * channels]) single array 
%                                   The data as formated by the function.
%                                   singletons are removed. This is only
%                                   useful if you passed a path initially.
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
%   14-06-2019
%
% See also: load_stack, show_vaa3d_3D_timelapse

function data = show_stack(data, viewer, vaa3D_folder)
    %% Adjust inputs
    if nargin < 2 || isempty(viewer)
        viewer = 'matlab';
    end
    viewer = lower(viewer);
    if nargin < 3 || isempty(vaa3D_folder)
        vaa3D_folder = '';
    end
    if isempty(vaa3D_folder) && strcmp(viewer,'vaa3d')
        f = folder_params(1);
        vaa3D_folder = f.vaa3D_folder;
    end
    
    %% If you provide a path, load the data before displaying it
    if (isstr(data) || isstring(data)) && isfile(data) 
        name = char(data);
        data = load_stack(name); 
    else % if stack is a numerical matrix 
        name = [pwd '/temp.v3draw']; 
    end
    
    %% Detect data type
    data = squeeze(data); 
    if ndims(data) == 5 || (ndims(data) == 4 && size(data, 4) > 3)
        %% Necessarily X * Y * Z * T * C. C can be 1
        % Data will go through a temporary vaa3d file
        type = '3d_timelapse';
        viewer = 'vaa3d';
    elseif ndims(data) == 4 || (ndims(data) == 3 && size(data, 3) > 3) || contains(name, 'Stack')
        %% Necessarily X * Y * Z_or_T * C. C can be 1
        type = '3d_stack_or_2d_timelapse';
    else
        %% Necessarily X * Y * C. C can be 1
        type = 'image';
        data = reshape(data, size(data, 1), size(data, 2), 1, size(data, 3));
    end
    
    %% Load data for each viewer type
    switch viewer
        case 'vaa3d'
            if contains(name,'.mat') || strcmp(name,[pwd '/temp.v3draw']) % temporarily save the stack as a v3draw file
                name = save_stack(data, [pwd '/temp.v3draw']);
            end

            if strcmp(type,'3d_stack_or_2d_timelapse')
                name = fix_vaa3d_path(name);
                vaa3D_folder = fix_vaa3d_path(vaa3D_folder);
                evalc('system(sprintf(''%s /i %s /v'', vaa3D_folder, name))'); % If code hangs here, you probably have a wrong vaa3d path in your config files
            else
                show_vaa3d_3D_timelapse(name);
            end

        case 'gui'
            Stack_Viewer(data);
            
        case 'matlab'
            num_planes = size(data,3);
            num_channels = size(data,4);
            
            if num_channels > 3
                error_box('only up to 3 channels are supported')
            elseif num_channels == 3 && ~any(reshape(data(:,:,:,3),[],1))
                num_channels = 2;
            end

            %% Create one subplot per channel
            f = figure(1011); hold on;
            cla();hold on
            f.Name = 'Close figure to continue function'; hold on
            subplot(1,num_channels,1); 
            im1 = imagesc(data(:,:,1,1)); hold on;
            colormap('gray'); axis image; hold on;
            t1 = title(sprintf('Channel 1 ; plane %d',1));hold on;
            if num_channels > 1
                subplot(1,num_channels,2);hold on; 
                im2 = imagesc(data(:,:,1,2)); hold on;        
                colormap('gray'); axis image; hold on;
                set(gca,'YDir','reverse');
                t2 = title(sprintf('Channel 2 ; plane %d',1));hold on;
                if num_channels > 2
                    subplot(1,num_channels,3);hold on; 
                    im3 = imagesc(data(:,:,1,3)); hold on;        
                    colormap('gray'); axis image; hold on;
                    t3 = title(sprintf('Channel 3 ; plane %d',1));hold on;
                end
            end

            %% Now display each plane in loop until window is closed
            while isvalid(f)
                for plane_num = 1:num_planes
                    if isvalid(f)
                        im1.CData = data(:,:,plane_num,1); hold on;
                        t1.String = sprintf('Channel 1 ; plane %d',plane_num);hold on;
                        if num_channels > 1
                            im2.CData = data(:,:,plane_num,2); hold on;
                            t2.String = sprintf('Channel 2 ; plane %d',plane_num);hold on;
                            if num_channels > 2
                                im3.CData = data(:,:,plane_num,3); hold on;
                                t3.String = sprintf('Channel 3 ; plane %d',plane_num);hold on;
                            end
                        end
                        drawnow;
                    else
                        break
                    end
                end
            end
    end

    %% Remove any temporary file
    if exist(name,'file') && strcmp(viewer,'vaa3d')%final cleaning
        if strcmp(name(end-10:end),'temp.v3draw')
            delete(name);
        end
    end
end

