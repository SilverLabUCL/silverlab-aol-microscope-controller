%% Use an image to select the coordinates of a ROI (for MC or miniscans)
%
% -------------------------------------------------------------------------
% Syntax: 
% [miniscan_ROI, ref_channel, absolute_z_for_ref] = 
%           select_ROI( controller, suggested_ROI, ROI_size, channel,
%                       image, inpar)
%
% -------------------------------------------------------------------------
% Inputs: 
%   controller(Controller object) - Optional - Default is main Controller:
%                                   Contains information about the
%                                   microscope setup such as FOV, dwell
%                                   time etc...
%
%   suggested_ROI([3 X 1 INT] OR []) - Optional - Default is [0, 0, 0]:
%                                   The coordinates where the ROI will
%                                   appear on the preview. If value is [0,
%                                   0, 0], then the coordinates will be set
%                                   at the center of the FOV. Value is in
%                                   pixels
%
%   ROI_size(INT) - Optional - Default is 18:
%                                   The size of the initially displayed ROI
%                                   (in pixels)
%
%   channel(INT) - Optional - Default is 1:
%                                   The channel displayed initially.
%
%   image([N X M X Ch] INT) - Optional - Default will take an average of 4 
%       frames using current drives;
%                                    The image to display fr the ROI
%                                    selection
%
%   inpar({1 X 5} Cell array) - Optional - Default []
%                                   A set of values used to renerate frames
%                                   and change Z. Cell array must contain
%                                   (in the right order)
%                                   - absolute_z_for_ref
%                                   - non_default_resolution
%                                   - non_default_aa
%                                   - non_default_dwelltime
%                                   - non_default_pockel_voltages
%                                   Inputs are passed to
%                                   get_averaged_data(), so see 
%                                   documentation for mre details.
%
%   Z_step_size(FLOAT) - Optional - Default is 1
%                                   The size of the Z steps in um when
%                                   clicking Up or Down
% 
% -------------------------------------------------------------------------
% Outputs:
%   miniscan_ROI([6 X 1 INT] OR []) :
%                                   The coordinates of the selected ROI. If
%                                   you cancelled the process, we return
%                                   [].
%                                   If a ROI was selected, format is
%                                   [Xstart, Ystart, Xstop, Ystop, Xsize,
%                                   Ysize]
%
%   ref_channel(INT):
%                                   The channel to use for the reference (1
%                                   or 2). The value can differ from the 
%                                   input if you changed it in the frame
%                                   selection menu.
%
%   absolute_z_for_ref(FLOAT OR []):
%                                   The stage absolute plane where the
%                                   reference is was selected. The value
%                                   can differ from the input if you
%                                   changed it in the frame selection menu.
%                                   If you cancelled the process, we return
%                                   [].
% -------------------------------------------------------------------------
% Extra Notes:
% * Full frame uses a 50ns dwell time to maximise the FOV at remote Z. The
%   purpose of that step is to find the location of the ROI, which is 
%   better done a short dwell time. The Miniscan preview, for threshold 
%   selection is done at the desired dwell time, and should give a porper
%   estimate of the brightess of the sample.
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
%   14-03-2019
%
% See also: preview_at_any_z, prepare_MC_miniscan, get_averaged_data,
%   select_MC_thr 

function [miniscan_ROI, ref_channel, absolute_z_for_ref] = select_ROI(controller, suggested_ROI, ROI_size, ref_channel, image, input_params, Z_step_size)
    if nargin < 1 || isempty(controller)
        controller = get_existing_controller_name(true);
    end
    if nargin < 2 || isempty(suggested_ROI)
        suggested_ROI = [controller.scan_params.mainscan_x_pixel_density/2 controller.scan_params.mainscan_x_pixel_density/2 0];
    end
    if nargin < 3 || isempty(ROI_size)
        ROI_size = 18;
    end
    if nargin < 4 || isempty(ref_channel)
        ref_channel = 1;
    end
    if nargin < 5 || isempty(image)
        image = get_averaged_data(controller, 4, false, true);
    end
    if nargin < 6 || isempty(input_params) || numel(input_params) ~= 5
        input_params = [];
    end
    if nargin < 7 || isempty(Z_step_size)
        Z_step_size = 1;
    end
    
    %% Set default ouputs 
    miniscan_ROI = [];
    absolute_z_for_ref = [];

    %% Create the ouput variable
    global result
    result = {};
    result.inpar = input_params;
    result.data = image;
    result.window_pos = [suggested_ROI(1), suggested_ROI(2), suggested_ROI(1)+ROI_size, suggested_ROI(2)+ROI_size, ROI_size, ROI_size]; % default value in case the user is not moving the ROI
    result.roi = [round(suggested_ROI(1)-ROI_size/2) round(suggested_ROI(2)-ROI_size/2) ROI_size ROI_size];
    result.channel = ref_channel;
    result.valid = 0;
    result.step = Z_step_size; 
    
    %% Generate figure (and store handle)
    result.f = figure(1050);hold on;
    clf();hold on;
    title(mat2str(result.roi,3));hold on;
    result.f2 = imagesc(result.data(:,:,ref_channel));set(gca,'YDir','reverse');hold on; %reverse Y to match axis direction with live viewer
    axis image;hold on;
    set_selection_square();
    
    %% Add buttons
    uicontrol('Style', 'pushbutton', 'String', 'Cancel', 'Position', [500 20 50 30], 'Callback', @(src,eventdata) cancel(src,eventdata));
    uicontrol('Style', 'pushbutton', 'String', 'Ok', 'Position', [500 50 50 30], 'Callback', @(src,eventdata) ok(src,eventdata));

    %% If you provided enough information, add AOL Z navigation controls
    if ~isempty(input_params)
        uicontrol('Style', 'pushbutton', 'String', 'Refresh', 'Position', [490 210 70 30], 'Callback', @(src,eventdata) refresh(src,eventdata,controller));
        uicontrol('Style', 'pushbutton', 'String', 'up 1 µm', 'Position', [490 180 70 30], 'Callback', @(src,eventdata) up(src,eventdata,controller));
        uicontrol('Style', 'pushbutton', 'String', 'down 1 µm', 'Position', [490 150 70 30], 'Callback', @(src,eventdata) down(src,eventdata,controller));
        uicontrol('Style', 'edit', 'String', num2str(Z_step_size), 'Position', [490 240 70 20], 'Callback', @(src,eventdata) change_step(src,eventdata));
        uicontrol('Style', 'text', 'String', 'AOL Z steps size', 'Position', [465 260 100 20]);
    end
    
    %% If there is more than 1 channel, allow the channel to change
    if size(result.data,3)  > 1
        uicontrol('Style', 'popup', 'String', {'1','2'}, 'Value', ref_channel, 'Position', [500 100 50 30], 'Callback', @(src,eventdata) change_channel(src,eventdata));
    end 
    
    %% Now wait until figure is closes (through validation or closure)
    uiwait(result.f);
    
    %% If you ended with a valid selection
    % i.e. If window not closed and selection not cancelled
    if result.valid && ~any(isnan(result.window_pos))
        drawnow; pause(0.1);
        
        %% Get the ROI limits
        if size(result.roi,1) > 0 && ~isnan(result.window_pos(1)) %if user moved the roi, else we keep the default
            result.window_pos = round([result.roi(1) result.roi(2) result.roi(1)+result.roi(3) result.roi(2)+result.roi(4) result.roi(3) result.roi(4)]);
        end
        miniscan_ROI = result.window_pos;
        
        %% If we are using Z AOL navigaton, return any updated Z
        if ~isempty(result.inpar)
            absolute_z_for_ref = result.inpar{1}; %empty or a new absolut Z
        end
        
        %% Get the right channel
        ref_channel = result.channel;
    else % If cancelled
        miniscan_ROI = [];
        absolute_z_for_ref = [];
    end
    
    %% Clear global
    clear global result;
end

function cancel(~,~)
    %% User click on Cancel Button
    global result
    close(result.f);
    result.window_pos = nan;
end

function ok(~,~)
    %% User click on Ok Button
    global result
    result.valid = 1;
    close(figure(1050));
end

function refresh(source, ~, controller)
    %% User click on Refresh Button
    global result
    
    %% Prevent further clicks
    source.Enable = 'off';

    %% Get frame
    update_frame(controller, 0);
    
    %% Allow new clicks
    source.Enable = 'on';
end

function change_step(source, ~)
    %% User changes Z Step Value
    global result
    result.step = str2num(source.String);
    result.f.Children(4).String = ['down ',source.String,' µm'];
    result.f.Children(5).String = ['up ',source.String,' µm'];
end

function up(source, ~, controller)
    %% User click on Up Button
    global result
    
    %% Prevent further clicks
    source.Enable = 'off';

    %% Get frame
    update_frame(controller, result.step);
    
    %% Allow new clicks
    source.Enable = 'on';
end

function down(source,~,controller)
    %% User click on Down Button
    global result
    
    %% Prevent further clicks
    source.Enable = 'off';

    %% Get frame
    update_frame(controller, -result.step);
    
    %% Allow new clicks
    source.Enable = 'on';
end

function change_channel(source,~)
    global result
    
    %% Read channel and update data
    result.channel = source.Value;
    image = result.data(:,:,result.channel);
    result.f2 = imagesc(image);hold on;
    caxis([min(image(:)),max(image(:))]);hold on;
    
    %% Reset selection square
    set_selection_square();
end

function set_selection_square()
    %% Setup a ROI selection square
    global result
    result.h = imrect(gca, result.roi);hold on;
    result.h.addNewPositionCallback(@(p) read(p));hold on;
    
    %% Force ROi as square 
    % qq we may want to change that 
    fcn = makeConstrainToRectFcn('imrect',get(gca,'XLim'),get(gca,'YLim'));hold on;
    setPositionConstraintFcn(result.h,fcn); hold on;
    setFixedAspectRatioMode(result.h,1);hold on;
end

function read(p)
    %% Read current ROI location and size
    title(mat2str(p,3));
    global result
    result.roi = p;  
end

function update_frame(controller, step)
    %% Get new frame at specified location
    global result
    
    %% Update Z location
    result.inpar{1} = result.inpar{1} + step;
    
    %% Get new frame
    result.data = preview_at_any_z( controller,...
                                    result.inpar{1},...
                                    result.inpar{2},...
                                    result.inpar{3},...
                                    result.inpar{4},...
                                    result.inpar{5});
                                
    %controller.reset_frame_and_send('raster',controller.scan_params.mainscan_x_pixel_density,controller.scan_params.acceptance_angle);
    
    %% Update selection window
    f = figure(1050); hold on;
    delete(findobj(f,'Type','Image','-depth',inf));hold on;
    delete(findobj(f,'Type','hggroup','-depth',inf));hold on;
    result.f2 = imagesc(result.data(:,:,result.channel));
    drawnow
    
    %% Reset selection square
    set_selection_square() %qq - We could keep the square where it was
end
