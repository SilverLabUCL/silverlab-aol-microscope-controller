%% Build records packets before sending to AOL Control FPGA
% -------------------------------------------------------------------------
% Syntax: 
%   recs = make_xy_records(drive_coeffs)
%
% -------------------------------------------------------------------------
% Inputs: 
%   drive_coeffs(DriveCoeffs OBJECT)
%                                   The drive coeffs object you build using
%                                   ScanParams 
% -------------------------------------------------------------------------
% Outputs:
%   records(...)
%                                   If
% -------------------------------------------------------------------------
% Extra Notes:
% -------------------------------------------------------------------------
% Examples:
% -------------------------------------------------------------------------
%                               Notice
%
% Author(s): Victoria Griffiths, Geoffrey Evans, Boris Marin, Antoine Valera
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
%   01-03-2019
%
% See also: SynthFpga, DriveCoeffs


function records = make_xy_records(drive_coeffs)
    x1          = make_records(drive_coeffs, 1);
    y1          = make_records(drive_coeffs, 2);
    x2          = make_records(drive_coeffs, 3);
    y2          = make_records(drive_coeffs, 4);

    recs_raw    = [x1, x2, y1, y2];
    records     = reshape(recs_raw', 1, []);
end

function r = make_records(drives, idx)
    r           = zeros(drives.num_drives, 28);
    r(:,3:6)    = split_4_bytes(drives.a(idx,:));
    r(:,7:8)    = split_2_bytes_s(drives.b(idx,:));
    r(:,9:10)   = split_2_bytes_s(drives.c(idx,:));
    r(:,11:12)  = split_2_bytes_s(drives.d(idx,:));
    r(:,[1,2,13,14]) = split_4_bytes(drives.d_4app(idx,:));             % using both fields from phase and e temporarily 
    r(:,15:16)  = split_2_bytes_s(drives.delta_bz(idx,:));              % ramp_offset are now 0
    r(:,17:18)  = split_2_bytes(drives.t(idx,:));
    r(:,19:20)  = split_2_bytes(drives.amp0(idx,:)); 
    r(:,21:22)  = split_2_bytes(drives.pockels_level(idx,:) * 2^13-1);  % if max is 2^14-1.Since range is 0-2 V, max is 2^13-1
    r(:,23:26)  = split_4_bytes_s(drives.delta_a_dz(idx,:));
    r(:,27:28)  = split_2_bytes_s(drives.aod_delay_cycles(idx,:));
end