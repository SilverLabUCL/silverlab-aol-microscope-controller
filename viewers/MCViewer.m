%% Read FIFO, display or log MC correction data.
% 
% Type doc function_name or help function_name to get more details about
% the function inputs and outputs.
% -------------------------------------------------------------------------
% Syntax: 
%   this = MCViewer(plot, name_suffix)
% -------------------------------------------------------------------------
% Class Generation Inputs:
%   plot (BOOL) - Optional - default is false
%                           If true, data is displayed, if false, data is
%                           logged in a file
%
%   name_suffix (STR) - Optional - default is ''
%                           filename suffix when writing log in file. 
% -------------------------------------------------------------------------
% Outputs: 
%   this (MCViewer object)
%       The MCViewer object reads some of the FIFO fields related to MC in 
%       the background, and display or write them in a log file
% -------------------------------------------------------------------------
% Class Methods: 
%
% * Update MCViewer using FIFO data / provided values
%   MCViewer.update(var1, var2, var3, var4, var5, var6)
%
% * Reset MCViewer data counter (for display)
%   MCViewer.reset()
%
% * Display RT-3DMC in real time, by reading FIFO values
%   MCViewer.plot_mc_log(controller)
%
% * Update MCViewer currently data (for display)
%   MCViewer.update_data_array(controller, var1, var2, var3, var4, var5, var6)
%
% * Delete MCViewer, close figure or stop writing log file and close
%   MCViewer.delete()
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
% See also: movement_correction, initialise_timed_image, imaging



classdef MCViewer < handle 
    properties
        fig;
        axes;
        max_length = 500;
        current_var1 = []
        current_var2 = []
        current_var3 = []
        current_var4 = []
        current_var5 = []
        current_var6 = []
        current_point = 1;
        file
        filename
        lx
        ly
        lz
        
        plotting_point_frequency = 20;
        type = 'MC_viewer';   % The viewer type, as read in the BaseViewer superclass
        init = true;
        p1;p2;p3;p4;p5;p6;t1;t2;
        title1,title2,title5
        current_rms = 0;
        plot
    end
    
    methods
        function obj = MCViewer(plot, name_suffix)
            %% If plot is false, then log data in a file
            if nargin < 1
                obj.plot = false;
            else
                obj.plot = plot;
            end
            if nargin < 2
                name_suffix = '';
            end
            
            obj.current_var1 = zeros(1,obj.max_length);
            obj.current_var2 = zeros(1,obj.max_length);
            obj.current_var3 = zeros(1,obj.max_length);
            obj.current_var4 = zeros(1,obj.max_length);
            obj.current_var5 = zeros(1,obj.max_length);
            obj.current_var6 = zeros(1,obj.max_length);           
            
            %% Create handle (figure or file)
            if obj.plot
            	obj.fig = figure(1004);
            else
                obj.fig = [];
                cl = clock();
                obj.filename = sprintf('%d_%d_%d-%d_%d_%d_MC_log_%s.txt',cl(1),cl(2),cl(3),cl(4),cl(5),round(cl(6)),name_suffix);
                obj.file = fopen(obj.filename, 'w' );
            end
            
            this.type = 'MC_viewer';
        end

        function update(obj, var1, var2, var3, var4, var5, var6)
            if ~isvalid(obj) && obj.plot
            	obj.delete
            end
            
            persistent controller
            if isempty(controller)
                controller = get_existing_controller_name(true);
            end

            if ~controller.viewer.plot_background_mc && exist('controller.viewer.log_background_mc','var') && ~controller.viewer.log_background_mc
                return
            end
            
            %% Receives or Read from CAPI 6 values (single values or arrays) 
            if nargin < 4
                var1 = single(controller.daq_fpga.capi.x_correction_X10)/10;
                var2 = single(controller.daq_fpga.capi.y_correction_X10)/10;
                var4 = single(controller.daq_fpga.capi.x_diff_X100)/100;
                var5 = single(controller.daq_fpga.capi.y_diff_X100)/100;
                if controller.daq_fpga.capi.Enable_ZMC
                    var3 = single(controller.daq_fpga.capi.z_correction_X100)/100;
                    var6 = single(controller.daq_fpga.capi.z_diff_X100)/100;
                else
                    var3 = NaN;
                    var6 = NaN;
                end
            end

%             if ~mod(obj.current_point,obj.plotting_point_frequency)
%                 obj.current_rms = sum([       rms(obj.current_var4(end-obj.plotting_point_frequency+2:end)),...
%                                               rms(obj.current_var5(end-obj.plotting_point_frequency+2:end)),...
%                                               rms(obj.current_var6(end-obj.plotting_point_frequency+2:end))]);  
%             end

            %% Software auto_relock
            if controller.daq_fpga.mc_auto_relock
                xy = max(abs(controller.daq_fpga.capi.x_correction_X10), abs(controller.daq_fpga.capi.y_correction_X10));
                z = int16(controller.daq_fpga.Z_Lines) * abs(controller.daq_fpga.capi.z_correction_X100);
                if controller.daq_fpga.is_correcting && (xy == 1280 || z == 12800)
                    controller.pause_resume_MC(false) ; pause(0.01);
                end
%                 if controller.daq_fpga.is_correcting && (~controller.daq_fpga.capi.x_correction_X10 || ~controller.daq_fpga.capi.z_correction_X100)
%                     controller.pause_resume_MC(true)
%                 end
            end
            

            %% Update figure when using a viewer
            if obj.plot && isvalid(obj) && ~isempty(obj.fig)
                %% Reset array
                if obj.current_point >= obj.max_length - numel(var1)
                    obj.current_point = 1;
                    cla();
                    obj.init = true;
                end
                
                %% Read new values
                if obj.current_point == 1
                    obj.current_var1 = var1;
                    obj.current_var2 = var2;
                    obj.current_var4 = var4;
                    obj.current_var5 = var5;
                    if controller.daq_fpga.capi.Enable_ZMC
                        obj.current_var3 = var3;
                        obj.current_var6 = var6;
                    end
                end                
                
                %% Initialise plot if necessary
                if obj.init
                    obj.plot_mc_log(controller);
                end
                
                %% Update data arrays
                obj.update_data_array(controller, var1, var2, var3, var4, var5, var6);

                %% Plot data every plotting_point_frequency points
                if ~mod(obj.current_point,obj.plotting_point_frequency)
                    f = gcf();
                    if ~isvalid(obj.fig) || f.Number ~= 1004
                        obj.fig = figure(1004);
                    end
                    
                    try
                        obj.p1.YData = obj.current_var1;
                        obj.title1.String = num2str(max(obj.current_var1) - min(obj.current_var1));
                        obj.p2.YData = obj.current_var2;
                        obj.title2.String = num2str(max(obj.current_var2) - min(obj.current_var2));
                        obj.p3.YData = obj.current_var4;
                        obj.p4.YData = obj.current_var5;
                        xm = mean(obj.current_var4);
                        obj.lx(1).YData = [xm-1,xm-1];
                        obj.lx(2).YData = [xm+1,xm+1];
                        ym = mean(obj.current_var5);
                        obj.ly(1).YData = [ym-1,ym-1];
                        obj.ly(2).YData = [ym+1,ym+1];
 
                        if controller.daq_fpga.capi.Enable_ZMC
                            obj.p5.YData = obj.current_var3;
                            obj.title5.String = num2str(max(obj.current_var3) - min(obj.current_var3));
                            obj.p6.YData = obj.current_var6;
                            zm = mean(obj.current_var6);
                            obj.lz(1).YData = [zm-1,zm-1];
                            obj.lz(2).YData = [zm+1,zm+1];
                        end
                        
                        obj.t1.String = ['Var =',num2str(obj.current_rms)];
                        
                    end
                    drawnow limitrate
                end

                %% Prepare next plot
                obj.current_point = obj.current_point + numel(var1);
                
            elseif isvalid(obj) % When logging
                cl = clock();
                if controller.daq_fpga.capi.Enable_ZMC
                    fprintf(obj.file, sprintf('%d:%d:%2.3f\t%d\t%d\t%d\t%d\t%d\t%d\t\n',cl(4),cl(5),cl(6),var1,var2,var3,var4,var5,var6));
                else
                    fprintf(obj.file, sprintf('%d:%d:%2.3f\t%d\t%d\t%d\t%d\t\n',cl(4),cl(5),cl(6),var1,var2,var4,var5));
                end
                obj.current_point = obj.current_point + 1;
            end
        end
       
        function reset(obj)
            obj.current_point = 1;
            %obj.fig = figure(1004);
            %cla();
        end
        
        function plot_mc_log(obj, controller)
            f = gcf();
            
            if nargin < 2 || isempty(controller)
                controller = get_existing_controller_name(true);
            end
            
            try
                if ~isvalid(obj.fig) || f.Number ~= 1004
                    obj.fig = figure(1004);
                end

                n_subplot = 2 + double(controller.daq_fpga.capi.Enable_ZMC);

                subplot(n_subplot,2,1); hold on;
                cla();hold on;
                obj.p1 = plot(obj.current_var1, 'b');
                obj.title1 = title(num2str(mean(obj.current_var1)));
                subplot(n_subplot,2,3); hold on;
                cla();hold on;
                obj.p2 = plot(obj.current_var2, 'r');
                obj.title2 = title(num2str(mean(obj.current_var2)));

                subplot(n_subplot,2,2); hold on;
                cla();hold on;
                obj.p3 = plot(obj.current_var4, 'b');
                obj.lx = plot([1,obj.max_length;1,obj.max_length]',[obj.current_var4-1,obj.current_var4-1;obj.current_var4+1,obj.current_var4+1]','--');
                obj.t1 = title('Score');

                subplot(n_subplot,2,4); hold on;
                cla();hold on;
                obj.p4 = plot(obj.current_var5, 'r');
                obj.ly = plot([1,obj.max_length;1,obj.max_length]',[obj.current_var5-1,obj.current_var5-1;obj.current_var5+1,obj.current_var5+1]','--');

                if controller.daq_fpga.capi.Enable_ZMC
                    subplot(n_subplot,2,5); hold on;
                    cla();hold on;
                    obj.p5 = plot(obj.current_var3, 'k');
                    obj.title5 = title(num2str(mean(obj.current_var3)));

                    subplot(n_subplot,2,6); hold on;
                    cla();hold on;
                    obj.p6 = plot(obj.current_var6, 'k');
                    obj.lz = plot([1,obj.max_length;1,obj.max_length]',[obj.current_var6-1,obj.current_var6-1;obj.current_var6+1,obj.current_var6+1]','--');
                end

                obj.init = false;
            end
        end
        
        function update_data_array(obj, controller, var1, var2, var3, var4, var5, var6)
            obj.current_var1(obj.current_point:obj.current_point + numel(var1) - 1) = var1;
            obj.current_var2(obj.current_point:obj.current_point + numel(var2) - 1) = var2;
            obj.current_var4(obj.current_point:obj.current_point + numel(var4) - 1) = var4;
            obj.current_var5(obj.current_point:obj.current_point + numel(var5) - 1) = var5;
            if controller.daq_fpga.capi.Enable_ZMC
                obj.current_var3(obj.current_point:obj.current_point + numel(var3) - 1) = var3;
                obj.current_var6(obj.current_point:obj.current_point + numel(var6) - 1) = var6;
            end
        end
        
        
        function delete(obj)
            if ~isempty(obj.fig) && isvalid(obj.fig)
                delete(figure(1004));
                %stop(timerfind('Name','background_mc_plot'));
            elseif exist(obj.filename, 'file')
                fclose(obj.file);
            end
        end
    end    
end

