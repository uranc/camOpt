function runM1450(fDir)
% D:\camOpt\deleteMeToStop.txt > deleting txt file stops acquisition
% It can take up to 10 seconds
saveDir = 'D:\PupilCamera\M1450';
if ~exist('fDir', 'var')
    fDir = 'fileDir';
    fileName = [fDir, sprintf('_cam1_%d', round(1e6*datenum(datetime('now')))), '.mp4'];
    fileName = fullfile(saveDir, fDir, fileName);
    disp(sprintf('I need a fileDir: \n runCameras(fileDir) writes to %s', fileName));
    return
end
filePath = [fullfile(saveDir, fDir), '\'];
mkdir(filePath)
disp(sprintf('Saving to %s', filePath));


%% Disconnect from all cameras from main MATLAB process and workers
delete(imaqfind);


%% Create videoinput objects (one camera per worker)


cameraID = labindex;
v = videoinput('gige', cameraID, 'Mono8');
s = v.Source;

assert(strcmp(s.DeviceModelName, 'Nano-M1450'), 'Wrong Camera, Only New Camera')
% Configure properties common for both cameras
s.PacketSize = 8192;
s.ExposureTime = 15000;
s.LineSelector = 'Line4';
v.FramesPerTrigger = Inf;
v.LoggingMode = 'disk';

% Configure properties that are camera specific
if strcmp(s.DeviceModelName, 'Nano-M1450')
    s.Gain = 2;
    s.acquisitionFrameRateControlMode = 'Programmable';
    s.AcquisitionFrameRate = 24;
    s.LineInverter = 'False';
    s.outputLineSource='PulseOnStartofExposure';
    s.outputLinePulseDuration = 1000;
    s.outputLinePulseDelay = 0;
    fileName = [fDir, sprintf('_cam1_%d', round(1e8*datenum(datetime('now')))), '.mp4'];
    diskLogger = VideoWriter([filePath, fileName], 'MPEG-4');
    diskLogger.FrameRate = 24;
    v.DiskLogger = diskLogger;
end

%% Configure manual triggering and wait for acquisition trigger
camOpt = 'starting';
setCamOpt();
%% Configure manual triggering and wait for acquisition trigger
triggerconfig(v, 'immediate');
pause(0.1);
% start acquiositng
start(v);

% log first package
dText = [v.FramesAcquired, v.DiskLoggerFrameCount];
logTxt = sprintf('%s_%d_%d_%d \n', camOpt, round(1e8*datenum(datetime('now'))), dText);
saveCamLog(logTxt, [filePath, fileName(1:end-3), 'txt']);

% exit
camOpt = 'running';

%% Display acquisition and logging status while logging
fprintf(sprintf('writing_%s\n', [filePath, fileName]))
% Display number of frames acquired and logged while acquiring
tic
while true
    pause(4.9)
    if toc > 4.9 % every 5 sec
        
        % summary
        dText = [v.FramesAcquired, v.DiskLoggerFrameCount];
        disp(sprintf('#frames %d, #logged %d',dText));
        logTxt = sprintf('%s_%d_%d_%d \n', camOpt, round(1e8*datenum(datetime('now'))), dText);
        saveCamLog(logTxt, [filePath, fileName(1:end-3), 'txt']);
        imwrite(getsnapshot(v), [filePath, fileName(1:end-3), 'png']);
        
        % get opts
        flagRunning = camIsRunning();
        
        % do stuff
        if ~flagRunning
            camOpt = 'stopping';
            disp(camOpt)
            while (v.FramesAcquired ~= v.DiskLoggerFrameCount)
                pause(1);
            end
            stop(v)
            break
        end
        tic
    end
end

% last log
dText = [v.FramesAcquired, v.DiskLoggerFrameCount];
disp(sprintf('#frames %d, #logged %d',dText));
logTxt = sprintf('%s_%d_%d_%d \n', camOpt, round(1e8*datenum(datetime('now'))), dText);
saveCamLog(logTxt, [filePath, fileName(1:end-3), 'txt']);
disp('beer time')
% D:\camOpt\deleteMeToStop.txt > deleting txt file stops acquisition
% It can take up to 10 seconds

%% Clean up
delete(imaqfind);
