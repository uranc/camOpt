function stopCameras()
delete(imaqfind);
spmd(2)
    delete(imaqfind);
end