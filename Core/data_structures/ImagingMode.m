%% Convert imaging mode to its correct numerical value (for the DAQFPGA)
%   Daq needs to know what imaging mode we are using (point/scan ; MC/NoMC)
%
% -------------------------------------------------------------------------
% Class Methods (ignoring get()/set() methods):
%
% * Get UINT32 value for corresponding mode
%   [val] = daq_val(mode, move_corr)
% -------------------------------------------------------------------------
% Extra Notes:
% -------------------------------------------------------------------------
% Examples:
% -------------------------------------------------------------------------
%                               Notice
%
% Author(s): Antoine Valera, Paul Kirkby
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
%   24-02-2020
%
% See also: DaQFPGA

classdef ImagingMode < uint32
    
    enumeration
        Raster (4),
        Pointing (2),
        Functional (3),
        Miniscan (1)
    end
    
    methods
        function val = daq_val(mode, move_corr)
            if mode == ImagingMode.Pointing || mode == ImagingMode.Functional
                if move_corr
                    val = 2;
                else
                    val = 1;
                end
            else
                if move_corr
                    val = 3;
                else
                    val = 0;
                end
            end
        end
    end
end

