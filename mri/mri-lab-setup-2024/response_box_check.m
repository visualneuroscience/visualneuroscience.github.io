% ================================================================ %
% MRI Lab response box input check
% AA 10/20, update NZ 08/2024 to be able to exit on escape
% Script for checking if the computer is recognising the response box inputs

% How to use: Run the script with matlab/octave.
% You will see a list of all external devices printed out and their respective indices
% Enter the index for the device you wish to test

% If the response box is in the list of devices ('Current Designs, Inc. 932'), the demo should work
% If the response box name is not printed out, make sure that the box is turned on.
% Changing the usb port might also work


% note: on windows, all devices are registered as one keyboard (so only index 1 or end will work)
% ================================================================ %
KbName('UnifyKeyNames'); % for compability between diff OSs

% get indices of recognized external devices
[keyboardIndices, productNames, allInfos] = GetKeyboardIndices;
% loop through all devices and print out names and respective indices
for i = 1:length(keyboardIndices)
  s = ["Name: ", productNames{i}, "; Index: ", num2str(keyboardIndices(i))];
  disp(s);
end
% choose the correct index of the keyboard you want to use
my_input = input("Enter the index for the device you wish to test: ");

deviceIndex = my_input;

% listen for button presses; press ctrl+c to exit the script
% this is borrowed from the KbQueueDemo, part 1

ListenChar(-1);

fprintf('Testing KbQueueCheck and KbName: press a key to see its number.\n');
fprintf('Press the "Esc" key to exit.\n');
escapeKey = KbName('ESCAPE');
KbQueueCreate(deviceIndex);
while KbCheck; end % Wait until all keys are released.

KbQueueStart(deviceIndex);

while 1
    % Check the queue for key presses.
    [ pressed, firstPress]=KbQueueCheck(deviceIndex);

    % If the user has pressed a key, then display its code number and name.
    if pressed

        % Note that we use find(firstPress) because firstPress is an array with
        % zero values for unpressed keys and non-zero values for pressed keys
        %
        % The fprintf statement implicitly assumes that only one key will have
        % been pressed. If this assumption is not correct, an error will result

        fprintf('You pressed key %i which is %s\n', min(find(firstPress)), KbName(min(find(firstPress))));

        if firstPress(escapeKey)
            fprintf('exiting...\n')
            break;
        end
    end
end
KbQueueRelease(deviceIndex);

ListenChar(0);
