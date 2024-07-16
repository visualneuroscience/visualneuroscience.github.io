% save luminance measurements
% CY 05/24
% ----------------------------------------------------------------------- %
% general info
readingDate   = '22-May-2024';
readingDevice = 'PCE-L335 LightMeter';
labName       = 'AW-lab';
screenName    = 'VPixx';
% ----------------------------------------------------------------------- %
% parameters
numMeasures = 17;
colorIDs    = {'R', 'G', 'B', 'A'};
measured    = 0; % did you already measured luminance?
% ----------------------------------------------------------------------- %
% readings
allLuminanceReadings = zeros(length(colorIDs), numMeasures);
if measured
    for col = 1:length(colorIDs)
        for i = 1:numMeasures
            fprintf([colorIDs{col}, ' - Value # %u ? '], i);
            resp = GetNumber;
            fprintf('\n');
            allLuminanceReadings(col, numMeasures) = resp;
        end
    end
else
    for col = 1:length(colorIDs)
        allLuminanceReadings(col, :) = saveMonitorPhotometerReadings(numMeasures, max(Screen('Screens')), colorIDs{col})
    end
end
% ----------------------------------------------------------------------- %
%save
save(['readings_lab-', labName, '_screen-', screenName, '.mat'], ...
    'allLuminanceReadings', ...
    'colorIDs', ...
    'labName', ...
    'numMeasures', ...
    'readingDate', ...
    'readingDevice', ...
    'screenName')
