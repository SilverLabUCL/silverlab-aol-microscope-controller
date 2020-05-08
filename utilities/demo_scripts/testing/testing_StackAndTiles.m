tiling_obj = StackAndTiles();

%% Extend stack range at the top (should change N planes and tiling Z lim)
tiling_obj.z_start = 10

%% Extend stack range at the bottom (should change N planes and tiling Z lim)
tiling_obj.z_stop = -20

%% Set stack bottom more positive than previous stack top (should change N planes, tiling Z lim and swap z_steps)
tiling_obj.z_stop = 20

%% Change Z_step sign (should revert stack direction)
tiling_obj.z_step_res = tiling_obj.z_step_res * -1

%% Change Z_step sign and value again (should revert stack direction and change N planes)
tiling_obj.z_step_res = tiling_obj.z_step_res * -2

%% Set a negative, decimal value to z planes (should do nothing)
tiling_obj.z_planes = abs(tiling_obj.z_planes) * -1.05;

%% Double the number of planes (should change step res)
tiling_obj.z_planes = tiling_obj.z_planes * 2

%% Set num planes to 0 (Should set it to 1, and then set Z_stop as z_start)
tiling_obj.z_planes = 0

%% Set Z start back to a different value (Should set z_planes to 2 and adjust z_step_res)
tiling_obj.z_start = -10
tiling_obj.z_step_res = 1; %just set a few more planes for the following steps


%% Changed tiling Z start should do like changing Z start
tiling_obj.tile_xyz_start(3) = -20


%% Changed tiling Z stop should do like changing Z stop
tiling_obj.tile_xyz_stop(3) = 20

%% Updating XYZ tile with this function should behave as setting Z stop. Here it should swap the Z and X axes (for X-Y, negative values ends in tiling start)
tiling_obj.tile_xyz_stop = [-10,20,-30]

%% Updating XYZ tile with this function should behave as setting Z start. Here it should do like changing Z start
tiling_obj.tile_xyz_start = [10,-20,-15]

%% Adding a XYZ tile within the range
tiling_obj.add_tile([10,-20,-15]);
tiling_obj

%% Adding a XYZ tile extending negative X
tiling_obj.add_tile([-10,-20,-15]);
tiling_obj

%% Adding a XYZ tile extending positive X and Y and Z
tiling_obj.add_tile([50,30,25]);
tiling_obj

