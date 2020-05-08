%% SuperClass of LiveViewer controlling the rendering options
% LiveViewer class inherits these methods and properties
%
% Type doc function_name or help function_name to get more details about
% the function inputs and outputs
% -------------------------------------------------------------------------
% Syntax: N/A
% -------------------------------------------------------------------------
% Class Generation Inputs: N/A 
% -------------------------------------------------------------------------
% Outputs: N/A  
% -------------------------------------------------------------------------
% Class Methods (ignoring get()/set() methods):
%
% * Apply a parameter preset
%   obj.update_params(imaging_preset)
%    
% * Backup current viewer options
%   viewer_options = obj.get_current_parameters_set()
%
% * Apply backed up viewer options
%   obj.set_new_parameters_set(viewer_options)
%
% -------------------------------------------------------------------------
% Extra Notes:
% * These options are on top of the some of the LiveViewer options
%
% * Selected sttings affects the data contained in the CDATA field of the
%   figure.
%
% * the LiveViewer preset_mode property calls c.viewer.update_params
% -------------------------------------------------------------------------
% Examples: 
%
% * Update viewer parameters in Controller by loading preset # 1
%   c.viewer.update_params(1);
%
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
% See also
%   BaseViewer, LiveViewer
%


classdef viewer_params < handle
    properties
        red_contrast        = 1;
        green_contrast      = 1;
        red_offset          = 0;
        green_offset        = 0;
        nb_of_gridlines     = 0
        auto_contrast_red   = false;
        auto_contrast_green = false;
        autocontrast_thr    = 99.9;
        flatten_field       = false;
        colormap;
    end

    methods
        function this = viewer_params()  %imaging mode 0 must not be changed, as it is used for MC
            this.red_contrast   = 1;
            this.green_contrast = 1;
            this.colormap       = jet;
        end

        function this = update_params(this, imaging_preset)            
            %% Load viewer_params preset
            % -------------------------------------------------------------
            % Syntax: 
            %   LiveViewer.update_params(imaging_preset) 
            % -------------------------------------------------------------
            % Inputs:
            %   imaging_preset(INT) - Optional - default is 0
            %       If not 0, load one of the hardcoded preset  
            % -------------------------------------------------------------
            % Outputs:
            % -------------------------------------------------------------
            % Extra Notes:
            %       red_contrast - (FLOAT) - Default is 1
            %           Scaling factor used to adjust contrast in the red
            %           channel. Saturation value defined by
            %           autocontrast_thr.
            %           > 1 to increase contrast, < 1 to reduce it
            %
            %       green_contrast - (FLOAT) - Default is 1
            %           Scaling factor used to adjust contrast in the green
            %           channel. Saturation value defined by
            %           autocontrast_thr.
            %           > 1 to increase contrast, < 1 to reduce it
            %
            %       red_offset - (IT) - Default is 1
            %           Defines the value used as zero in the red channel. 
            %           Use the offset to clip background noise
            %
            %       green_offset - (FLOAT) - Default is 1
            %           Defines the value used as zero in the green channel. 
            %           Use the offset to clip background noise
            %
            %       mode - (STR) - Any in { 'none','frame_average',
            %                               'time_average'} - Default is 1
            %            Defines the type of unit used for frame averaging.
            %            - If 'frame_average', then refresh_limit is the
            %            number of frames to average
            %            - If 'time_average', then refresh_limit is the
            %            duration in s during which one we average frames.
            %
            %       refresh_limit - (FLOAT) - Default is 0
            %            - If 'frame_average', then refresh_limit is the
            %            number of frames to average
            %            - If 'time_average', then refresh_limit is the
            %            duration in s during which one we average frames.
            %
            %       colormap - (colormap or STR matchin a colormap) -
            %                   Default is jet
            %           Rendering colormap (under developement)
            %
            %       nb_of_gridlines - (INT) - Default is 0
            %           If value is > 0, draw a grid mesh with as many
            %           lines as nb_of_gridlines in X and Y.
            %
            %       auto_contrast_red - (BOOL) - Default is false
            %           If true, red contrast is calculated for each frame
            %
            %       auto_contrast_green - (BOOL) - Default is false
            %           If true, green contrast is calculated for each frame
            %
            %       autocontrast_thr - (FLOAT) - Default is 99.9
            %           Defines the highest (and lowest by doing
            %           1-autocontrast_thr) percentile used to calculate
            %           contrast. Use lower values to increase autocontrast
            %           clipping effect
            %
            %       flatten_field - (BOOL) - Default is false
            %            If true, FOV is flattened using a intensity
            %            template (under developement)
            %
            %       sliding - (BOOL) - Default is false
            %           If true, we use a sliding window for frme averaging
            %           (better aspect, but more ressource intensive
            %
            % -------------------------------------------------------------
            % Author(s):
            %   Antoine Valera, Geoffrey Evans
            %---------------------------------------------
            % Revision Date:
            %   30-03-2020
            
            if nargin < 2 || isempty(imaging_preset)
                imaging_preset = 0;
            end
            
            this.red_contrast       = 1;
            this.green_contrast     = 1;
            this.red_offset         = 0;
            this.green_offset       = 0;
            this.mode               = 'none'; 
            this.refresh_limit      = 0; 
            this.colormap           = jet;
            this.nb_of_gridlines    = 0;
            this.auto_contrast_red  = false;
            this.auto_contrast_green= false;
            this.autocontrast_thr   = 99.9;
            this.flatten_field      = false;
            this.sliding            = false;
                
            if imaging_preset == 1 % high contrast
                this.red_contrast       = 250;
                this.green_contrast     = 1000;
                this.red_offset         = 120;
                this.green_offset       = 120;
                this.mode               = 'frame_average';
                this.refresh_limit      = 5;
                this.auto_contrast_red  = false;
                this.auto_contrast_green= false;
                this.sliding            = true;
                
            elseif imaging_preset == 2  % slower refresh rate
                this.red_contrast       = 2;
                this.green_contrast     = 2;
                this.red_offset         = 250;
                this.green_offset       = 20;
                this.mode               = 'frame_average';
                this.refresh_limit      = 5;
                this.auto_contrast_red  = true;
                this.auto_contrast_green= true;
                
            elseif imaging_preset == 3 % .2s average
                this.mode               = 'time_average';
                this.refresh_limit      = 0.2;
                
            elseif imaging_preset == 4 % .2s average
                this.red_contrast       = 200;
                this.green_contrast     = 50;
                this.red_offset         = 450;
                this.green_offset       = 30;
                this.mode               = 'frame_average';
                this.refresh_limit      = 5;
                this.auto_contrast_red  = false;
                this.auto_contrast_green= false;
                this.sliding            = true; 
            elseif imaging_preset ~= 0
                warning('Viewer parameter not recognized, default values applied')
            end
        end    
        
        function bkp = get_current_parameters_set(this)
            bkp =  {this.red_contrast       ,...
                    this.green_contrast     ,...
                    this.auto_contrast_red  ,...
                    this.auto_contrast_green,...
                    this.red_offset         ,...
                    this.green_offset       ,...
                    this.mode               ,...
                    this.refresh_limit      ,...
                    this.sliding            ,...
                    this.nb_of_gridlines    ,...
                    this.flat_field         ,...
                    this.autocontrast_thr   };
        end
        
        function set_new_parameters_set(this, bkp)
            [   this.red_contrast       ,...
                this.green_contrast     ,...
                this.auto_contrast_red  ,...
                this.auto_contrast_green,...
                this.red_offset         ,...
                this.green_offset       ,...
                this.mode               ,...
                this.refresh_limit      ,...
                this.sliding            ,...
                this.nb_of_gridlines    ,...
                this.flat_field         ,...
                this.autocontrast_thr   ] = deal(bkp{:});
        end
    end
end