%% Scan the current frame multiple times and return the averaged result
%
% -------------------------------------------------------------------------
% Syntax: 
%   averaged_data = get_averaged_data(controller, averages, plot, init, reuse_viewer, method)
%
% -------------------------------------------------------------------------
% Inputs: 
%   controller(Controller object) - Optional - Default is main Controller:
%                                   Contains information about the
%                                   microscope setup such as FOV, dwell
%                                   time etc...
%
%   averages(INT) - Optional - Default is 0:  
%                                   The number of extra frames to get for 
%                                   the average. 0 for no averages.
%
%   plot(BOOL) - Optional - Default is true:  
%                                   If true, the final averged image is 
%                                   displayed.
%
%   init(BOOL) - Optional - Default is true:  
%                                   If true, shutter is openened at the
%                                   beginning and close at the end.
%
%   reuse_viewer(BOOL) - Optional - Default is false:  
%                                   If true, the viewer is not regenerated
%                                   (but will still be reset). You must be
%                                   sure that the data resolution or the
%                                   recroding duration is not changing (for
%                                   example, between each plane of a
%                                   Zstack).
%
%   method(STR) - Optional - Default is 'mean' ; any in {'mean','max',
%                            'median','min','var'}
%                                   Define the function to use if you get
%                                   more than one frame.
%
% -------------------------------------------------------------------------
% Outputs:
%   averaged_data        image
% 	stack([X * Y * NChannels] UINT16) : 
%                                   The output averaged image
%
% -------------------------------------------------------------------------
% Extra Notes:
%   Make sure you sent the new drives before calling the function
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
%   07-02-2018
%
% See also: controller.imaging, preview_at_any_z, controller.single_record
%

% TODO : 
%- Check if we need to resend drives

function averaged_data = get_averaged_data(controller, averages, plot, init, reuse_viewer, method)
    if nargin < 1 || isempty(controller),   controller = get_existing_controller_name(true);    end
    if nargin < 2 || isempty(averages),     averages = 0;                                       end
    if nargin < 3 || isempty(plot),         plot = true;                                        end
    if nargin < 4 || init == true,          controller.initialise();                            end
    if nargin < 5 || isempty(reuse_viewer), reuse_viewer = false;                               end
    if nargin < 6 || isempty(method),       method = 'mean';                                    end

    single_rectangle = numel(unique(controller.scan_params.voxels_for_ramp)) == 1;

    if controller.scan_params.imaging_mode == ImagingMode.Pointing %I added tha hack
        res_x = controller.scan_params.num_drives;
        res_y = controller.scan_params.num_drives;
    elseif single_rectangle
        res_x = controller.scan_params.voxels_for_ramp(1);
        res_y = controller.scan_params.num_drives;
    else
        res_x = sum(controller.scan_params.voxels_for_ramp);
        res_y = 1;
    end

    averaged_data = controller.single_record(averages, reuse_viewer, method);

    if plot   
        if single_rectangle
            figure(); hold on;
            subplot(1,2,1); imagesc(averaged_data(:,:,1)); hold on;
            colormap('gray'); axis image; hold on;
            subplot(1,2,2); imagesc(averaged_data(:,:,2)); hold on; 
            colormap('gray'); axis image;
        end
    end

    if nargin < 4 || init == true && ~controller.daq_fpga.is_correcting
        controller.finalise();
    end

end