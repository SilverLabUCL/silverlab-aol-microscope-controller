%% Subclass of BaseViewer for Live rendering rendering of frames
% 
% Type doc function_name or help function_name to get more details about
% the function inputs and outputs.
% -------------------------------------------------------------------------
% Syntax: 
%   this = LiveViewer(  x, y, buffer_size, viewer_preset,
%                       intensity_bar, gui, n_averages)
% -------------------------------------------------------------------------
% Class Generation Inputs:
%   x (INT) - Optional - default is 512
%       The x resolution of the frame
%
%   y (INT) - Optional - default is 512
%       The y resolution of the frame
%
%   buffer_size (INT) - Optional - default is [512,512]
%       x * y 
%
%   viewer_preset (INT) - Optional - default is 1
%       The initial viewer presets to use in viewer_params. Typically
%       controller.gui_handles.viewer_mode (called from create_viewer.m)
%       unless specified otherwise
%
%   intensity_bar (BOOL) - Optional - default is true
%       Default is true. Plot the max brightness in real time. Use
%       this display if you want to know if PMTs are close to saturation.
%
%   gui (BOOL) - Optional - default is false
%
%   n_averages (INT) - Optional - default is 1
%       The number of frames to average 
% -------------------------------------------------------------------------
% Outputs: 
%   this (DataHolder object)
%       The DataHolder object with Triggers and preallocated memory for
%       data collection.
% -------------------------------------------------------------------------
% Class Methods: 
%
% * Update DataHolder.data0 and DataHolder.data1 with new data
%   LiveViewer.update(new_data0, new_data1)
%
% * Reshape the data in the format defined by this.data_size and average trials.
%   data = LiveViewer.reshape_and_average()
%
% * Reset DataHolder buffer.
%   LiveViewer.reset()
%
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
%   16-03-2020
%
% See also
%   BaseViewer, viewer_params

%% TODO
% gui input can be removed
% some propeties to move between here and viewer params

classdef LiveViewer < viewer_params & BaseViewer
    properties
        %% Figure handles
        plt                     ; %
        bar                     ; % Power lavel bar handle
        ax1                     ; %   
        ax2                     ; %
        
        %% Rendering options
        current_nb_of_gridlines=0;% Number of lines to plot on top of the image
        intensity_bar   = true  ; % If true, display channel 1/2 intensity
        gui             = false ; % gui handle if passed during
        cross                   ; % If true, display gridlines

        %% Image
        data                    ; % Data currently displayed
        holder0                 ;
        holder1                 ;
        num_pixels              ; % number of pixels per frame
        data_size               ;
        
        %% Image correction
        zeroed_frame            ;
        flat_field              ;
        greenmax        = 0     ;
        redmax          = 0     ; 
        XDir            = 'normal'; % 'normal' for standard matlab display
        YDir            = 'reverse'; % 'reverse' for standard matlab display
        rotate          = false; % Flip X and Y
        mirror          = true;  % Mirror X-axis
        
        %% Indexing
        next_elem0      = 1     ;
        next_elem1      = 1     ;
        idx0            = 0     ;
        idx1            = 0     ;
        
        %% Counter and timers
        timer1          = []    ;
        timer2          = []    ;
        current_frame   = -1    ; % frame counter
        
        preset_mode     = []    ; % Load a specific set of settings from viewer_params
        refresh_limit   = 0     ; % Defines when the displayed frame is refreshed
                                  % if mode == 'time_average' , refresh_limit is a time is s
                                  % if mode == 'frame_average', refresh_limit is a number of frames 
        frame_duration  = 0     ; %
        mode            = 'none'; % Define metric used in refresh_limit for averaging
                                  % 'none' : No average; 
                                  % 'time_average' : a timer defines refresh rate
                                  % 'frame_average': a frame counter define refresh rate 
        sliding         = false ; % use sliding frame average or not
        refresh_scaling_factor = 1; % used to scale time into frames
        
        %% Extra Flags
        type            = 'live_image';
    end

    methods
        function this = LiveViewer(x, y, buffer_size, viewer_preset, intensity_bar, gui, refresh_limit)
            if nargin < 1 || isempty(x)
                x = 512;
            end
            if nargin < 2 || isempty(y)
                y = 512;
            end
            if nargin < 3 || isempty(buffer_size)
                buffer_size = [512,512];
            end
            if nargin < 4 || isempty(viewer_preset)
                viewer_preset = 1;
            end
            if nargin < 5 || isempty(intensity_bar)
               intensity_bar = true;
            end
            if nargin < 6 || isempty(gui)
                gui = false;
            end
            
            %% Set Frame properties (and frames indexes)
            this.num_pixels = x * y;
            this.data_size  = [x,y];
            this.data       = zeros(x, y, 3, 'uint16'); 
            this.zeroed_frame = zeros(x, y, 3, 'single'); %this blank frame will not be modified and can be used for a faster reset
            this.idx0       = zeros(1,buffer_size(1),'uint32'); % supports up to 65536 * 65536 pixels frames...
            this.idx1       = zeros(1,buffer_size(2),'uint32');
            
            %% Adjust frame rate and buffer size
            this.preset_mode = viewer_preset;
            if nargin < 7 || isempty(refresh_limit) || refresh_limit <= 0
                this.refresh_limit = 0;
                this.mode = 'none';
                this.sliding = false;
            else
                this.refresh_limit = refresh_limit;
            end
            this.gui = gui;  
            
            %% Add Optional intensity bar
            this.intensity_bar = intensity_bar;
            if this.intensity_bar
                a = 1:100;a = a(~ismember(a,0:10:100));
                this.ax1 = subplot(10,10,a);hold on;
            end
            
            %% Initiate figure
            if this.gui && isempty(this.plt)
                this.plt = figure(1000);
            end
            this.plt = imagesc(zeros(y, x, 3,'uint16'),'CDataMapping','direct'); hold on;
            this.plt.Parent.YDir = this.YDir;
            this.plt.Parent.XDir = this.XDir;
            if this.mirror
                set(gca,'xdir','reverse')
            end
            colormap(gray); hold on;
            axis image; hold on;
            set(gcf,'doublebuffer','off','NextPlot','replacechildren');
            pbaspect([x/x, x/y, 1]);
            this.cross = x / 2 + [0, 1];
            
            %% Add optional intensity bar
            if intensity_bar
                this.ax2 = subplot(10,10,10:10:100);hold on;
                this.bar = bar([10000,10000]);ylim([0,2^15]);
            end
        end
        
        function update(this, new_data0, new_data1, data2, roi_size)
            %% Initial checks
            n_frame_limit = uint16(round(this.refresh_limit * this.refresh_scaling_factor));
            if isempty(this.idx0)
                this.idx0 = 0;
            end
            
            %% Once we finished any kind of averaging, we reset the frame
            % If we were averaging we reset the frame and the counters. It
            % should ideally be done at the end of the function, but it
            % would clear the data and prevent further access from another
            % function (through the CData field), which can be handy.
            if max(this.idx0) == this.num_pixels && this.current_frame >= n_frame_limit && (n_frame_limit > 1 || strcmp(this.mode, 'frame_average') || strcmp(this.mode, 'time_average'))
                 this.data = this.zeroed_frame;
                 this.current_frame = 0;
            end
 
            %% Generate bar object if required
            if this.intensity_bar && max(this.idx0) == this.num_pixels && this.current_frame >= n_frame_limit
               set(this.bar, 'YData', max([new_data0; new_data1])); hold on;
            end
            
            %% We adjust offset and contrast for each channel
            new_data0 = (new_data0 - this.red_offset)   / (1/this.red_contrast); 
            new_data1 = (new_data1 - this.green_offset) / (1/this.green_contrast);
            
            %% any data2(MC ROI) will be shown in blue in the top left corner
            if nargin > 3
            	this.data(1:roi_size(1),1:roi_size(2),3) = reshape(data2, roi_size(1), roi_size(2)); 
            end

            %% We update data indexes
            this.idx0 = uint32(mod(this.next_elem0 - 1 + uint32(1:numel(new_data0)) - 1, this.num_pixels) + 1); 
            this.idx1 = uint32(mod(this.next_elem1 - 1 + uint32(1:numel(new_data1)) - 1, this.num_pixels) + 1);
            this.next_elem0 = this.idx0(end) + 1; % This is the the next pixel location in the frame
            this.next_elem1 = this.idx1(end) + 1;

            %% We push the data at the right index location. If there is averaging, we add it to previous data
            if strcmp(this.mode, 'none') || ~n_frame_limit%no averaging 
                this.data(this.idx0) = new_data0; %1 to this.num_pixels is red
                this.data(this.idx1 + this.num_pixels) = new_data1; %(this.num_pixels + 1) to (this.num_pixels*2) is green
                %(this.num_pixels *2 + 1) to (this.num_pixels * 3) is blue
            elseif strcmp(this.mode, 'frame_average') || strcmp(this.mode, 'time_average')
                if ~this.sliding
                    this.data(this.idx0) = uint16(this.data(this.idx0)) + new_data0'/ n_frame_limit;
                    this.data(this.idx1 + this.num_pixels) = uint16(this.data(this.idx1 + this.num_pixels)) + new_data1' / n_frame_limit;
                else
                    this.holder0(this.idx0 + this.num_pixels * (this.current_frame)) = new_data0; %1 to this.num_pixels is red
                    this.holder1(this.idx1 + this.num_pixels * (this.current_frame)) = new_data1; 
                end
            end
            
            %% Every time we fill a frame, we increase the counter
            if max(this.idx0) >= this.num_pixels
                this.current_frame = this.current_frame + 1;
            end
            
            %% If we have a complete frame AND if we averaged enough frames or
            %% time, we display the result
            if ~mod(max(this.idx0),this.num_pixels) && (this.current_frame >= n_frame_limit || this.sliding)
                % We display a cross if wanted
                this.add_cross(); 

                if this.sliding && n_frame_limit
                    this.data(1:this.num_pixels)                    =    mean(this.holder0,3);
                    this.data(this.num_pixels+1:this.num_pixels*2)  =    mean(this.holder1,3);
                end
                
                if this.flatten_field %achieved with (acquired image - background) / (flatfield image - background)
%                     initial_max = single(max(this.data(:)));
                    this.data = uint16(single(this.data) ./ (single(this.flat_field )));
                end

                
                %% Rotate frame if required
                if this.rotate
                    this.data = rot90(this.data);
                end
                               
                %% Note because of an unidentified pb with fast viewer mode, the autocontrast is done only on 90% of the picture
                this.data = single(this.data);
                if this.auto_contrast_red
                    initial_max = prctile(reshape(this.data(:,ceil(this.data_size(1)/5):end,1),[],1),this.autocontrast_thr);
                    if initial_max > 2000 %qq  mitigates autocontrast issue
                        initial_max = 2000;
                    end
                    this.data(:,:,1) = (2^16 * this.data(:,:,1) / (initial_max/this.red_contrast));
                end
                if this.auto_contrast_green
                    initial_max = prctile(reshape(this.data(:,ceil(this.data_size(1)/5):end,2),[],1),this.autocontrast_thr);
                    if initial_max > 2000 %qq  mitigates autocontrast issue
                        initial_max = 2000;
                    end
                    this.data(:,:,2) = (2^16 * this.data(:,:,2) / (initial_max/this.green_contrast));
                end

                %% Plot frame. If contrast is 0 for one channel, plot only 1 color
                % Be aware that this.data was altered by contrast and 
                % recasting and do not represent the original data
                this.data = uint16(this.data);
                if ~this.green_contrast
                    set(this.plt, 'cdata', this.data(:,:,1));
                elseif ~this.red_contrast
                    set(this.plt, 'cdata', this.data(:,:,2));  %be aware that this.data was altered by contrast and recasting and do not represent the real values
                else
                    set(this.plt, 'cdata', this.data);  %be aware that this.data was altered by contrast and recasting and do not represent the real values
                end
                drawnow limitrate;
            end

        end
       
        function add_cross(this)
            if this.nb_of_gridlines && this.current_nb_of_gridlines ~= this.nb_of_gridlines
                this.ax1;
                lines = linspace(0,1,this.nb_of_gridlines+2);
                lines = lines(2:end-1);
                offset = diff(this.data_size); % for non square FOV (eg MC ref with Z lines on the left)
                for l = lines
                    line([this.data_size(1)*l this.data_size(1)*l],[0.5 this.data_size(1)+0.5],'Color','w');
                    line([0.5 this.data_size(2)+0.5],[(this.data_size(2)-offset)*l (this.data_size(2)-offset)*l],'Color','w');
                end
                this.current_nb_of_gridlines = this.nb_of_gridlines;
            end
        end
        
        function set.preset_mode(this, value)
            % update the viewer_params. If you use time average, you have
            % to set the frame duration
            this.preset_mode = value;
            this.update_params(value);
        end
        
        function set.refresh_limit(this, refresh_limit)
            this.refresh_limit = refresh_limit;
            this.set_refresh_limit();
        end
        
        function set.frame_duration(this, frame_duration)
            this.frame_duration = frame_duration;
        end
        
        function set.mode(this, mode)
            this.mode = mode;
            this.frame_duration = 0; % you must always recalculate frame_duration if you change mode.
            if strcmp(mode, 'time_average')
                controller = get_existing_controller_name(true);
                fps = controller.scan_params.get_fps(1, controller.mc_scan_params, double(controller.daq_fpga.MC_rate) * double(controller.daq_fpga.use_movement_correction));
                this.frame_duration = 1/fps;
            end
        end
        
        function set_refresh_limit(this)
            if strcmp(this.mode, 'frame_average') && this.refresh_limit < 0
                error('n frame per cycle must be > 0')
            elseif strcmp(this.mode, 'time_average')  && ~this.frame_duration
                error('frame duration must be > 0')
            end
            
            if strcmp(this.mode,'frame_average' ) || strcmp(this.mode,'none')
                this.refresh_scaling_factor = 1; % so this.refresh_limit IS a number of frame
            elseif strcmp(this.mode,'time_average')
                this.refresh_scaling_factor = 1/this.frame_duration; %so (this.refresh_limit * this.refresh_scaling_factor) is a number of frame        
            end
            this.regenerate_buffers(round(this.refresh_limit * this.refresh_scaling_factor));
        end

        function regenerate_buffers(this, n_frames)
            this.holder0 = zeros(this.data_size(1), this.data_size(2), n_frames+1, 'uint16');
            this.holder1 = zeros(this.data_size(1), this.data_size(2), n_frames+1, 'uint16');
        end
            
        function reset(this)
            this.next_elem0 = 1;
            this.next_elem1 = 1;
            this.data = this.zeroed_frame;
            %this.plt = figure(1000);
            %set(this.plt, 'cdata', get(this.plt, 'cdata')*0.5);
            this.current_frame = 0;
        end
    end
    
end

