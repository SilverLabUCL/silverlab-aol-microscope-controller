toolbox_root = fileparts(fileparts(which('Controller.m')));

%% List files in microscope_driver
fun = fullfile([toolbox_root,'/Core/microscope_drivers/'],'*.m');

%% Convert to p-files
pcode(fun,'-inplace')

files = dir(fun);
for file = 1:numel(files)
    delete([files(file).folder,'/',files(file).name]);
end

if isfile([toolbox_root,'/TODO.txt'])
    delete([toolbox_root,'/TODO.txt']);
end

if isfile([toolbox_root,'/Core/configuration_file_path.ini'])
    delete([toolbox_root,'/Core/configuration_file_path.ini']);
end

if isfile([toolbox_root,'/Core/+default/calibration.ini'])
    delete([toolbox_root,'/Core/+default/calibration.ini']);
end
if isfile([toolbox_root,'/Core/+default/setup.ini'])
    delete([toolbox_root,'/Core/+default/setup.ini']);
end

files = dir([toolbox_root,'/**/*.pdb']);
for file = 1:numel(files)
    delete([files(file).folder,'/',files(file).name]);
end