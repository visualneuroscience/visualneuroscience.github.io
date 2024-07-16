function [displayBaseline, displayRange, displayGamma, maxLevel] = createGammaFromSavedReadings(labName, screenName, varargin)
% [displayBaseline, displayRange, displayGamma, maxLevel] = createGammaFromSavedReadings(labName, screenName, 'plot', 0)
% ----------------------------------------------------------------------- %
% offline curve fitting
% Record your luminance measurements, fit them on a gamma curve, create and
% save gamma tables.
% 
% % INPUTS e.g.
% labName       = 'AW';
% screenName    = 'VPixx';
%
% CY 05/24
% ----------------------------------------------------------------------- %
load(['readings_lab-', labName, '_screen-', screenName, '.mat'])
% ----------------------------------------------------------------------- %
if ~isempty(varargin)
    for tmp_i = 1:length(varargin)
        if contains(varargin{tmp_i}, 'plot')
            enablePlot = varargin{tmp_i+1};
        end
    end
else
    enablePlot = 0;
end
if length(colorIDs) > 3
    colorIDs = colorIDs(1:3);
    grayMeasured = 1;
end
maxLevel = 255; %Screen('ColorRange', win);

gammaTable1 = zeros(256,length(colorIDs));
gammaTable2 = zeros(256,length(colorIDs));

for i = 1:length(colorIDs)
    inputV = 0:(maxLevel+1)/(numMeasures - 1):(maxLevel+1);
    inputV(end) = maxLevel;

    vals = allLuminanceReadings(:,i);
    
    displayRange = range(vals);
    displayBaseline = min(vals);
    
    %Normalize values
    vals = (vals - displayBaseline) / displayRange;
    inputV = inputV/maxLevel;
    
    if ~exist('fittype') %#ok<EXIST>
        fprintf('This function needs fittype() for automatic fitting. This function is missing on your setup.\n');
        fprintf('Therefore i can''t proceed, but the input values for a curve fit are available to you by\n');
        fprintf('defining "global vals;" and "global inputV" on the command prompt, with "vals" being the displayed\n');
        fprintf('values and "inputV" being user input from the measurement. Both are normalized to 0-1 range.\n\n');
        error('Required function fittype() unsupported. You need the curve-fitting toolbox for this to work.\n');
    end
    
    %Gamma function fitting
    g = fittype('x^g');
    fittedmodel = fit(inputV',vals',g);
    displayGamma = fittedmodel.g;
    gammaTable1(:,i) = ((([0:maxLevel]'/maxLevel))).^(1/fittedmodel.g); %#ok<NBRAK>
    firstFit = fittedmodel([0:maxLevel]/maxLevel); %#ok<NBRAK>
    
    %Spline interp fitting
    fittedmodel = fit(inputV',vals','splineinterp');
    
    secondFit = fittedmodel([0:maxLevel]/maxLevel); %#ok<NBRAK>
    %Invert interpolation
    fittedmodel = fit(vals',inputV','splineinterp');   
    gammaTable2(:,i) = fittedmodel([0:maxLevel]/maxLevel); %#ok<NBRAK>

    % plot
    if enablePlot
        figure; hold on
        plot(inputV, vals, '*', [0:maxLevel]/maxLevel, firstFit, '--', [0:maxLevel]/maxLevel, secondFit, '-.'); %#ok<NBRAK>
        legend('Measures', 'Gamma model', 'Spline interpolation');
        title(sprintf('%s Gamma model x^{%.2f} vs. Spline interpolation', colorIDs{i}, displayGamma));
    end

    dlmwrite(['lab-', labName, '_screen-', screenName, 'rgb_gamma.txt'], gammaTable1);
    dlmwrite(['lab-', labName, '_screen-', screenName, 'rgb_spline.txt'], gammaTable2);
end

if grayMeasured

    inputV = 0:(maxLevel+1)/(numMeasures - 1):(maxLevel+1);
    inputV(end) = maxLevel;

    vals = allLuminanceReadings(:,end);
    
    displayRange = range(vals);
    displayBaseline = min(vals);
    
    %Normalize values
    vals = (vals - displayBaseline) / displayRange;
    inputV = inputV/maxLevel;
    
    if ~exist('fittype') %#ok<EXIST>
        fprintf('This function needs fittype() for automatic fitting. This function is missing on your setup.\n');
        fprintf('Therefore i can''t proceed, but the input values for a curve fit are available to you by\n');
        fprintf('defining "global vals;" and "global inputV" on the command prompt, with "vals" being the displayed\n');
        fprintf('values and "inputV" being user input from the measurement. Both are normalized to 0-1 range.\n\n');
        error('Required function fittype() unsupported. You need the curve-fitting toolbox for this to work.\n');
    end
    
    %Gamma function fitting
    g = fittype('x^g');
    fittedmodel = fit(inputV',vals',g);
    displayGamma = fittedmodel.g;
    gammaTable1 = ((([0:maxLevel]'/maxLevel))).^(1/fittedmodel.g); %#ok<NBRAK>
    firstFit = fittedmodel([0:maxLevel]/maxLevel); %#ok<NBRAK>
    
    %Spline interp fitting
    fittedmodel = fit(inputV',vals','splineinterp');
    
    secondFit = fittedmodel([0:maxLevel]/maxLevel); %#ok<NBRAK>
    %Invert interpolation
    fittedmodel = fit(vals',inputV','splineinterp');   
    gammaTable2 = fittedmodel([0:maxLevel]/maxLevel); %#ok<NBRAK>

    % plot
    if enablePlot
        figure; hold on
        plot(inputV, vals, '*', [0:maxLevel]/maxLevel, firstFit, '--', [0:maxLevel]/maxLevel, secondFit, '-.'); %#ok<NBRAK>
        legend('Measures', 'Gamma model', 'Spline interpolation');
        title(sprintf('%s Gamma model x^{%.2f} vs. Spline interpolation Gray', displayGamma));
    end

    dlmwrite(['lab-', labName, '_screen-', screenName, 'gray_gamma.txt'], gammaTable1);
    dlmwrite(['lab-', labName, '_screen-', screenName, 'gray_spline.txt'], gammaTable2);
end

end
