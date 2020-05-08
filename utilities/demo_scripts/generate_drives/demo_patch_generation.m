%% DEMONSTRATION SCRIPT
% This script demonstrates how to generate some patches using scripts
% -------------------------------------------------------------------------
% Content : 
%
% * Example 1: Generate a series of horizontal patches of fixed size.  
%
% * Example 2: Generate a series of patches of fixed size but random orientation
%
% * Example 3: Generate a series of patches of random size but fixed orientation
% -------------------------------------------------------------------------
% Requirements : 
% 
% * You need a Controller object in you workspace. If you don't have one,
%   type:
%   c = Controller(false);
%
% * If you plan to use conversion to um, you need to have correct
%   Calibration.ini values. For calculation in normalized space, you can
%   ignore this requirement
%
% -------------------------------------------------------------------------

%% ------------------------------------------------------------------------
%% Example 1
%% ------------------------------------------------------------------------

%% Generate a series of horizontal patches of fixed size. 
% Note : Patches are defined by a start point ("corner") and three 3D
% vectors : v1 is the linescan, v2 indicates the width of a pacth (and is
% usually orthogonal to v1) and v3 defines the thickness of a volume.
% For a point scan v1, v2 and v3 are [0,0,0]
% For a point scan     v2 and v3 are [0,0,0]
% For a patch scan            v3 is  [0,0,0]

%% Reset frame to default resolution, in case you were experimenting with 
% some values
c.reset_frame_and_send('raster')

%% Prepare some variables
n_ROIs      = 10;
segment_len = 30;
res         = 500;

%% Set patches location and direction
corner_x    = linspace(1,res,n_ROIs);
corner_y    = randi(res,1,n_ROIs);
corner_z    = linspace(1,res,n_ROIs);
corner      = [corner_x;corner_y;corner_z];
template_v1 = [segment_len;0;0];
template_v2 = [0;segment_len;0];

%% Generate boxes
boxes       = c.scan_params.generate_miniscan_boxes(...,
                  corner                            ,...
                  repmat(template_v1,1,n_ROIs)      ,...
                  repmat(template_v2,1,n_ROIs)      ,...
                  zeros(3,n_ROIs)                   );
              
%% Set boxes
c.set_miniscans(boxes);

%% Plot result
c.scan_params.plot_drives()

%% You could now send the drives and scan if necessary

%% ------------------------------------------------------------------------
%% Example 2
%% ------------------------------------------------------------------------

%% Generate a series of patches of fixed size but random orientation

%% Prepare some variables
n_ROIs      = 10;
segment_len = 30;
res         = 500;

%% Set patches location and direction
corner_x    = linspace(1,res,n_ROIs);
corner_y    = randi(res,1,n_ROIs);
corner_z    = linspace(1,res,n_ROIs);
corner      = [corner_x;corner_y;corner_z];
rand_line_scans = rand(3,n_ROIs);
template_v1 = segment_len * rand_line_scans ./ vecnorm(rand_line_scans);
template_v2 = [0;segment_len;0];

%% Generate boxes
boxes       = c.scan_params.generate_miniscan_boxes(...,
                  corner                            ,...
                  template_v1                       ,... % No repmat this time
                  repmat(template_v2,1,n_ROIs)      ,...
                  zeros(3,n_ROIs)                   );

%% Set boxes           
c.set_miniscans(boxes);

%% Plot result
c.scan_params.plot_drives()


%% ------------------------------------------------------------------------
%% Example 3
%% ------------------------------------------------------------------------

%% Generate a series of patches of random size but fixed orientation

%% Prepare some variables
n_ROIs      = 10;
segment_len = 30;
res         = 500;

%% Set patches location and direction
corner_x    = linspace(1,res,n_ROIs);
corner_y    = randi(res,1,n_ROIs);
corner_z    = linspace(1,res,n_ROIs);
corner      = [corner_x;corner_y;corner_z];
template_v1 = [segment_len;0;0];
template_v2 = randi(50, 3, n_ROIs);

%% Generate boxes
boxes = c.scan_params.generate_miniscan_boxes(      ...,
                  corner                            ,...
                  repmat(template_v1,1,n_ROIs)      ,...
                  template_v2                       ,...
                  zeros(3,n_ROIs)                   );
              
%% Set boxes  
c.set_miniscans(boxes);

%% Plot result
c.scan_params.plot_drives()