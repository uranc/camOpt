%Same as runGenie with preview
%Main Settings to change for brightness:
% - var: exposureTime: 15000-30000 
% - var: gainRaw (-60 - 120); 70 default

% C:\install\Matlab_Code\camOpt\deleteMeToStop.txt > delete this txt file to stop acquisition
% This can take up to 6 seconds to complete

function runGenie2(fDir)
% Main Settings to change for brightness:
exposureTime = 19501; 
gainRaw = 70;

savePngInterval = 4.9; %default 4.9

saveDir = 'C:\PupilCamera\Genie';
if ~exist('fDir', 'var')
    fDir = 'fileDir';
%     fileName = [fDir, sprintf('_cam1_%d', round(1e6*datenum(datetime('now')))), '.mp4'];
    fileName = [fDir, sprintf('_genie_%s', char(datetime('now','Format','yyy-MM-DD_HHmmss'))), '.mp4'];
    fileName = fullfile(saveDir, fDir, fileName);
    fprintf('I need a fileDir: \n runCameras(fileDir) writes to %s\n', fileName);
    return
end
filePath = [fullfile(saveDir, fDir), '\'];
mkdir(filePath)
disp('---------------------------------');
fprintf('Saving video to folder:\n %s\n', filePath);

%% Disconnect from all cameras from main MATLAB process and workers
delete(imaqfind);

gigeinfo = imaqhwinfo('gige');
numCamerasFound = numel(gigeinfo.DeviceIDs);
fprintf('Found %d connected cameras ... \n', numCamerasFound);

%% Create videoinput objects (one camera per worker)
if numel(gigeinfo.DeviceIDs) > 1
    cameraID = find(strcmp('Genie M1280',{gigeinfo.DeviceInfo.DeviceName}));
else
    cameraID = 1;
end
v = videoinput('gige', cameraID, 'Mono8');  %'Mono10'
s = v.Source;
flushdata(v);

assert(strcmp(s.DeviceModelName, 'Genie M1280'), 'Wrong Camera, Only Genie Camera')
% Configure properties common for both cameras
s.ExposureTime = exposureTime;
s.GainRaw = gainRaw;
s.LineSelector = 'Line4';
v.FramesPerTrigger = Inf;
v.LoggingMode = 'disk';

% Configure properties that are camera specific
if strcmp(s.DeviceModelName, 'Genie M1280')
    % Configure properties common for both cameras
    s.PacketSize = 8000; %8192
    s.LineSelector = 'Line4';
    v.FramesPerTrigger = Inf;
    v.LoggingMode = 'disk';
%     s.GainAbs = 1.9952623149688795; %we use GainRaw instead!
    s.AcquisitionFrameRateRaw = 24560; %old val: 24000
    s.OutputLineMode = 'EventDriven';
    s.OutputLinePulseDuration = 1000;
    s.OutputLinePulseDelay = 0;   
    delay = CalculatePacketDelay(v, s.AcquisitionFrameRateRaw/1000);
    s.PacketDelay = 0;
    s.ReverseX = 'True';
    
    % Codec H.264 
    fileName = [fDir, sprintf('_GenieCam1_%s', char(datetime('now','Format','yyy-MM-DD_HHmmss'))), '.mp4'];
    diskLogger = VideoWriter([filePath, fileName], 'MPEG-4');

    % Codec 'Grayscale AVI' 
%     fileName = [fDir, sprintf('_GenieCam1_%s',  char(datetime('now','Format','yyy-MM-DD_HHmmss'))), '.avi'];
%     diskLogger = VideoWriter([filePath, fileName]);

    diskLogger.FrameRate = 25;    
    diskLogger.Quality = 95;  %old val: 75
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

%% Build custom GUI
% figure('Name', 'My Custom Preview Window'); 
% uicontrol('String', 'Close', 'Callback', 'close(gcf)'); 


% vidRes = v.VideoResolution; 
% nBands = v.NumberOfBands; 
% hImage = image( zeros(vidRes(2), vidRes(1), nBands) ); 
% hImage = getsnapshot(v);

preview(v);

%% Display acquisition and logging status while logging
fprintf('Begin writing to disk...\n  %s\n', [filePath, fileName]);
% Display number of frames acquired and logged while acquiring
tic
while true
    pause(savePngInterval)
    if toc > savePngInterval % every 5 sec
        
        % summary
        dText = [v.FramesAcquired, v.DiskLoggerFrameCount];
        fprintf('#frames %d, #logged %d \n',dText);
        logTxt = sprintf('%s_%d_%d_%d \n', camOpt, round(1e8*datenum(datetime('now'))), dText);
        saveCamLog(logTxt, [filePath, fileName(1:end-3), 'txt']);
%         imwrite(getsnapshot(v), [filePath, fileName(1:end-3), 'png']);
%         hImage = imshow(getsnapshot(v));
%         preview(v, hImage); 

        
        % get opts
        flagRunning = camIsRunning();
        
        % do stuff
        if ~flagRunning
            camOpt = 'stopping';
            disp(camOpt)
            c = 1;
            closepreview(v);
            fprintf('Waiting for logged frames to be saved...\n');
            while (v.FramesAcquired ~= v.DiskLoggerFrameCount) && (c < 6)
                fprintf('%d Frames remaining %6d\n',(round(v.FramesAcquired-v.DiskLoggerFrameCount)), c)
                pause(1);
                fprintf('\b\b\b\b\b\b\n');
                c = c+1;
            end
            stop(v)
            break
        end
        tic
    end
end

% last log
dText = [v.FramesAcquired, v.DiskLoggerFrameCount];
disp('---------------------------------');
fprintf('Final Frame Counts: \n#frames %d, #logged %d \n',dText);
logTxt = sprintf('%s_%d_%d_%d \n', camOpt, round(1e8*datenum(datetime('now'))), dText);
saveCamLog(logTxt, [filePath, fileName(1:end-3), 'txt']);
% stoppreview(v);
log2save(v.EventLog, filePath, fileName)
disp('beer time')
% D:\camOpt\deleteMeToStop.txt > deleting txt file stops acquisition
% It can take up to 10 seconds

%% Clean up
delete(v);
delete(imaqfind);
imaqreset;

end

%% Nested Functions:
% save the output of the v.EventLog structure to text file
function log2save(S, filePath, fileName)
    fid = fopen(fullfile(filePath, [fileName(1:end-3), '_Events.txt']), 'w');
    for i = 1:length(S)
        fprintf(fid, '\n');
        fields = fieldnames(S);
        for ii = 1:length(fields)
            current = eval(['S(',num2str(i),').',fields{ii}]);

            if isstruct(current)
                fields2 = fieldnames(current);
                for iii = 1:length(fields2)
                    current2 = eval(['S(',num2str(i),').',fields{ii}, '.', fields2{iii}]);
                    fprintf(fid, '%s: %s\n', fields2{iii}, num2str(current2));
                end

            else
                fprintf(fid, '%s:\n', current);
            end
        end
    end
    fclose(fid);
end
