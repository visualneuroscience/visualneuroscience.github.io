% *beh.tsv and *beh.json will be created after preprocessing!          
%
% *_beh.tsv
%
% anushkab, 2018
% ----------------------------------------------------------------------- %
% https://www.fieldtriptoolbox.org/example/bids_behavioral/
% general information that applies to all
function createBIDS_beh_after_preprocessing(root_dir, project, sub_label, ses_label, run_label)
% INPUT
% root_dir      the directory where the project folder is stored, e.g.,
%           'C:\Users\username\Documents'
% project       the name of the project. It is same with the name of project
%           folder, e.g., 'transriv'
% sub_label     subject ID, e.g., 'S001'
% ses_label     session label, e.g., 'GG'
% run_label     run label, e.g., 'LL'
% task_label    task label, e.g., 'reportDominance'. If you don't use task
%           label, leave it as empty string ('').
% NO OUTPUT 
% The function only saves the tsv and json files. If you have an error, it
% must be due to the preprocessing. Go and debug the keypress.
% BIDS folder hierarchy
% root_dir
%   project
%       sub-<sub_label>
%           ses-<ses_label>
%               beh
%                   sub-<label>_ses-<label>_task-<label>_run-<index>_beh.json
%                   sub-<label>_ses-<label>_task-<label>_run-<index>_beh.tsv
% ----------------------------------------------------------------------- %
% data structure
dataStr = getBIDSdirectory(project, sub_label, ses_label, run_label, task_label);
% preprocessing rivalry data
datafile  = dir(dataStr);
datafile = datafile.name;
load([dataFold filesep datafile], 'log', 'trials')
% preprocess
[~, data] = analyzeBistableKeys(log.exp, log.key, 'plotFlag', 0);
% ----------------------------------------------------------------------- %
name_spec.modality = 'beh';
name_spec.suffix = 'beh';
name_spec.ext = '.tsv';
if isempty(task_label)
    name_spec.entities = struct('sub', sub_label, ...
                            'ses', ses_label, ...
                            'run', run_label);
else
    name_spec.entities = struct('sub', sub_label, ...
                            'ses', ses_label, ...
                            'run', run_label, ...
                            'task', task_label);
end

% using the 'use_schema', true
% ensures that the entities will be in the correct order
bids_file = bids.File(name_spec, 'use_schema', true);

% Contrust the fullpath version of the filename
events_tsv_name = fullfile(root_dir, project, 'rawdata', bids_file.bids_path, bids_file.filename);
events_json_name = fullfile(root_dir, project, 'rawdata', bids_file.bids_path, bids_file.json_filename);
% ----------------------------------------------------------------------- %
% preprocessed data
% REQUIRED Onset of the trials
tsv.onset = [0, log.exp.trialStartTime(2) - log.exp.trialStartTime(1)];

% REQUIRED. Duration of trials
tsv.duration = [120, 120];

% OPTIONAL Primary categorisation of each trial in a run
tsv.trial_type = {trials{1}.name, trials{2}.name};

% 
tsv.press_time = [data{1}(:,1); data{2}(:,1)+tsv.onset(2)];
tsv.release_time = [data{1}(:,2); data{2}(:,2)+tsv.onset(2)];
tsv.pressed_keyID = [data{1}(:,3); data{2}(:,3)];
tsv.pressed_percept = repmat('T', length(tsv.pressed_keyID), 1);
for i = 1:length(log.key.perceptKeys)
    tsv.pressed_percept(tsv.pressed_keyID == log.key.perceptKeys(i)) = log.key.perceptKeyNames{i}(1);
end
% ----------------------------------------------------------------------- %
% Save table
bids.util.tsvwrite(events_tsv_name, tsv);
% ----------------------------------------------------------------------- %
% json
% general info
json.StimulusPresentation.OperatingSystem = 'Linux Ubuntu 20.04 LTS';
json.StimulusPresentation.SoftwareName = 'Psychtoolbox';
json.StimulusPresentation.SoftwareRRID = ' ';
json.StimulusPresentation.SoftwareVersion = ' ';
json.StimulusPresentation.Code = ' ';

json.InstitutionName                 = 'University of Graz';
json.InstitutionalDepartmentName     = 'Department of Psychology';
json.InstitutionAddress              = 'Universtaetplatz 2, 8010, Graz, Austria';
% ----------------------------------------------------------------------- %
% associated data dictionary
template = struct('LongName', '', ...
                  'Description', '');

json.onset = template;
json.onset.LongName = 'Onset of the trials';
json.onset.Description = 'The time point (0: start of the run) when the trials started';

json.duration = template;
json.duration.LongName = 'Duration of trials';
json.duration.Description = 'The duration of each trial';

json.trial_type = template;
json.trial_type.LongName = 'Trial type';
json.trial_type.Description = 'Primary categorisation of each trial in a run';

json.press_time = template;
json.press_time.LongName = 'Key press time';
json.press_time.Description = 'The time point when the observer pressed a key';

json.release_time = template;
json.release_time.LongName = 'Key release time';
json.release_time.Description = 'The time point when the observer released a key';

json.pressed_keyID = template;
json.pressed_keyID.LongName = 'Key ID';
json.pressed_keyID.Description = 'The unique identifier for the key pressed and released';

json.pressed_percept = template;
json.pressed_percept.LongName = 'Percept type';
json.pressed_percept.Description = 'The percept type indicates the category of transition appearance when the conscious percept is a mixed percept or dominance percept';
% ----------------------------------------------------------------------- %
% Write JSON
% Make sure the directory exists
bids.util.mkdir(fileparts(events_json_name));
bids.util.jsonencode(events_json_name, json);
end
