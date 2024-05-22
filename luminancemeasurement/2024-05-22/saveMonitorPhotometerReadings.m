function vals = saveMonitorPhotometerReadings(numMeasures, colorID, screenid)
% vals = saveMonitorPhotometerReadings([numMeasures=9], [screenid=max], [colorID=[1 2 3]])
% 
% example call:
% go through red values
% CalibrateMonitorPhotometerRGB(17, 'R', max(Screen('Screens'))
% go through green values
% CalibrateMonitorPhotometerRGB(17, 'G', max(Screen('Screens'))
% go through blue values
% CalibrateMonitorPhotometerRGB(17, 'B', max(Screen('Screens'))
% go through grayscale values
% CalibrateMonitorPhotometerRGB(17, 'A', max(Screen('Screens'))

% A simple calibration script for analog photometers.
%
% numMeasures (default: 9) readings are taken manually, and the readings
% are saved in a mat file. (numMeasures - 1) should be a power of 2, 
% ideally (9, 17, 33, etc.). The measured values will be returned.
%
%
% History:
% Version 1.0: Patrick Mineault (patrick.mineault@gmail.com)
% 22.10.2010 mk Switch numeric input from use of input() to use of
%               GetNumber(). Restore gamma table after measurement. Make
%               more robust.
% 19.08.2012 mk Some cleanup.
%  4.09.2012 mk Use Screen('ColorRange') to adapt number/max of intensity
%               level to given range of framebuffer.
% Extended 22.03.2019 Natalia Zaretskaya to use with specific RGB values
% Shrinked 22.05.2024 Cemre Yilmaz only to measure and save the luminance
% readings. The fitting was separated.

KbName('UnifyKeyNames');
Screen('Preference', 'SkipSyncTests', 1);
global vals;
global inputV;

    if (nargin < 1) || isempty(numMeasures)
        numMeasures = 9;
    end

    input(sprintf(['When black screen appears, point photometer, \n' ...
           'get reading in cd/m^2, input reading using numpad and press enter. \n' ...
           'A screen of higher luminance will be shown. Repeat %d times. ' ...
           'Press enter to start'], numMeasures));
       
    psychlasterror('reset');    
    try
        if nargin < 3 || isempty(screenid)
            % Open black window on default screen:
            screenid = max(Screen('Screens'));
        end
        
        % Open black window:
        win = Screen('OpenWindow', screenid, [0 0 0]);
        maxLevel = Screen('ColorRange', win);

        % Load identity gamma table for calibration:
        LoadIdentityClut(win);

        vals = [];
        inputV = [0:(maxLevel+1)/(numMeasures - 1):(maxLevel+1)]; %#ok<NBRAK>
        inputV(end) = maxLevel;
        rgb = [0 0 0];
        count=1;
        
        input('now press alt+tab to go back to command line and press enter :)');
        
        if strcmpi(colorID, 'R')
            colorID = 1;
        elseif strcmpi(colorID, 'G')
            colorID = 2;
        elseif strcmpi(colorID, 'B')
            colorID = 3;
        elseif strcmpi(colorID, 'A')
            colorID = [1, 2, 3];
        end
        
        for i = inputV
            rgb(colorID) = i;
            Screen('FillRect',win,rgb);
            Screen('Flip',win);

            fprintf('Value # %u ? ', count);
            resp = GetNumber;
            fprintf('\n');
            vals = [vals resp]; %#ok<AGROW>
            count = count+1;
        end
        
        % Restore normal gamma table and close down:
        RestoreCluts;
        Screen('CloseAll');
    catch %#ok<*CTCH>
        RestoreCluts;
        Screen('CloseAll');
        psychrethrow(psychlasterror);
    end

    displayRange = range(vals);
    displayBaseline = min(vals);
    
    %Normalize values
    vals_norm = (vals - displayBaseline) / displayRange;
    inputV = inputV/maxLevel;
    
    % save the data
    save(sprintf('luminance_readings_%s.mat', num2str(colorID)));
    figure; plot(inputV, vals_norm)
    xlabel('input'); ylabel('output')

return;
