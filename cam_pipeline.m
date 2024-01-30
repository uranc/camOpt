%% Setup ops
gainRaw = 75;
exposureTime = 19501; 
fps = 30; % applies to Nano cam only!

file_name = 'Bl6_433_290124';

%% Preview Cams
previewCameras(gainRaw, exposureTime, fps)

%% Run Genie
runGenie2(file_name, gainRaw, exposureTime)

%% Run Nano
runNano2(file_name, gainRaw, exposureTime, fps)