%% Class storing drivers coeffs (or fixed point representations)
%   Store all the fields that will be sent to the controller. a, b, c, 
%   and d values should be scaled.  delta_a_dz and d_app should be 
%   converted to fixed point. 
% -------------------------------------------------------------------------
% Class Methods (ignoring get()/set() methods):
%
% * Returns 13 drives subsection for ethernet packets
%   [drive_section] = obj.section(start_index, end_index)
%
%
% -------------------------------------------------------------------------
% Extra Notes:
% * Values are automatically rescaled and converted to fixed whenever
%   required, unless you set synth_clock_freq to 0. 
%
% * When passing values, dimensions are typically [num_aods, num_drives]  
%
% * For a practical example see drives_for_synth_fpga()
% -------------------------------------------------------------------------
% Examples: 
% -------------------------------------------------------------------------
%                               Notice
%
% Author(s): Vicky Griffiths, Boris Marin, Geoffrey Evans, Paul Kirkby, 
%            Srinivas Nadella, Antoine Valera
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
% See also: drives_for_synth_fpga, SynthFpga
%


classdef DriveCoeffs < handle
    properties 
        synth_clock_freq    ; %        
        a                   ; %
        b                   ; %
        c                   ; %
        d                   ; %
        delta_bz            ; %
        delta_a_dz          ; %
        t                   ; %
        d_4app              ; %
        amp0                ; %
        amp1                ; %
        amp2                ; %
        pockels_level       ; %
        aod_delay_cycles    ; %
        num_drives          ; %
        num_aods            ; %
        timing_offsets      ; %
    end
    
    
    methods
        function obj = DriveCoeffs(synth_clock_freq, a, b, c, d, t, d_4app, amp0, amp1, amp2, pockels_level, aod_delay_cycles, delta_bz, delta_a_dz, timing_offsets)
            %% DriveCoeffs constructor 
            % -------------------------------------------------------------
            % Syntax: 
            %   DriveCoeffs = DriveCoeffs(synth_clock_freq, a, b, c, d, t, 
            %                             d_4app, amp0, amp1, amp2, 
            %                             pockels_level, aod_delay_cycles, 
            %                             delta_bz, delta_a_dz)
            % -------------------------------------------------------------
            % Inputs:
            %   synth_clock_freq(INT):
            %       Synthetizer clock speed for rescaling. 0 to prevent
            %       rescaling
            %
            %   a (4 X Ndrives INT)
            %       scaled a values to send to the controller 
            %
            %   b (4 X Ndrives INT)
            %       scaled b values to send to the controller
            %
            %   c (4 X Ndrives INT)
            %       scaled c values to send to the controller
            %
            %   d (4 X Ndrives INT)
            %       scaled d values to send to the controller
            %
            %   t (4 X Ndrives INT)
            %       t values to send to the controller (ramp durations)
            %
            %   d_4app (4 X Ndrives INT)
            %       d_4app values to send to the controller. d_4app values 
            %       need fixed point scaling before sending
            %
            %   amp0 (4 X Ndrives INT)
            %       amp0 values to send to the controller
            %
            %   amp1 (4 X Ndrives INT)
            %       amp1 values to send to the controller - UNUSED FOR NOW
            %
            %   amp2 (4 X Ndrives INT)
            %       amp2 values to send to the controller - UNUSED FOR NOW
            %
            %   pockels_level (4 X Ndrives INT)
            %       pockels_level values to send to the controller
            %
            %   aod_delay_cycles (4 X Ndrives INT)
            %       aod_delay_cycles values to send to the controller
            %
            %   delta_bz (4 X Ndrives INT)
            %       delta_bz values to send to the controller. delta_bz 
            %       values need fixed point scaling before sending. 
            %
            %   delta_a_dz (4 X Ndrives INT)
            %       delta_a_dz values to send to the controller. delta_a_dz 
            %       values need fixed point scaling before sending
            % -------------------------------------------------------------
            % Outputs: 
            % -------------------------------------------------------------
            % Extra Notes:
            % -------------------------------------------------------------
            % Author(s):
            %   Vicky Griffiths, Boris Marin, Geoffrey Evans, Paul Kirkby,
            %   Srinivas Nadella, Antoine Valera
            %---------------------------------------------
            % Revision Date:
            %   22-03-2019
            %
            % See also: drives_for_synth_fpga, delta_bz_dc,
            % delta_a_delta_z_dc, d_4app
            
            %% TODO : add galvo x and y
            
            %% Set synth_clock_freq first, as some scaling requires it
            obj.synth_clock_freq = synth_clock_freq;
            
            obj.num_drives = size(a, 2);
            obj.num_aods = size(a, 1);
            
            obj.a = a; % a is rescaled
            obj.b = b; % b is rescaled
            obj.c = c; % c is rescaled
            obj.d = d; % d is rescaled
            obj.delta_bz = delta_bz; % delta_bz is rescaled
            obj.delta_a_dz = delta_a_dz; % delta_a_dz is rescaled and converted to fixed point
            if size(d,2) == size(t,2)
                obj.t = t;
            else %% Pointing mode
                obj.t = repmat(t(:,1),1,size(d,2));
            end
            obj.d_4app = d_4app; % d_4app is converted to fixed point
            obj.amp0 = amp0;
            obj.amp1 = amp1; % UNUSED FOR NOW
            obj.amp2 = amp2; % UNUSED FOR NOW
            obj.pockels_level = pockels_level;
            obj.aod_delay_cycles = aod_delay_cycles; 
            obj.timing_offsets = timing_offsets;
        end
        
        function set.a(obj, a)
            %% Set method for the a's value. Include rescaling
            % -------------------------------------------------------------
            % Syntax: 
            %   DriveCoeffs.a = a;
            % -------------------------------------------------------------
            % Inputs:
            %   a (M X Ndrives INT)
            %       0-order parameter for ramp generation
            % -------------------------------------------------------------
            % Outputs: 
            % -------------------------------------------------------------
            % Extra Notes:
            %   Rescaling by .* 2^32 / obj.synth_clock_freq
            %   If obj.synth_clock_freq is 0, values are not rescaled.
            % -------------------------------------------------------------
            % Author(s):
            %   Vicky Griffiths, Geoffrey Evans, Antoine Valera
            %---------------------------------------------
            % Revision Date:
            %   24-03-2019
            %
            % See also: SynthFpga, drives_for_synth_fpga, linear_driver, 
            %       nonlinear_driver,
            
            %% If provided, rescale a parameter
            if obj.synth_clock_freq
                obj.a   = a .* 2^32 / obj.synth_clock_freq;    
            else
                obj.a   = a;
            end            
        end
        
        
        function set.b(obj, b)
            %% Set method for the b's value. Include rescaling
            % -------------------------------------------------------------
            % Syntax: 
            %   DriveCoeffs.b = b;
            % -------------------------------------------------------------
            % Inputs:
            %   b (M X Ndrives INT)
            %       1st-order parameter for ramp generation
            % -------------------------------------------------------------
            % Outputs: 
            % -------------------------------------------------------------
            % Extra Notes:
            %   Rescaling by 536870912 / obj.synth_clock_freq^2
            %   If obj.synth_clock_freq is 0, values are not rescaled.
            % -------------------------------------------------------------
            % Author(s):
            %   Vicky Griffiths, Geoffrey Evans, Antoine Valera
            %---------------------------------------------
            % Revision Date:
            %   24-03-2019
            %
            % See also: SynthFpga, drives_for_synth_fpga, linear_driver, 
            %       nonlinear_driver,
            
            %% If provided, rescale b parameter
            if obj.synth_clock_freq
                obj.b   = b .* 2^32 / obj.synth_clock_freq^2 / 2^3; 
            else
                obj.b   = b;
            end
        end
        
        function set.c(obj, c)
            %% Set method for the c's value. Include rescaling
            % -------------------------------------------------------------
            % Syntax: 
            %   DriveCoeffs.c = c;
            % -------------------------------------------------------------
            % Inputs:
            %   c (M X Ndrives INT)
            %       2nd-order parameter for ramp generation
            % -------------------------------------------------------------
            % Outputs: 
            % -------------------------------------------------------------
            % Extra Notes:
            %   Rescaling by 3.5184e+13 / obj.synth_clock_freq^3
            %   If obj.synth_clock_freq is 0, values are not rescaled.
            % -------------------------------------------------------------
            % Author(s):
            %   Vicky Griffiths, Geoffrey Evans, Antoine Valera
            %---------------------------------------------
            % Revision Date:
            %   24-03-2019
            %
            % See also: SynthFpga, drives_for_synth_fpga, linear_driver, 
            %       nonlinear_driver,
            
            %% If provided, rescale c parameter            
            if obj.synth_clock_freq
                obj.c   = c .* 2^32 / obj.synth_clock_freq^3 * 2^13;  
            else
                obj.c   = c;
            end
        end
        
        function set.d(obj, d)
            %% Set method for the d's value. Include rescaling
            % -------------------------------------------------------------
            % Syntax: 
            %   DriveCoeffs.d = d;
            % -------------------------------------------------------------
            % Inputs:
            %   d (M X Ndrives INT)
            %       3rd-order parameter for ramp generation
            % -------------------------------------------------------------
            % Outputs: 
            % -------------------------------------------------------------
            % Extra Notes:
            %   Rescaling by 1.4412e+17 / obj.synth_clock_freq^4
            %   If obj.synth_clock_freq is 0, values are not rescaled.
            % -------------------------------------------------------------
            % Author(s):
            %   Vicky Griffiths, Geoffrey Evans, Antoine Valera
            %---------------------------------------------
            % Revision Date:
            %   24-03-2019
            %
            % See also: SynthFpga, drives_for_synth_fpga, linear_driver, 
            %       nonlinear_driver,
            
            %% If provided, rescale d parameter  
            if obj.synth_clock_freq
                obj.d   = d .* 2^32 / obj.synth_clock_freq^4 * 2^25;
            else
                obj.d   = d;
            end
        end
        
        function set.timing_offsets(obj, timing_offsets)
            %% Convert timing_offsets for MC (scaled for a's, and 
            %% converted to fixed point + formatting for header)
            % -------------------------------------------------------------
            % Syntax: 
            %   DriveCoeffs.timing_offsets = timing_offsets;
            % -------------------------------------------------------------
            % Inputs:
            %   timing_offsets (1 X 4 Float)
            %       set timing_offsets for calibration correction in 3D MC.
            %       Timing offsets corected for wavelength, as output by
            %       AolParams. 
            % -------------------------------------------------------------
            % Outputs: 
            % -------------------------------------------------------------
            % Extra Notes:
            %   If obj.synth_clock_freq is 0, values are not rescaled.
            % -------------------------------------------------------------
            % Author(s):
            %   Antoine Valera
            %---------------------------------------------
            % Revision Date:
            %   24-03-2019
            %
            % See also: AolParams
            
            %% If provided, rescale and convert timing_offsets to fixed point
            if obj.synth_clock_freq
                obj.timing_offsets = timing_offsets .* (2^32 / obj.synth_clock_freq);
                
                obj.timing_offsets = fi(obj.timing_offsets', true, 32, 32);
                obj.timing_offsets = split_4_bytes(typecast(obj.timing_offsets.int(:),'uint32'))';
                obj.timing_offsets = obj.timing_offsets(:)';
            else
                obj.timing_offsets   = timing_offsets;
            end
        end
       
        function set.d_4app(obj, d_4app)        
            %% Set method for the d_4app value and fixed point conversion
            % -------------------------------------------------------------
            % Syntax: 
            %   DriveCoeffs.d = d;
            % -------------------------------------------------------------
            % Inputs:
            %   d_4app (M X Ndrives INT)
            %       set d_4app values for 3D MC
            % -------------------------------------------------------------
            % Outputs: 
            % -------------------------------------------------------------
            % Extra Notes:
            %   If obj.synth_clock_freq is 0, values are not rescaled.
            % -------------------------------------------------------------
            % Author(s):
            %   Vicky Griffiths, Antoine Valera
            %---------------------------------------------
            % Revision Date:
            %   24-03-2019
            %
            % See also: get_d_4app, drives_for_synth_fpga

            %% If provided, convert d_4app to fixed point 
            if obj.synth_clock_freq
                obj.d_4app = fi(d_4app, true, 32, 16); 
                obj.d_4app = reshape(typecast(obj.d_4app.int(:),'uint32'),size(obj.d_4app));
            else
                obj.d_4app   = d_4app;
            end
        end
                
        function set.delta_bz(obj, delta_bz)
            %% Set method for the delta_bz_dc value and rescaling
            % -------------------------------------------------------------
            % Syntax: 
            %   DriveCoeffs.delta_bz_dc = delta_bz_dc;
            % -------------------------------------------------------------
            % Inputs:
            %   delta_bz_dc (M X Ndrives INT)
            %       set delta_bz_dc for magnification correction in 3D MC.
            % -------------------------------------------------------------
            % Outputs: 
            % -------------------------------------------------------------
            % Extra Notes:
            %   If obj.synth_clock_freq is 0, values are not rescaled.
            % -------------------------------------------------------------
            % Author(s):
            %   Vicky Griffiths, Antoine Valera
            %---------------------------------------------
            % Revision Date:
            %   24-03-2019
            %
            % See also: delta_bz_dc, drives_for_synth_fpga
            
            %% If provided, rescale delta_bz to fixed point 
            if obj.synth_clock_freq
                obj.delta_bz   = delta_bz .* 2^32 / obj.synth_clock_freq^2 / 2^3;  % scaled as b's 
            else
                obj.delta_bz   = delta_bz;
            end
        end
        
        function set.delta_a_dz(obj, delta_a_dz)
            %% Set method for the delta_a_dz value + conversion and rescaling
            % -------------------------------------------------------------
            % Syntax: 
            %   DriveCoeffs.delta_a_dz = delta_a_dz;
            % -------------------------------------------------------------
            % Inputs:
            %   delta_a_dz (M X Ndrives INT)
            %       set delta_a_dz for magnification correction in 3D MC.
            % -------------------------------------------------------------
            % Outputs: 
            % -------------------------------------------------------------
            % Extra Notes:
            %   If obj.synth_clock_freq is 0, values are not rescaled.
            % -------------------------------------------------------------
            % Author(s):
            %   Vicky Griffiths, Antoine Valera
            %---------------------------------------------
            % Revision Date:
            %   24-03-2019
            %
            % See also: delta_a_delta_z_dc, drives_for_synth_fpga
            
            %% If provided, rescale delta_a_dz and convert to fixed point 
            if obj.synth_clock_freq
                obj.delta_a_dz = delta_a_dz  .* 2^32 / obj.synth_clock_freq; % scaled as a's

                %% delta_a_dz conversion
                obj.delta_a_dz = fi(obj.delta_a_dz, true, 32, 0); 
                obj.delta_a_dz = reshape(typecast(obj.delta_a_dz.int(:),'int32'), size(obj.delta_a_dz));    
            else
                obj.delta_a_dz   = delta_a_dz;
            end
        end
        
        
        function drive_section = section(obj, start_index, end_index)
            %% Called to return a subsection of the data
            % Typically used to collect groups of 13 drives, as required by
            % the current communication protocol
            % -------------------------------------------------------------
            % Syntax: 
            %   DriveCoeffs.section(start_index, end_index)
            % -------------------------------------------------------------
            % Inputs:
            %   start_index (INT)
            %       The beginning of the section to slice
            %   end_index (INT)
            %       The end of the section to slice
            % -------------------------------------------------------------
            % Outputs: 
            % -------------------------------------------------------------
            % Extra Notes:
            % -------------------------------------------------------------
            % Author(s):
            %   Vicky Griffiths, Geoffrey Evans, Antoine Valera
            %---------------------------------------------
            % Revision Date:
            %   22-03-2019
            %
            % See also: make_xy_records
            
            a_section = obj.a(:,start_index:end_index);
            b_section = obj.b(:,start_index:end_index);
            c_section = obj.c(:,start_index:end_index);
            d_section = obj.d(:,start_index:end_index);
            delta_bz_section = obj.delta_bz(:,start_index:end_index);
            delta_a_dz_section = obj.delta_a_dz(:,start_index:end_index);            
            t_section = obj.t(:,start_index:end_index);
            d_4app_section = obj.d_4app(:,start_index:end_index);
            amp0_section = obj.amp0(:,start_index:end_index);
            amp1_section = obj.amp1(:,start_index:end_index);
            amp2_section = obj.amp2(:,start_index:end_index);
            pockels_level_section = obj.pockels_level(:,start_index:end_index);
            aod_delay_cycles_section = obj.aod_delay_cycles(:,start_index:end_index);
            drive_section = DriveCoeffs(0, a_section, b_section, c_section, d_section, t_section, d_4app_section, amp0_section, amp1_section, amp2_section, pockels_level_section, aod_delay_cycles_section, delta_bz_section, delta_a_dz_section, obj.timing_offsets);
        end
    end    
end

