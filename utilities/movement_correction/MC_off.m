

function [out, out2] = MC_off(controller, visualize, non_default_resolution, non_default_aa)
%% Disable movement correction and any running scan, reset main scan drives
% this includes background mc
% If visualize is true we restart imaging once MC is stopped
%
    if nargin < 1 || isempty(controller)
        controller = get_existing_controller_name(true);
    end
    
    out = 0; out2 = 0;

    %% Deal with any running MC tracking
    controller.stop_mc_logging_or_plotting();
    
    %% Reset original drives resolutions
    controller.restore_ref_drives();
    
    if nargin < 2 || isempty(visualize)
        visualize = true;
    end
    if nargin < 3 || isempty(non_default_resolution)
        non_default_resolution = controller.scan_params.mainscan_x_pixel_density;
    end
    if nargin < 4 || isempty(non_default_aa)
        non_default_aa = controller.scan_params.acceptance_angle;
    end
   
    controller.stop_MC();
    controller.reset_frame_and_send('raster',non_default_resolution, non_default_aa);
    
    if visualize
        start(timer('StartDelay', 0.1, 'TimerFcn', @(~,~)controller.stop_image(true,true)));
        controller.live_image('safe', true);
    end
end

