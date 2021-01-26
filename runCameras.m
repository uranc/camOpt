function runCameras(fDir)
% D:\camOpt\deleteMeToStop.txt > deleting txt file stops acquisition
% It can take up to 10 seconds
saveDir = 'D:\BiCameras';
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
%% Create a parallel pool with two workers, one per camera
if isempty(gcp('nocreate'))
    parpool(2)
end

%% Disconnect from all cameras from main MATLAB process and workers
delete(imaqfind);
spmd(2)
    delete(imaqfind);
end

%% Create videoinput objects (one camera per worker)
spmd(2)
    % labBarrier ensures that the camera detection code is called
    % by only one worker at a time.
    for idx = 1:numlabs
        if idx == labindex
            imaqreset
            
            % Configure acquisition to not stop if dropped frames occur
            %             imaqmex('feature', '-gigeDisablePacketResend', true);
            
            % Detect cameras
            gigeinfo = imaqhwinfo('gige');
            numCamerasFound = numel(gigeinfo.DeviceIDs);
            fprintf('Worker %d detected %d cameras.\n', ...
                labindex, numCamerasFound);
        end
        labBarrier
    end
    
    cameraID = labindex;
    v = videoinput('gige', cameraID, 'Mono8');
    s = v.Source;
    
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
        
    elseif strcmp(s.DeviceModelName, 'Genie M1280')
        s.GainAbs = 2;
        s.AcquisitionFrameRateRaw = 24000;
        s.OutputLineMode = 'EventDriven';
        s.OutputLinePulseDuration = 1000;
        s.OutputLinePulseDelay = 0;
        fileName = [fDir, sprintf('_cam2_%d', round(1e8*datenum(datetime('now')))), '.mp4'];
        diskLogger = VideoWriter([filePath, fileName], 'MPEG-4');
        diskLogger.FrameRate = 24;
        v.DiskLogger = diskLogger;
    end
end

%% Configure manual triggering and wait for acquisition trigger
camOpt = 'starting';
setCamOpt();
%% Configure manual triggering and wait for acquisition trigger
spmd(2)
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
end

%% Display acquisition and logging status while logging
spmd(2)
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
            if labindex == 1
                flagRunning = camIsRunning();
                labSend(flagRunning, 2);
            elseif labindex == 2
                flagRunning = labReceive(1);
            end
            
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
end


disp('beer time')
% D:\camOpt\deleteMeToStop.txt > deleting txt file stops acquisition
% It can take up to 10 seconds

%% Clean up
spmd(2)
    delete(imaqfind);
end