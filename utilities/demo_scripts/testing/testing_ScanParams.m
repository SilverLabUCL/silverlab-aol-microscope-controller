%% This scripts test variable aspect of drive generation (raster and 
% miniscan modes). For advanced pacth generation, see
% demo_patch_generation.m

test_full_frame = true;
test_full_frame_special_cases = true;
test_miniscans_fixed_length  = true;
test_miniscan_rotations = true;
test_miniscans_variable_length_or_res = true;

%% Initial reset
c.reset_scan_params('raster')

if test_full_frame

    %% ===================
    %% Testing Raster mode
    %% ===================

    %% Set all the scan_params to the default value
    c.reset_frame_and_send('raster')
    c.scan_params.plot_drives();title('default Raster mode')

    %% Test downsampled full frame
    tic
    c.scan_params.mainscan_x_pixel_density = 128;
    toc
    c.scan_params.plot_drives();title('Raster mode downsampled to 128 lines')

    %% Test rotated, downsampled full frame
    tic
    c.scan_params.angles = [20,40,60];
    toc
    c.scan_params.plot_drives();title('Raster mode downsampled to 128 lines, rotated')

    %% Test offset, rotated, downsampled full frame
    tic
    c.scan_params.start_norm_raw = [0;0.5;1];
    toc
    c.scan_params.plot_drives();title('Raster mode downsampled to 128 lines, rotated, offset in Y and Z')

    %% Test downsampling of an offset, rotated, downsampled full frame
    tic
    c.scan_params.mainscan_x_pixel_density = 32;
    toc
    c.scan_params.plot_drives();title('Raster mode re-downsampled to 32 lines, with rotation and offsets')

    %% Test on top of it, and keeping the number of lines constant we change the number of voxels per line
    tic
    c.scan_params.voxels_for_ramp = 8;
    toc
    c.scan_params.plot_drives('full');title('Raster mode re-downsampled to 32 lines, with extra X resampling to 8 voxels per line, with rotation and offsets')

    %% ===================
    %% What you can't do
    % The following commands should all return an clear error
    
    %% --> Trying to change the number of drives directly. you must 
    % use mainscan_x_pixel_density instead
    % c.scan_params.num_drives = 128; 
    
    %% --> Trying set drives coordinates directly; 
    % In raster mode, the FOV is of size 2 normalized units, whioch is
    % scaled in um using the acceptance angle. You can offset and rotate
    % the FOV, but the corresponding area will remain constant. To change
    % that, you must switch to miniscan mode
    % c.scan_params.start_norm_raw = c.scan_params.start_norm; 
    
    %%  --> Trying set lines with different number of pixels.
    % a.k.a variable resolution. This can only be achived in miniscan mode
    % with c.scan_params.fixed_res set to false
    % c.scan_params.voxels_for_ramp = randi(20, 1, c.scan_params.num_drives); 

    %%  --> Trying set lines with different length.
    % a.k.a variable resolution. This can only be achived in miniscan mode
    % with c.scan_params.fixed_len set to false. and even there, only
    % start_norm_raw can be edited.
    % c.scan_params.start_norm(1,:) = randi(20, 1, c.scan_params.num_drives); 
    
end

if test_full_frame_special_cases
    
    %% ===================
    %% Testing bizarre or corner case scenario
    %% ===================

    %% Test resolution mainscan resolution of 1 
    % Useless but should not fail. This generate a 1*1 pixel FOV. Without 
    % offset, the pixel is set in the corner
    c.reset_frame_and_send('raster')
    tic    
    c.scan_params.mainscan_x_pixel_density = 1; 
    c.scan_params.plot_drives('full');title('Raster mode, with a single point (method 1)')
    tic
    
    %% Test single line
    toc
    c.scan_params.voxels_for_ramp = 64; % just increase the resolution
    c.scan_params.plot_drives('full');title('Raster mode, with a single line but several voxels')
    toc
    
    %% Test single line
    toc
    c.scan_params.mainscan_x_pixel_density = 64; 
    c.scan_params.voxels_for_ramp = 1; 
    c.scan_params.plot_drives('full');title('Raster mode, with a single point per ramp (method 2)')
    toc
    
    %% Test changing the resolution of each line
    tic
    c.scan_params.fixed_res = false;
    c.scan_params.mainscan_x_pixel_density = 32; % downsampled
    c.scan_params.angles = [20,40,60]; % rotated
    c.scan_params.start_norm_raw = [0;0.5;1]; % offset
    c.scan_params.voxels_for_ramp = randi(30, 1, c.scan_params.num_drives); % random resolution for each line
    toc
    c.scan_params.plot_drives('full');title('Raster mode downsampled to 32 lines, with variable line resolution, with rotation and offsets')

    %% --> Trying resample a scan with variable resolution
    % This could be fixed, but it's risky so we may want to keep that
    % disabled
    % c.scan_params.mainscan_x_pixel_density = 128;
    % c.scan_params.plot_drives('full');title('Raster mode re-downsampled to 32 lines, with variable line resolution, with rotation and offsets')

end

if test_miniscans_fixed_length
    
    %% ===================
    %% Testing Miniscan mode
    %% ===================

    %% Test default miniscan, aka a full frame scan (but editable)
    c.reset_frame_and_send('miniscan');
    c.scan_params.plot_drives();title('Miniscan mode, default')

    %% Test downsampling on minisan
    tic
    c.scan_params.mainscan_x_pixel_density = 128;
    toc
    c.scan_params.plot_drives('full');title('Miniscan mode, full frame downsampled to 128 lines')

    %% Test manual creation of a miniscan
    % Create a miniscan of of 0.5 * 0.25 norm units, based on the non default res
    x_norm_size = 0.5;
    x_norm_start = -1;
    y_norm_size = 0.25;
    y_norm_start = -1;
    start = zeros(3, round(c.scan_params.mainscan_x_pixel_density * (x_norm_size/2)));
    stop = zeros(3, round(c.scan_params.mainscan_x_pixel_density * (x_norm_size/2)));
    start(1,:) = x_norm_start + 0;
    stop(1,:) = x_norm_start + x_norm_size;
    start(2,:) = linspace(y_norm_start, y_norm_start + y_norm_size, size(start,2));
    stop(2,:) = linspace(y_norm_start, y_norm_start + y_norm_size, size(start,2));

    tic
    c.scan_params.start_norm_raw = start;
    c.scan_params.stop_norm_raw = stop;
    toc
    c.scan_params.plot_drives();title('Miniscan mode, patch, based on full frame downsampled to 128 lines')

    %% Test resamplig of the miniscan
    tic
    c.scan_params.voxels_for_ramp = 8;
    c.scan_params.plot_drives('full');title('Miniscan mode, patch, based on full frame downsampled to 128 line, with X resampling to 8 voxels per line')
    toc

    %% Test angling of miniscan
    tic
    c.scan_params.angles = [5, 10, 15];
    c.scan_params.plot_drives('full');title('Miniscan mode, patch, based on full frame downsampled to 128 lines, rotated')
    toc

    %% Test offset of miniscan
    % Note : in miniscan mode, you need to add manually the offset, and cannot
    % use start_norm_raw as for full_frame. You need to update the value for
    % both start and stop_norm_raw
    tic
    c.scan_params.start_norm_raw = c.scan_params.start_norm_raw + [1;-1;2];
    c.scan_params.stop_norm_raw = c.scan_params.stop_norm_raw + [1;-1;2];
    c.scan_params.plot_drives('full');title('Miniscan mode, patch, based on full frame downsampled to 128 lines, rotated, offset')
    toc

    %% ===================
    %% What you can't do
    % The following commands should all return an clear error
    
    %% --> Trying to change the main resolution while a miniscan already exist
    % --> valid only for full frame
    % c.scan_params.mainscan_x_pixel_density = 128;
end


if test_miniscan_rotations
    
    %% ===================
    %% Testing what happens to a rotating miniscan
    %% ===================
    
    %% Create miniscan
    c.reset_frame_and_send('miniscan', 128); % same as c.scan_params.mainscan_x_pixel_density = 128;

    %% Create a miniscan of of 0.5 * 0.25 norm units, based on the nondefault res
    x_norm_size = 0.5;
    x_norm_start = -1;
    y_norm_size = 0.25;
    y_norm_start = -1;
    
    start = zeros(3, round(c.scan_params.mainscan_x_pixel_density * (x_norm_size/2)));
    stop = zeros(3, round(c.scan_params.mainscan_x_pixel_density * (x_norm_size/2)));
    start(1,:) = x_norm_start + 0;
    stop(1,:) = x_norm_start + x_norm_size;
    start(2,:) = linspace(y_norm_start, y_norm_start + y_norm_size, size(start,2));
    stop(2,:) = linspace(y_norm_start, y_norm_start + y_norm_size, size(start,2));
    
    %% Test rotation for each axis
    n = get(gcf,'Number');
    figure(n+1);xlim([-1,1]);ylim([-1,1]);zlim([-1,1]);hold on;
    for anglex = 0:5:360
        c.scan_params.angles = [anglex, 0, 0];
        c.scan_params.plot_drives('simple',n+1);title(sprintf('same scan, rotation by X = %i, Y = %i, Z = %i',anglex, 0, 0));
    end
    pause(1)
    for angley =  0:5:360
        c.scan_params.angles = [0, angley, 0];
        c.scan_params.plot_drives('simple',n+1);title(sprintf('same scan, rotation by X = %i, Y = %i, Z = %i',0, angley, 0));
    end
    pause(1)
    for anglez = 0:5:360
        c.scan_params.angles = [0, 0, anglez];
        c.scan_params.plot_drives('simple',n+1);title(sprintf('same scan, rotation by X = %i, Y = %i, Z = %i',0, 0, anglez));
    end
    pause(1)
end


if test_miniscans_variable_length_or_res
    
    
    %% ===================
    %% Testing what happens to a rotating miniscan
    %% ===================
    
    %% Create miniscan
    c.reset_frame_and_send('miniscan', 32); % same as c.scan_params.mainscan_x_pixel_density = 128;

    %% Create a miniscan of of 0.5 * 0.25 norm units, based on the nondefault res
    x_norm_size = 0.5;
    x_norm_start = -1;
    y_norm_size = 0.25;
    y_norm_start = -1;
    
    start = zeros(3, round(c.scan_params.mainscan_x_pixel_density * (x_norm_size/2)));
    stop = zeros(3, round(c.scan_params.mainscan_x_pixel_density * (x_norm_size/2)));
    start(1,:) = x_norm_start + 0;
    stop(1,:) = x_norm_start + x_norm_size;
    start(2,:) = linspace(y_norm_start, y_norm_start + y_norm_size, size(start,2));
    stop(2,:) = linspace(y_norm_start, y_norm_start + y_norm_size, size(start,2));
    c.scan_params.start_norm_raw = start;
    c.scan_params.stop_norm_raw = stop;
    
    %% Test variable resolution for each line
    tic
    c.scan_params.fixed_res = false;
    c.scan_params.voxels_for_ramp = randi(20, 1, c.scan_params.num_drives);
    c.scan_params.plot_drives('full');title('Miniscan mode, patch, based on full frame downsampled to 32 lines, with X resampling to variable number of voxels per line')
    toc
    
    %% Test resetting fixed resolution for each line
    c.scan_params.fixed_res = true;
    
    %% Test variable length for each line
    tic
    c.scan_params.fixed_len = false;
    c.scan_params.stop_norm_raw = c.scan_params.stop_norm_raw + randi(10, 1, c.scan_params.num_drives)/10;
    c.scan_params.plot_drives('full');title('Miniscan mode, patch, based on full frame downsampled to 32 lines, with each line having a different res')
    toc

    %% Test variable length and res for each line
    tic
    c.scan_params.fixed_res = false;
    c.scan_params.voxels_for_ramp = randi(30, 1, c.scan_params.num_drives);
    c.scan_params.plot_drives('full');title('Miniscan mode, patch, based on full frame downsampled to 128 lines, with X resampling to variable number of voxels per line and length')
    toc
    
end