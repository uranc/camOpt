%Same as runGenie with preview
%Main Settings to change for brightness:
% - var: exposureTime: 15000-30000 
% - var: gainRaw (0 - 480); 110 default
% - var: fps (0 - 65); 30 default FramesPerSec
% Note: max fps is dependent on the exposureTime. If exposureTime is too high
% fps will be less.

% exposureTime = 19501; 
% gainRaw = 75;
% fps = 30; % applies to Nano cam only!

function previewCameras(gainRaw, exposureTime, fps)

if nargin==0
    gainRaw = 75;  
    exposureTime = 19501; 
    fps = 30;
elseif nargin==1
    exposureTime = 19501; 
    fps = 30;
elseif nargin==2
    fps = 30;
end

gigeinfo = imaqhwinfo('gige');
numCamerasFound = numel(gigeinfo.DeviceIDs);
fprintf('Viewing %d camera, %s\n',numCamerasFound, gigeinfo.DeviceInfo.DeviceName);

% Disconnect from all cameras from main MATLAB process and workers
delete(imaqfind);

for labindex = 1:numCamerasFound
    cameraID = labindex;
    v(labindex) = videoinput('gige', cameraID);
    s(labindex) = v(labindex).Source;
    
    % Configure properties common for both cameras
    s(labindex).PacketSize =  8192;  % alt val: 8000 or 8192
%     s(labindex).ExposureTime = 10000;
    s(labindex).LineSelector = 'Line4';
    v(labindex).FramesPerTrigger = Inf;
    % Main settings
    s(labindex).ExposureTime = exposureTime;
    
    % Configure properties that are camera specific
    if strcmp(s(labindex).DeviceModelName, 'Nano-M1450')
        s(labindex).Gain = 3.9;  %Gain Settings!
        s(labindex).acquisitionFrameRateControlMode = 'Programmable';
        s(labindex).AcquisitionFrameRate = fps;
        s(labindex).LineInverter = 'False';
        s(labindex).outputLineSource='PulseOnStartofExposure';
        s(labindex).outputLinePulseDuration = 1000;
        s(labindex).outputLinePulseDelay = 0; 
        s(labindex).GainRaw = gainRaw;
    elseif strcmp(s(labindex).DeviceModelName, 'Genie M1280')
        s(labindex).AcquisitionFrameRateRaw =  24560; %old val: 24000;
        s(labindex).OutputLineMode = 'EventDriven';
        s(labindex).OutputLinePulseDuration = 1000;
        s(labindex).OutputLinePulseDelay = 0;
        s(labindex).GainRaw = gainRaw;
    end
    %New basic preview
	preview(v(labindex))
	
	%Old preview
	%{
    figure('Toolbar','none',...
        'Menubar', 'none',...
        'NumberTitle','Off',...
        'Name',sprintf('cam%02d', labindex));
    vidRes = v(labindex).VideoResolution;
    nBands = v(labindex).NumberOfBands;
    hImage = image( zeros(vidRes(2), vidRes(1), nBands) );
    
    % prev
    preview(v(labindex), hImage)
	%}
end

%% Configure manual triggering and wait for acquisition trigger
camOpt = 'preview';


% delete(imaqfind);

