function saveCamLog(wTxt, fName)
if ~exist(fName, 'file')
    fid = fopen(fName, 'w');
else
    fid = fopen(fName, 'a');
end
fwrite(fid, sprintf('%s', wTxt));
fclose(fid);
