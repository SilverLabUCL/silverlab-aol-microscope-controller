%% Class controlling communication with AOL Control FPGA
%   This class manage connection and packet generation for the AOL Control
%   FPGA, and oversee the generation of the microscope drives using the 
%   linear or nonlinear drivers.
% -------------------------------------------------------------------------
% Class Methods (ignoring get()/set() methods):
%
% * Compute drive_coeffs, build and send records from scan_params
%   [xy_records, drive_coeffs] = obj.load(aol_params, scan_params, 
%                                       is_for_move_corr, num_scans_main,
%                                       acc_ang_main, z_pixel_size_um,
%                                       pockel_values, xy_records,
%                                       drive_coeffs)
%    
% * Build and send Records from scan_params
%   xy_records = obj.select_and_send_command( scan_params, drive_coeffs,
%                                       is_for_move_corr, num_scans_main,
%                                       acc_ang_main, x_norm_to_um_scaling,
%                                       wavelength, z_pixel_size_um,
%                                       xy_records, just_calculate,
%                                       distortion_corr)
%
% * Generate records for structural imaging
%   obj.load_plane_size(num_elem_line)
%
% * Generate records for the header prior to scanning
%   obj. load_points_repeat( num_scans, is_for_move_corr, num_scans_main,
%                       acc_ang_main, x_norm_to_um_scaling, wavelength,
%                       z_pixel_size_um, just_calculate, distortion_corr,
%                       scaled_timing_offsets)
%
% * Generate Records for structural imaging (up to 13 / loop)
%   packet_data = obj.load_plane_records_packet_unsized(num_elem_line,
%                                   start_index, end_index, xy_records)
%
% * Generate Records for pointing / scanning (up to 13 / loop)
%   packet_data = obj.load_points_packet(start_index, end_index, xy_records)
%
%
% * Send up to 13 records at the time to the AOL Control FPGA
%   data = obj.send_xy_records( func, drive_coeffs, start_index, end_index,
%                               data, just_calculate)
%
% * Set duty cycle for screen dimming
%   screen_cycle(obj, t_ramp)
%
% * Run continuous, single frequency on selected AODs 
%   load_single_freqs(obj, aod, freq)   
%
%   stop_single_frequency(obj, aod)
% * Stop continuous, single frequency on selected AODs   
%         
%   toggle_movement_correction(obj)
% * Takes the aol controller in or out of MC mode 
%
% * Object destructor. Close connection.
%   delete(obj)
% -------------------------------------------------------------------------
% Extra Notes:
%
% * This version is intended to work with AOL control FPGA bitfiles located
%   in /Core/aol_controller_binary/
% -------------------------------------------------------------------------
% Examples: 
% -------------------------------------------------------------------------
%                               Notice
%
% Author(s): Victoria Griffiths, Geoffrey Evans, Boris Marin,
%            Antoine Valera
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
% -------------------------------------------------------------------------
% See also: Controller, drives, movement_correction

%% TODO
% check why distortion_corr/2
% screen_cycle
% Read Controller messages (see load_plane_complete_c	
%                               load_points_complete_c
%                               run_plane_complete_c
%                               run_points_complete_c
%                               run_frequency_complete_c)

classdef SynthFpga < handle
    properties
        dest_addr           = uint8(hex2dec(['aa'; 'bb'; 'cc'; 'dd'; 'ee'; 'ff']))';
                              % Mac Adress of AOL Control FPGA (hardcoded)
        send_addr           ; % Mac Adress of the PC ethernet card
        aod_vals            = [128, 64, 32, 16];
        is_running_single   ; 
        device_idx          ; % Hardware number of the ethernet card
        online              ; % Online/Offline status of the setup
    end
    
    methods
        function obj = SynthFpga(adapter_name, online, dest_addr)
            %% SynthFpga Object Constructor
            % -------------------------------------------------------------
            % Syntax: 
            %   obj = SynthFpga(adapter_name, online, dest_addr);
            % -------------------------------------------------------------
            % Inputs:    
            %   adapter_name (INT) - The name of the ethernet adapter to
            %   use, as detected by windows ipconfig function. See
            %   get_adresses() for more details,
            %
            %   online (BOOL) - Optional - default is false
            %       If true, a connection with the AOL Control FPGA with be
            %       initiated.
            %
            %   dest_addr (BOOL) - Optional - default is []
            %       ...
            % -------------------------------------------------------------
            % Outputs: 
            %   obj (SynthFpga object)
            %       The SynthFpga object that handle communication with AOL
            %       Control FPGA
            % -------------------------------------------------------------
            % Extra Notes:
            %   Crash during initialisation may indicate a problem with the
            %   adapter name or mac adress, and can be resolved by
            %   adjusting setup.ini
            % -------------------------------------------------------------
            % Author(s):
            %   Victoria Griffiths, Geoffrey Evans, Boris Marin,
            %   Antoine Valera 
            % ---------------------------------------------
            % Revision Date:
            %   06-05-2020
            
            if nargin <= 2 || isempty(online)
                online = false;
            end
            if nargin <= 3 || isempty(dest_addr)
                dest_addr = [];
            end
            
            %% Set online/offline status for the class
            obj.online = online;
            
            %% If online, initialise connection with AOL Control FPGA
            if obj.online
                [obj.send_addr, obj.device_idx,~] = get_adresses(adapter_name);

                if ~isempty(dest_addr)
                    obj.dest_addr                  = uint8(sscanf(obj.dest_addr, '%2x%*c', 6))';
                end

                obj.is_running_single              = [0,0,0,0];
                send_packet(obj.device_idx, obj.dest_addr, obj.send_addr, obj.send_addr); % open port
            end
        end

        function [xy_records, drive_coeffs] = load(obj, aol_params, scan_params, is_for_move_corr, num_scans_main, acc_ang_main, z_pixel_size_um, pockel_values, xy_records, drive_coeffs)
            %% Compute drive_coeffs, build & send records from scan_params
            % -------------------------------------------------------------
            % Syntax:
            %   [xy_records, drive_coeffs] = ...
            %                   load(obj, aol_params, scan_params,
            %                        is_for_move_corr, num_scans_main,
            %                        acc_ang_main, z_pixel_size_um, 
            %                        pockel_values, xy_records, 
            %                        drive_coeffs)
            % -------------------------------------------------------------
            % Inputs:
            %   aol_params(aol_params OBJECT)
            %       The AolParams object that will be used to generated the
            %       microscope drives
            %   scan_params (scan_params OBJECT)
            %       The ScanParams object that will be converted into
            %       microscope drives. It ca be a regular imaging set or a
            %       movement correction set
            %   is_for_move_corr(BOOL)
            %       Defines if the ScanParams are used for imaging or for
            %       RT-3DMC
            %   num_scans_main(INT) - Only used for RT-3DMC.
            %       The number of ramps of the main imaging records.
            %   acc_ang_main(FLOAT) - Only used for RT-3DMC.
            %       In radians, the acceptance angle of the main imaging
            %       records.
            %   z_pixel_size_um(INT) - Only used for RT-3DMC.
            %       in um, the size of the Z-pixel size
            %   pockel_values (FLOAT OR 1xN FLOAT) - Optional - default is 
            %                           scan_params,pockel_raw
            %       If provided, update the current current pockel values.      
            %       If INT, all drives have the same pockel value. If 1xN,
            %       set the Pockel value for individual ramps. N must match
            %       the number of drives
            %   xy_records([] or Cell Array of (1 x 13 Cells)) - Optional -
            %                           default is []
            %       If non empty, bypass the records calculation, and send
            %       the content of the cell using obj.send_xy_records().
            %       Use this feature if drives are precalculated. see
            %       drives.precalculate_drives() and drives.send_drives() 
            %       for an example
            %   drive_coeff([], or DriveCoeffs OBJECT) - Optional - Default
            %                           is [];
            %       drive_coeffs for the drives in scan_params. If provided
            %       bypass drivesCOeff calculation.
            %       Use this feature if drives are precalculated. see
            %       drives.precalculate_drives() and drives.send_drives() 
            %       for an example 
            % -------------------------------------------------------------
            % Outputs:
            %   xy_records(Cell Array of (1 x 13 Cells))
            %       Records computed using current ScanParams. You can
            %       store them and pass them directly if you intend to scan
            %       the same object again.
            %   drive_coeffs(DriveCoeffs OBJECT)
            %       drive_coeffs computed using current ScanParams. You can
            %       store them and pass them directly if you intend to scan
            %       the same object again.
            % -------------------------------------------------------------
            % Extra Notes:
            % * For more detail, see load_points_c in Online Documentation.
            % * Regular imaging drives are sent using 
            %   Controller.send_drives(), with is_for_move_corr = false.
            %    Controller.scan_params
            % * Movement correction scan drives are sent using 
            %   Controller.send_mc_drives(), with is_for_move_corr = true.
            %   Drives are typically generated from 
            %   Controller.mc_scan_params
            % -------------------------------------------------------------
            % Author(s):
            %   Victoria Griffiths, Geoffrey Evans, Boris Marin,
            %   Antoine Valera
            %--------------------------------------------------------------
            % Revision Date:
            %   06-05-2020

            %% If provided, replace pockel values with new ones
            if nargin < 9 || isempty(xy_records)
                xy_records = [];
                scan_params.pockels_raw = pockel_values;
            end
            
            %% If not provided, calculate drives
            if nargin < 10 || isempty(drive_coeffs)
                drive_coeffs = drives_for_synth_fpga(aol_params, scan_params); %calculate a, b and c's and a bit of d's
            end

            %% Calculate or send drives
            % If you ask for a function output, drives are calculated but
            % not sent. This is used if you ant to send drives in quick
            % sucession and try to precalculate drives. see drives.precalculate_drives
            just_calculate = nargout;
            wl = round(aol_params.current_wavelength * 1e9);
            xy_records = obj.select_and_send_command( scan_params                       ,...
                                                      drive_coeffs                      ,...
                                                      is_for_move_corr                  ,...
                                                      num_scans_main                    ,...
                                                      acc_ang_main                      ,...
                                                      aol_params.x_norm_to_um_scaling   ,...
                                                      wl                                ,...
                                                      z_pixel_size_um                   ,...
                                                      xy_records                        ,...
                                                      just_calculate                    ,...
                                                      aol_params.distortion_corr/2      );
        end

        function xy_records = select_and_send_command(obj, scan_params, drive_coeffs, is_for_move_corr, num_scans_main, acc_ang_main, x_norm_to_um_scaling, wavelength, z_pixel_size_um, xy_records, just_calculate, distortion_corr)
            %% Build & send records from scan_params
            % -------------------------------------------------------------
            % Syntax:
            %   xy_records = select_and_send_command(obj, scan_params,
            %                           drive_coeffs, is_for_move_corr,
            %                           num_scans_main, acc_ang_main,
            %                           x_norm_to_um_scaling, wavelength,
            %                           z_pixel_size_um, xy_records,
            %                           just_calculate, distortion_corr)
            % -------------------------------------------------------------
            % Inputs:
            %   scan_params (scan_params OBJECT)
            %       The ScanParams object that will be converted into
            %       microscope drives. It can be a regular imaging set or a
            %       movement correction set
            %   drive_coeff(DriveCoeffs OBJECT)
            %       drive_coeffs for the drives in scan_params. Calculated
            %       using drives_for_synth_fpga()
            %   is_for_move_corr(BOOL)
            %       Defines if the ScanParams are used for imaging or for
            %       RT-3DMC
            %   num_scans_main(INT) - Only used for RT-3DMC.
            %       The number of ramps of the main imaging records.
            %   acc_ang_main(FLOAT) - Only used for RT-3DMC.
            %       In radians, the acceptance angle of the main imaging
            %       records.
            %   x_norm_to_um_scaling(FLOAT) - Only used for RT-3DMC.
            %       used to calculate fov_main in obj.load_points_repeat()
            %   wavelength(FLOAT) - Only used for RT-3DMC.
            %       wavelength wave for wavelength-dependent geometry
            %       corrections.
            %   z_pixel_size_um(INT) - Only used for RT-3DMC.
            %       in um, the size of the Z-pixel size
            %   xy_records([] or Cell Array of (1 x 13 Cells))
            %       If non empty, bypass the records calculation, and send
            %       the content of the cell using obj.send_xy_records().
            %       Use this feature if drives are precalculated. see
            %       drives.precalculate_drives() and drives.send_drives() 
            %       for an example
            %   just_calculate(BOOL) - Optional - default is false
            %       If true, records will only be calculated, but not be
            %       send in obj.send_records 
            %   distortion_corr(FLOAT)
            %       Corrective value for non-telecentric distortions
            % -------------------------------------------------------------
            % Outputs:
            %   xy_records(Cell Array of (1 x 13 Cells))
            %       Records computed using current ScanParams. You can
            %       store them and pass them directly if you intend to scan
            %       the same object again.
            % -------------------------------------------------------------
            % Extra Notes:
            % * For more details, see load_points_c, load_points_repeat_c
            %   and load_plane_size_c in Online Documentation,
            % -------------------------------------------------------------
            % Author(s):
            %   Victoria Griffiths, Geoffrey Evans, Boris Marin,
            %   Antoine Valera
            %--------------------------------------------------------------
            % Revision Date:
            %   06-05-2020
            
            if scan_params.imaging_mode == ImagingMode.Pointing
                %% Drive generation in Pointing mode
                obj.load_plane_size(scan_params.mainscan_x_pixel_density);
                load_plane_records_packet = @(start_index, end_index, xy_records) obj.load_plane_records_packet_unsized(scan_params.mainscan_x_pixel_density, start_index, end_index, xy_records);
                xy_records = obj.loop13(load_plane_records_packet, drive_coeffs, xy_records, just_calculate);
            else                   
                %% Drive generation in Scanning mode
                %obj.screen_cycle(drive_coeffs.t(1));
                obj.load_points_repeat( drive_coeffs.num_drives,...
                                        is_for_move_corr,...
                                        num_scans_main,...
                                        acc_ang_main,...
                                        x_norm_to_um_scaling,...
                                        wavelength,...
                                        z_pixel_size_um,...
                                        just_calculate,...
                                        distortion_corr,...
                                        drive_coeffs.timing_offsets); 
                xy_records = obj.loop13(@obj.load_points_packet,...
                                        drive_coeffs,...
                                        xy_records,...
                                        just_calculate);
            end
        end

        function load_plane_size(obj, num_elem_line)
            %% Generate Header for structural imaging
            % In structural mode, we generate one ramp per voxel. As the
            % AOL Control FPGA cannot handle that many records in memory,
            % we only specify where the lines are starting, and the number
            % of voxel per line.
            % -------------------------------------------------------------
            % Syntax:
            %   load_plane_size(obj, num_elem_line)
            % -------------------------------------------------------------
            % Inputs:
            %   num_elem_line (INT)
            %       Number of points to generate per line
            % -------------------------------------------------------------
            % Outputs:
            % -------------------------------------------------------------
            % Extra Notes:
            % * For more detail, see load_plane_size_c in Online
            %   Documentation.
            % -------------------------------------------------------------
            % Author(s):
            %   Victoria Griffiths, Geoffrey Evans, Boris Marin,
            %   Antoine Valera
            %--------------------------------------------------------------
            % Revision Date:
            %   06-05-2020

            length  = 6; % number of bytes to expect in the packet
            data    = [split_2_bytes_lr(length) SynthComs.load_plane_size.v 0 split_2_bytes(num_elem_line) split_2_bytes(num_elem_line)];
            send_packet(int32(-1), obj.dest_addr, obj.send_addr, data);
        end
 
        function load_points_repeat(obj, num_scans, is_for_move_corr, num_scans_main, acc_ang_main, x_norm_to_um_scaling, wavelength, z_pixel_size_um, just_calculate, distortion_corr, scaled_timing_offsets)
            %% Generate Header for scanning mode
            % -------------------------------------------------------------
            % Syntax:
            %   load_points_repeat( obj, num_scans, is_for_move_corr, 
            %                       num_scans_main, acc_ang_main,
            %                       x_norm_to_um_scaling, wavelength,
            %                       z_pixel_size_um, just_calculate,
            %                       distortion_corr, scaled_timing_offsets)
            % -------------------------------------------------------------
            % Inputs:
            %   num_scans (INT)
            %       Number of line scans
            %   is_for_move_corr(BOOL)
            %       Defines if the ScanParams are used for imaging or for
            %       RT-3DMC
            %   num_scans_main(INT) - Only used for RT-3DMC.
            %       The number of ramps of the main imaging records.
            %   acc_ang_main(FLOAT) - Only used for RT-3DMC.
            %       In radians, the acceptance angle of the main imaging
            %       records.
            %   x_norm_to_um_scaling(FLOAT) - Only used for RT-3DMC.
            %       used to calculate fov_main in obj.load_points_repeat()
            %   wavelength(FLOAT) - Only used for RT-3DMC.
            %       wavelength wave for wavelength-dependent geometry
            %       corrections.
            %   z_pixel_size_um(INT) - Only used for RT-3DMC.
            %       in um, the size of the Z-pixel size
            %   just_calculate(BOOL) - Optional - default is false
            %       If true, records will only be calculated, but not be
            %       send in obj.send_records 
            %   distortion_corr(FLOAT) - Only used for RT-3DMC.
            %       Corrective value for non-telecentric distortions
            %   scaled_timing_offsets(1X16 UINT8) - Only used for RT-3DMC.
            %       Modified version of AOL_params. timing_offsets,
            %       required for taking calibration into account for
            %       RT-3DMC.
            % -------------------------------------------------------------
            % Outputs:
            % -------------------------------------------------------------
            % Extra Notes:
            % * For more detail, see load_points_repeat_c in Online
            %   Documentation.
            % -------------------------------------------------------------
            % Author(s):
            %   Victoria Griffiths, Geoffrey Evans, Boris Marin,
            %   Antoine Valera
            %--------------------------------------------------------------
            % Revision Date:
            %   06-05-2020

           %% QQ had that note, but not sure what it means : changing this to add z fields  pixel size 1 byte (1),  lambda 2 bytes 912, acc x100 2 bytes(570), objective 1 byte (20) + 6 bytes fixed value for calibration 
           
           %% Calculate FOV of the mainscan
           fov_main = uint16(acc_ang_main * x_norm_to_um_scaling * 2);

           %% Build and send header
           data = [split_2_bytes_lr(33) SynthComs.load_points_repeat.v split_2_bytes(num_scans) is_for_move_corr 0 split_2_bytes(fov_main) 1 split_2_bytes(num_scans_main) uint8(z_pixel_size_um) split_2_bytes(uint16(wavelength)) split_2_bytes(uint16(acc_ang_main*100000)), 20, uint8(distortion_corr), scaled_timing_offsets]; %%qq objective fiedl(last value) is still passed manually
           if ~just_calculate
                send_packet(int32(-1), obj.dest_addr, obj.send_addr, data);
           end
        end
        
        function packet_data = load_plane_records_packet_unsized(~, num_elem_line, start_index, end_index, xy_records)
            %% Generate Records for structural imaging (up to 13 / loop)
            % -------------------------------------------------------------
            % Syntax:
            %   packet_data = load_plane_records_packet_unsized(~, 
            %                               num_elem_line, start_index,
            %                               end_index, xy_records)
            % -------------------------------------------------------------
            % Inputs:
            %   num_elem_line (INT)
            %       Totoal Number of points to generate per line
            %   start_index (INT)
            %       Start index of the current batch of records
            %   end_index (INT)
            %       Stop index of the current batch of records
            %   xy_records(Cell Array of (1 x 13 Cells))
            %       If non empty, bypass the records calculation, and send
            %       the content of the cell using obj.send_xy_records().
            %       Use this feature if drives are precalculated. see
            %       drives.precalculate_drives() and drives.send_drives() 
            %       for an example
            % -------------------------------------------------------------
            % Outputs:
            %   packet_data(1x? UINT8)
            %       The packet generated from the 13 records
            % -------------------------------------------------------------
            % Extra Notes:
            % * For more detail, see load_plane_records_c in Online
            %   Documentation.
            % -------------------------------------------------------------
            % Author(s):
            %   Victoria Griffiths, Geoffrey Evans, Boris Marin,
            %   Antoine Valera
            %--------------------------------------------------------------
            % Revision Date:
            %   06-05-2020

            packet_data = [ 0, 0, SynthComs.load_plane_records.v, 0                     ,...
                            split_2_bytes(num_elem_line), split_2_bytes(num_elem_line)  ,...
                            split_2_bytes(start_index-1), split_2_bytes(end_index-1)    ,...
                            xy_records                                                  ];
        end
        
        function packet_data = load_points_packet(~, start_index, end_index, xy_records)
            %% Generate Records for pointing / scanning (up to 13 / loop)
            % -------------------------------------------------------------
            % Syntax:
            %   packet_data = load_points_packet(~, start_index,
            %                                   end_index, xy_records)
            % -------------------------------------------------------------
            % Inputs:
            %   start_index (INT)
            %       Start index of the current batch of records
            %   end_index (INT)
            %       Stop index of the current batch of records
            %   xy_records(Cell Array of (1 x 13 Cells))
            %       If non empty, bypass the records calculation, and send
            %       the content of the cell using obj.send_xy_records().
            %       Use this feature if drives are precalculated. see
            %       drives.precalculate_drives() and drives.send_drives() 
            %       for an example
            % -------------------------------------------------------------
            % Outputs:
            %   packet_data(1x? UINT8)
            %       The packet generated from the 13 records
            % -------------------------------------------------------------
            % Extra Notes:
            % * For more detail, see load_points_c in Online
            %   Documentation.
            % -------------------------------------------------------------
            % Author(s):
            %   Victoria Griffiths, Geoffrey Evans, Boris Marin,
            %   Antoine Valera
            %--------------------------------------------------------------
            % Revision Date:
            %   06-05-2020

            packet_data = [0 0 SynthComs.load_points.v ...
                split_3_bytes(start_index-1) split_3_bytes(end_index-1)...
                xy_records];
        end

        function xy_records = loop13(obj, func, drive_coeffs, xy_records, just_calculate)
            %% Send up to 13 records at the time
            % -------------------------------------------------------------
            % Syntax:
            %   xy_records = packet_data = loop13(~, func,
            %                   drive_coeffs, xy_records, just_calculate)
            % -------------------------------------------------------------
            % Inputs:
            %   func (INT)
            %       Function handle that generates the packets
            %   drive_coeff(DriveCoeffs OBJECT)
            %       drive_coeffs for the drives in scan_params. Calculated
            %       using drives_for_synth_fpga()
            %   xy_records(Cell Array of (1 x 13 Cells))
            %       If non empty, bypass the records calculation, and send
            %       the content of the cell using obj.send_xy_records().
            %       Use this feature if drives are precalculated. see
            %       drives.precalculate_drives() and drives.send_drives() 
            %       for an example
            %   just_calculate(BOOL) - Optional - default is false
            %       If true, records will only be calculated, but not be
            %       send in obj.send_records 
            % -------------------------------------------------------------
            % Outputs:
            %   xy_records(Cell Array of (1 x 13 Cells))
            %       The up-to-13 records of the current loop
            % -------------------------------------------------------------
            % Extra Notes:
            % -------------------------------------------------------------
            % Author(s):
            %   Victoria Griffiths, Geoffrey Evans, Boris Marin,
            %   Antoine Valera
            %--------------------------------------------------------------
            % Revision Date:
            %   06-05-2020
            
            start_index = 1;
            if isempty(xy_records)
                xy_records          = cell(1,ceil(drive_coeffs.num_drives/13));
            end
            counter = 1;
            while start_index <= drive_coeffs.num_drives
                end_index           = start_index + 12; % take at most 13
                if end_index > drive_coeffs.num_drives % and maybe less than 13 if at the end
                    end_index       = drive_coeffs.num_drives;
                end
                xy_records{counter} = obj.send_xy_records(func, drive_coeffs, start_index, end_index, xy_records{counter}, just_calculate);
                start_index         = start_index + 13;
                counter             = counter + 1;
            end
        end
        
        function data = send_xy_records(obj, func, drive_coeffs, start_index, end_index, data, just_calculate)
            %% Send up to 13 records at the time to the AOL Control FPGA
            % -------------------------------------------------------------
            % Syntax:
            %   xy_records = packet_data = loop13(~, func,
            %                   drive_coeffs, xy_records, just_calculate)
            % -------------------------------------------------------------
            % Inputs:
            %   func (INT)
            %       Function handle that generates the packets
            %   drive_coeff(DriveCoeffs OBJECT)
            %       drive_coeffs for the drives in scan_params. Calculated
            %       using drives_for_synth_fpga()
            %   xy_records(Cell Array of (1 x 13 Cells))
            %       If non empty, bypass the records calculation, and send
            %       the content of the cell using obj.send_xy_records().
            %       Use this feature if drives are precalculated. see
            %       drives.precalculate_drives() and drives.send_drives() 
            %       for an example
            %   just_calculate(BOOL) - Optional - default is false
            %       If true, records will only be calculated, but not be
            %       send in obj.send_records 
            % -------------------------------------------------------------
            % Outputs:
            %   xy_records(Cell Array of (1 x 13 Cells))
            %       The up-to-13 records of the current loop
            % -------------------------------------------------------------
            % Extra Notes:
            % -------------------------------------------------------------
            % Author(s):
            %   Victoria Griffiths, Geoffrey Evans, Boris Marin,
            %   Antoine Valera
            %--------------------------------------------------------------
            % Revision Date:
            %   06-05-2020
            
            if isempty(data)
                xy_records  = make_xy_records(drive_coeffs.section(start_index, end_index));
                data        = func(start_index, end_index, xy_records);
                data_length = length(data) - 2;
                data(1:2)   = split_2_bytes_lr(data_length);
            end
            if ~just_calculate
                send_packet(int32(-1), obj.dest_addr, obj.send_addr, data);
            end
        end
 
        function screen_cycle(obj, t_ramp)     
            %% Set duty cycle for screen dimming
            % -------------------------------------------------------------
            % Syntax:
            %   screen_cycle(obj, t_ramp) 
            % -------------------------------------------------------------
            % Inputs:
            %   t_ramp (INT)
            %       ramp duration as output from DriveCoeff.t
            % -------------------------------------------------------------
            % Outputs:
            % -------------------------------------------------------------
            % Extra Notes:
            % * For more detail, see screen_cycle_c in Online
            %   Documentation.            
            % -------------------------------------------------------------
            % Author(s):
            %   Victoria Griffiths, Antoine Valera
            %--------------------------------------------------------------
            % Revision Date:
            %   06-05-2020
            
        	data = [split_2_bytes_lr(3), uint8(31), split_2_bytes(t_ramp)];  % drive_coeffs.t(1) only true for first line
        	send_packet(int32(-1), obj.dest_addr, obj.send_addr, data);
        end
        
        function load_single_freqs(obj, aod, freq)
            %% Run continuous, single frequency on selected AODs 
            % -------------------------------------------------------------
            % Syntax:
            %   load_single_freqs(obj, aod, freq)
            % -------------------------------------------------------------
            % Inputs:
            %   aod ([1x4] BOOL)
            %       Defines which AOD to use (X1 X2 Y1 Y2)
            %   freq (?)
            %       ?
            % -------------------------------------------------------------
            % Outputs:
            % -------------------------------------------------------------
            % Extra Notes:
            % * For more detail, see load_single_frequency_c in Online
            %   Documentation.            
            % -------------------------------------------------------------
            % Author(s):
            %   Victoria Griffiths
            %--------------------------------------------------------------
            % Revision Date:
            %   06-05-2020
            
            %% QQ check for rescaling since DriveCoeffs was upgraded
            error_box('NEED REVIEW FIRST')
            
            a = round(freq * 2^32 / 240e6); 
            xy_record = make_xy_records(DriveCoeffs(aol_params.synth_clock_freq, a, a*0, 0, 0, 0)); % amplitude modulations fields not send. may need revision
            data = [ SynthComs.load_single_frequency.v obj.aod_vals(aod) xy_record];
            send_packet(int32(-1), obj.dest_addr, obj.send_addr, data);
            obj.is_running_single(aod) = 1;
        end
        
        function stop_single_frequency(obj, aod)
            %% Stop continuous, single frequency on selected AODs 
            % -------------------------------------------------------------
            % Syntax:
            %   stop_single_frequency_c(obj, aod)
            % -------------------------------------------------------------
            % Inputs:
            %   aod ([1x4] BOOL)
            %       Defines which AOD to use (X1 X2 Y1 Y2)
            % -------------------------------------------------------------
            % Outputs:
            % -------------------------------------------------------------
            % Extra Notes:
            % * For more detail, see stop_single_frequency_c in Online
            %   Documentation.            
            % -------------------------------------------------------------
            % Author(s):
            %   Victoria Griffiths
            %--------------------------------------------------------------
            % Revision Date:
            %   06-05-2020
            
            data = [ SynthComs.stop_single_frequency.v obj.aod_vals(aod)];
            send_packet(int32(-1), obj.dest_addr, obj.send_addr, data);
            obj.is_running_single(aod) = 0;
        end

        function toggle_movement_correction(obj)
            %% Takes the aol controller in or out of MC mode
            % -------------------------------------------------------------
            % Syntax:
            %   toggle_movement_correction(obj)
            % -------------------------------------------------------------
            % Inputs:
            % -------------------------------------------------------------
            % Outputs:
            % -------------------------------------------------------------
            % Extra Notes:
            % * For more detail, see clear_reference_c in Online
            %   Documentation.            
            % -------------------------------------------------------------
            % Author(s):
            %   Victoria Griffiths, Antoine Valera
            %--------------------------------------------------------------
            % Revision Date:
            %   06-05-2020
            
            length = 2;
            data = [split_2_bytes_lr(length), 15, 0];         
            send_packet(int32(-1), obj.dest_addr, obj.send_addr, data);
        end
        
        function delete(obj)
            %% Object Destructor. Close connection.
            % -------------------------------------------------------------
            % Syntax:
            %   obj.delete();
            % -------------------------------------------------------------
            % Inputs:
            % -------------------------------------------------------------
            % Outputs:
            % -------------------------------------------------------------
            % Extra Notes:            
            % -------------------------------------------------------------
            % Author(s):
            %   Victoria Griffiths, Geoffrey Evans, Boris Marin,
            %   Antoine Valera
            %--------------------------------------------------------------
            % Revision Date:
            %   06-05-2020
            
            if ~check_caller({'load_','uiimport','uiopen'}) % can add 'SynthFpga.SynthFpga'
                if ~isempty(obj.send_addr) && ~isempty(obj.dest_addr)
                    send_packet(int32(-2), obj.dest_addr, obj.send_addr, obj.send_addr); % close port
                    for aod = find(obj.is_running_single)
                        stop_single_frequency(obj, aod);
                    end
                end
            end
        end
        
    end
end

