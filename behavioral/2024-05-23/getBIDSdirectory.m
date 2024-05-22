function saveFolder = getBIDSdirectory(projectFolder, subjectID, sessionID, runID, taskID)

subjectFolder = [projectFolder, filesep, 'rawdata', filesep, 'sub-', subjectID];
sessionFolder = [subjectFolder, filesep, 'ses-', sessionID];
dataFolder    = [sessionFolder, filesep, 'beh'];
% ----------------------------------------------------------------------- %
% check if the directories are ready and create them if they are not
if not(isfolder(projectFolder))
    mkdir(projectFolder)
end
if not(isfolder(subjectFolder))
    mkdir(subjectFolder)
end
if not(isfolder(sessionFolder))
    mkdir(sessionFolder)
end
if not(isfolder(sessionFolder))
    mkdir(dataFolder)
end
% ----------------------------------------------------------------------- %
saveFolder = dataFolder;
if isempty(taskID)
    saveString   = ['sub-', subjectID, '_ses-', sessionID, '_run-', runID, '_beh.mat'];
else
    saveString   = ['sub-', subjectID, '_ses-', sessionID, '_run-', runID, '_task-', taskID, '_beh.mat'];
end
saveString = fullfile(saveFolder, saveString);

fprintf('=>Saving data under %s\n', saveString);
% ----------------------------------------------------------------------- %
