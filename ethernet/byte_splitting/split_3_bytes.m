%% Convert UINT32 data into 3 bytes representations 
% -------------------------------------------------------------------------
% Syntax: 
%   out = split_3_bytes(in)
% -------------------------------------------------------------------------
% Inputs: 
%   in(UINT): 
%                                   input UINT32 data to reshape.
%                                   If input data format is not UINT32,
%                                   data is converted first.
% -------------------------------------------------------------------------
% Outputs:
%
% 	out([N x 3] UINT8) : 
%                                   input data split in 3 bytes elements
% -------------------------------------------------------------------------
% Extra Notes:
% -------------------------------------------------------------------------
% Examples:
% -------------------------------------------------------------------------
%                               Notice
%
% Author(s): Victoria Griffiths, Geoffrey Evans, Boris Marin 
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
%   06-05-2020
%
% See also: SynthFpga, make_xy_records


function out = split_3_bytes(in)
    out_list    = typecast(uint32(in),'uint8');
    out         = reshape(out_list(1:3), 3, [])';
end

