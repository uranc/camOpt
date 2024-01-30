# camOpt
Record video from Dalsa Teledyne cameras using GigE backend in matlab

## Example Pipeline on how to use the new fucntions:

``` matlab
% Setup Ops
gainRaw = 75;
exposureTime = 19501; 
fps = 30; % applies to Nano cam only!
file_name = 'Bl6_433_290124';

% Preview either/both Cameras
previewCameras(gainRaw, exposureTime, fps)

% Run Genie or Nano recording
runGenie2(file_name, gainRaw, exposureTime)
runNano2(file_name, gainRaw, exposureTime, fps)
```
