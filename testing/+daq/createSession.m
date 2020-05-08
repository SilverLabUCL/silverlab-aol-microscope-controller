function s = createSession(~)
    fprintf(['Using simulated NI session.\n',...
             'If you want to use a NI instruments board, remove the folder ./testing from matlab path\n',...
             'This is done automatically if you use the controller in online mode\n'])
	s = struct('addAnalogOutputChannel', @(a,b,c) 1, 'outputSingleScan', @(v) 2, 'addDigitalChannel', @(a,b,c) 3, 'Channels', @(a,b,c) 4);
end

