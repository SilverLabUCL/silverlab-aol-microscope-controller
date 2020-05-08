%% Subclass of Base for storing data in 2 arrays (one per channel)
% Create a DataHolder, and update its content by reading the FIFO.
%
% Type doc function_name or help function_name to get more details about
% the function inputs and outputs.
% -------------------------------------------------------------------------
% Syntax: 
%   this = DataHolder(size, repeats);
% -------------------------------------------------------------------------
% Class Generation Inputs:
%   size (INT) - Optional - default is 1.
%       The expected number of points to acquire in one repeat. This is
%       used for memory preallocation. Haveing enough points preallocated
%       speed up acquisition and prevent buffer issues.
%
%   repeats (INT) - Optional - default is 0
%       The expected number of time the scan will be repeated (use 0 
%       for a single trial)
% -------------------------------------------------------------------------
% Outputs: 
%   this (DataHolder object)
%       The DataHolder object with Triggers and preallocated memory for
%       data collection.
% -------------------------------------------------------------------------
% Class Methods: 
%
% * Update DataHolder.data0 and DataHolder.data1 with new data
%   DataHolder.update(new_data0, new_data1)
%
% * Reshape the data in the format defined by this.data_size and average 
%   trials.
%   data = DataHolder.reshape_and_average()
%
% * Reset DataHolder buffer.
%   DataHolder.reset()
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
%   16-07-2018
%
% See also
%   BaseViewer

classdef DataHolder < BaseViewer
    %% This is an Ultra basic Data Holder
    % You can store 2 data channels

    properties
        data0                   % The data in channel 1
        data1                   % The data in channel 2
        counter_ch1_pre = 0     % The index of the first point to write during the next FIFO read in channel 1
        counter_ch1_post = 0    % The index of the last point to write during the next FIFO read in channel 1
        counter_ch2_pre = 0     % The index of the first point to write during the next FIFO read in channel 2
        counter_ch2_post = 0    % The index of the last point to write during the next FIFO read in channel 2
        zeroed_frame = [];      % An empty array used for rapidly reset the data without reallocating memory
        repeats = 0;            % The number of repeats of each cycle. Use 0 for a single trial 
        data_size = 0;          % The expected number of points in each cycle 
        refresh_limit = 0;      % No averages in this mode
        type = 'data_holder';   % The viewer type, as read in the BaseViewer superclass
    end

    methods
        function this = DataHolder(size, repeats)
            %% DataHolder Object Constructor
            % -------------------------------------------------------------
            % Syntax: 
            %   this = DataHolder(size, repeats);
            % -------------------------------------------------------------
            % Inputs:    
            %   size (INT) - Optional - default is 1.
            %       The expected number of points to acquire in one repeat.
            %       This is used for memory preallocation. Haveing enough
            %       points preallocated speed up acquisition and prevent
            %       buffer issues.
            %
            %   repeats (INT) - Optional - default is 0
            %       The expected number of time the scan will be repeated 
            %       (use 0 for a single trial)
            % -------------------------------------------------------------
            % Outputs: 
            %   this (DataHolder object)
            %       The DataHolder object with Triggers and preallocated 
            %       memory for data collection.
            % -------------------------------------------------------------
            % Extra Notes:
            %   Data type is UINT16. Data is stored in a linear array, but
            %   can be reshaped with DataHolder.reshape_and_average()
            % -------------------------------------------------------------
            % Author(s):
            %   Antoine Valera
            % ---------------------------------------------
            % Revision Date:
            %   16-07-2018
            
            if nargin < 1 || isempty(size)
                size = 1;
            end
            if nargin < 2 || isempty(repeats)
                repeats = 0;
            end
            
            this.repeats = repeats;
            this.data_size = size;
            this.data0 = zeros(sum(prod(this.data_size,2)) * this.repeats, 1, 'uint16');
            this.data1 = zeros(sum(prod(this.data_size,2)) * this.repeats, 1, 'uint16');
            this.zeroed_frame = this.data0;
            this.type = 'data_holder';
        end
        
        function update(this, new_data0, new_data1)  
            %% Update DataHolder.data0 and DataHolder.data1 with new data
            % -------------------------------------------------------------
            % Syntax: 
            %   DataHolder.update(new_data0, new_data1)  
            % -------------------------------------------------------------
            % Inputs:    
            %   new_data0 (1 x N INT)
            %       The new data to be added in data0 channel.
            %       DataHolder.counter_ch1_pre/post are updated accordingly
            %
            %   new_data1 (1 x N INT)
            %       The new data to be added in data1 channel.
            %       DataHolder.counter_ch2_pre/post are updated accordingly
            % -------------------------------------------------------------
            % Outputs: 
            % -------------------------------------------------------------
            % Author(s):
            %   Antoine Valera
            % ---------------------------------------------
            % Revision Date:
            %   16-07-2018
            
            if ~isempty(new_data0)
                ndata1 = size(new_data0,1);
                this.counter_ch1_post = this.counter_ch1_pre + ndata1;
                this.data0(this.counter_ch1_pre + 1:this.counter_ch1_post) = new_data0;
                this.counter_ch1_pre = this.counter_ch1_post;
            else
                this.counter_ch1_post = this.counter_ch1_pre;
            end
            
            if ~isempty(new_data1) %can be empty if one channel finished before the other
                ndata2 = size(new_data1,1);
                this.counter_ch2_post = this.counter_ch2_pre + ndata2;
                this.data1(this.counter_ch2_pre + 1:this.counter_ch2_post) = new_data1;
                this.counter_ch2_pre = this.counter_ch2_post;
            else
                this.counter_ch2_post = this.counter_ch2_pre;
            end
        end
        
        function data = reshape_and_average(this)
            %% Average all recorded trials 
            % -------------------------------------------------------------
            % Syntax: 
            %   data = DataHolder.update(new_data0, new_data1)  
            % -------------------------------------------------------------
            % Inputs:    
            %   new_data0 (1 x N INT)
            %       The new data to be added in data0 channel.
            %       DataHolder.counter_ch1_pre/post are updated accordingly
            %
            %   new_data1 (1 x N INT)
            %       The new data to be added in data1 channel.
            %       DataHolder.counter_ch2_pre/post are updated accordingly
            % -------------------------------------------------------------
            % Outputs: 
            %   data ([DataHolder.data_size * 2] INT)
            %       The data reshaped as specified in DataHolder.data_size,
            %       for each channel, and averaged across repeats.
            % -------------------------------------------------------------
            % Author(s):
            %   Antoine Valera
            % ---------------------------------------------
            % Revision Date:
            %   16-07-2018
            
            if ndims(this.data_size) == 2 && size(a,2) == 1
                dimensions = 1;
            else
                dimensions = ndims(this.data_size);
            end
            
            this.data0 = mean(reshape(this.data0, this.data_size, []), dimensions+1);
            this.data1 = mean(reshape(this.data1, this.data_size, []), dimensions+1);
            data = cat(dimensions+1, this.data0, this.data1);
        end
        
        function reset(this)
            %% Reset DataHolder buffer.
            % -------------------------------------------------------------
            % Syntax: 
            %   DataHolder.reset()  
            % -------------------------------------------------------------
            % Inputs:    
            % -------------------------------------------------------------
            % Outputs: 
            % -------------------------------------------------------------
            % Author(s):
            %   Antoine Valera
            % ---------------------------------------------
            % Revision Date:
            %   16-07-2018
            
            this.data0 = this.zeroed_frame;
            this.data1 = this.zeroed_frame;
            this.counter_ch1_pre = 0;
            this.counter_ch1_post = 0; 
            this.counter_ch2_pre = 0;
            this.counter_ch2_post = 0; 
        end
        
        function remove_trailing_zeros(this)
            %% Removes trailing zeros when preallocation was too large
            % -------------------------------------------------------------
            % Syntax: 
            %   DataHolder.reset()  
            % -------------------------------------------------------------
            % Inputs:    
            % -------------------------------------------------------------
            % Outputs: 
            % -------------------------------------------------------------
            % Extra Notes: 
            % We use the index, but we could also detect the first zero with 
            %   trailing = find(this.data0 == 0, 1 );
            % -------------------------------------------------------------
            % Author(s):
            %   Antoine Valera
            % ---------------------------------------------
            % Revision Date:
            %   16-07-2018
            
            this.data0 = this.data0(1:this.counter_ch1_post);
            this.data1 = this.data1(1:this.counter_ch2_post);
        end 
        
    end
end

