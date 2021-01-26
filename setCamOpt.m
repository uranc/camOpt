function setCamOpt()
setTxt = 'deleteThisFileToStop';
fid = fopen('D:\camOpt\deleteMeToStop.txt', 'wt');
fwrite(fid, sprintf('%s\n', setTxt));
fclose(fid);
