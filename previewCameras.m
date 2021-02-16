function previewCameras()
gigeinfo = imaqhwinfo('gige');
numCamerasFound = numel(gigeinfo.DeviceIDs);

% Disconnect from all cameras from main MATLAB process and workers
delete(imaqfind);

for labindex = 1:numCamerasFound
    cameraID = labindex;
    v(labindex) = videoinput('gige', cameraID);
    s(labindex) = v(labindex).Source;
    
    % Configure properties common for both cameras
    s(labindex).PacketSize = 8192;
    s(labindex).ExposureTime = 10000;
    s(labindex).LineSelector = 'Line4';
    v(labindex).FramesPerTrigger = Inf;
    
    % Configure properties that are camera specific
    if strcmp(s(labindex).DeviceModelName, 'Nano-M1450')
        s(labindex).Gain = 2;
        s(labindex).acquisitionFrameRateControlMode = 'Programmable';
        s(labindex).AcquisitionFrameRate = 24;
        s(labindex).LineInverter = 'False';
        s(labindex).outputLineSource='PulseOnStartofExposure';
        s(labindex).outputLinePulseDuration = 1000;
        s(labindex).outputLinePulseDelay = 0;
    elseif strcmp(s(labindex).DeviceModelName, 'Genie M1280')
        s(labindex).AcquisitionFrameRateRaw = 24000;
        s(labindex).OutputLineMode = 'EventDriven';
        s(labindex).OutputLinePulseDuration = 1000;
        s(labindex).OutputLinePulseDelay = 0;
    end
    
    figure('Toolbar','none',...
        'Menubar', 'none',...
        'NumberTitle','Off',...
        'Name',sprintf('cam%02d', labindex));
    vidRes = v(labindex).VideoResolution;
    nBands = v(labindex).NumberOfBands;
    hImage = image( zeros(vidRes(2), vidRes(1), nBands) );
    
    % prev
    preview(v(labindex), hImage)
end

%% Configure manual triggering and wait for acquisition trigger
camOpt = 'preview';


% delete(imaqfind);

