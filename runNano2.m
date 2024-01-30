%Same as runGenie with preview
%Main Settings to change for brightness:
% - var: exposureTime: 15000-30000 
% - var: gainRaw (0 to 480); 110 default
% - var: fps (0 - 65); 30 default FramesPerSec
% Note: max fps is dependent on the exposureTime. If exposureTime is too high
% fps will be less.

% exposureTime = 19501; 
% gainRaw = 75;
% fps = 50; % applies to Nano cam only!

% C:\install\Matlab_Code\camOpt\deleteMeToStop.txt > delete this txt file to stop acquisition
% This can take up to 6 seconds to complete

function runNano2(fDir, gainRaw, exposureTime, fps)

if nargin==1
    gainRaw = 75;  
    exposureTime = 19501; 
    fps = 30;
elseif nargin==2
    exposureTime = 19501; 
    fps = 30;
elseif nargin==3
    fps = 30;
end

savePngInterval = 2.9; 

if ~contains(fDir,'cam','IgnoreCase',true)
    fDir = ['cam_', fDir];
end

saveDir = 'C:\PupilCamera\Nano';
if ~exist('fDir', 'var')
    fDir = 'fileDir';
    fileName = [fDir, sprintf('_nano_%s', char(datetime('now','Format','yyy-MM-DD_HHmmss'))), '.mp4'];
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
    cameraID = find(strcmp('Nano-M1450',{gigeinfo.DeviceInfo.DeviceName}));
else
    cameraID = 1;
end
v = videoinput('gige', cameraID, 'Mono8');  %'Mono12'
s = v.Source;
flushdata(v);

assert(strcmp(s.DeviceModelName, 'Nano-M1450'), 'Wrong Camera, Only New Camera')
s.PacketSize = 8192;  % alt val: 8000 or 8192
s.ExposureTime = exposureTime;
s.LineSelector = 'Line4';
v.FramesPerTrigger = Inf;
v.LoggingMode = 'disk'; %disk&memory

% Configure properties that are camera specific
if strcmp(s.DeviceModelName, 'Nano-M1450')
  % s.Gain = 3.3884415613920256;  %Gain Settings!
    s.GainRaw = gainRaw;
    s.acquisitionFrameRateControlMode = 'Programmable';
    s.AcquisitionFrameRate = fps; %old val: 24, max 66
    s.LineInverter = 'False';
    s.outputLineSource='PulseOnStartofExposure';
    s.outputLinePulseDuration = 1000;
    s.outputLinePulseDelay = 0;
    delay = CalculatePacketDelay(v, s.AcquisitionFrameRate);
    s.PacketDelay = 0;
    s.ReverseX = 'True';

    % Codec H.264 
    fileName = [fDir, sprintf('_nano_%s', char(datetime('now','Format','yyy-MM-DD_HHmmss'))), '.mp4'];
    diskLogger = VideoWriter([filePath, fileName], 'MPEG-4');
    diskLogger.FrameRate = s.AcquisitionFrameRate;
    diskLogger.Quality = 95;  %old val: 75
    v.DiskLogger = diskLogger;
end


%% Configure manual triggering and wait for acquisition trigger
camOpt = 'starting';
setCamOpt();

%% Configure manual triggering and wait for acquisition trigger
triggerconfig(v, 'immediate');
pause(1);
% start acquiositng
start(v);

% log first package
dText = [v.FramesAcquired, v.DiskLoggerFrameCount];
logTxt = sprintf('%s_%d_%d_%d \n', camOpt, round(1e8*datenum(datetime('now'))), dText);
saveCamLog(logTxt, [filePath, fileName(1:end-3), 'txt']);

% exit
camOpt = 'running';

%% Display acquisition and logging status while logging
fprintf('Begin writing to disk...\n  %s\n', [filePath, fileName]);
% Display number of frames acquired and logged while acquiring
tic
% preview GUI
preview(v);

while true
    pause(savePngInterval)
    if toc > savePngInterval % every 5 sec
        
        % summary
        dText = [v.FramesAcquired, v.DiskLoggerFrameCount];
        fprintf('#frames %d, #logged %d \n',dText);
        logTxt = sprintf('%s_%d_%d_%d \n', camOpt, round(1e8*datenum(datetime('now'))), dText);
        saveCamLog(logTxt, [filePath, fileName(1:end-3), 'txt']);
%         imwrite(getsnapshot(v), [filePath, fileName(1:end-3), 'png']);
        
        % get opts
        flagRunning = camIsRunning();
        
        % do stuff
        if ~flagRunning
            camOpt = 'stopping';
            disp(camOpt)
            c = 1;
            closepreview(v);
            fprintf('Waiting for logged frames to be saved...\n');
            while (v.FramesAcquired ~= v.DiskLoggerFrameCount) && (c < 51)
                if rem(c,10)==1
                    fprintf('%d Frames Behind %6d\n',(round(v.FramesAcquired-v.DiskLoggerFrameCount)), round(c/10))
                end
                pause(.1);
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
% closepreview(v);
log2save(v.EventLog, filePath, fileName);
disp('beer time');

% Note:
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


