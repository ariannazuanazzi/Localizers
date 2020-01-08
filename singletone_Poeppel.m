function singletone_Poeppel(varargin)

%% November 2019: added eyetracking by Arianna Zuanazzi
record_eye = str2num(cell2mat(inputdlg('Eye recording? 1/0'))); %want to record eyemovements?

%% ---- generalcparameters ----
SaveFolder = '/Users/megadmin/Desktop/Experiments/Arianna/singletone/data';

screennumber = max(Screen('Screens')); %selects the screen number  
white = [255 255 255]; %defines colour of background
gray = [128 128 128]; %defines colour of instructions
SubjectNumber = cell2mat(inputdlg('Participant ID')); %number of subject for data saving
cd(SaveFolder);mkdir(SubjectNumber);cd(SubjectNumber);

% number of tones
if nargin==0
    numberOFtones=100;
else
    numberOFtones=varargin{1};
end

% Make sure we're compatible
PTBVersionCheck(1,1,5,'at least');

% Set to debug, if we want to.
% Debugging mode is "1", normal mode is "0"
PTBSetIsDebugging(0);
Screen('Preference', 'SkipSyncTests', 1);

% Sets the keypress that exits the program
PTBSetExitKey('q');
PTBSetInputCollection('Char');

% Sets names of log files from PTBSetLogFiles function
PTBSetLogFiles('tonedata_log.txt');

%% Initialize eyetracker
if record_eye == 1
        
%Settings
windowPtr=Screen('OpenWindow', screennumber); %select screen for calibration
%display instructions for calibration
Screen(windowPtr, 'FillRect', gray); 
DrawFormattedText(windowPtr, sprintf('%s', 'Eyetracking calibration: follow the dots with your eyes!'), 'center', 'center', white);
Screen('Flip', windowPtr);
%eyetracking settings
el = EyelinkInitDefaults(windowPtr);
WaitSecs(5); %wait before calibration
Screen('Close');

%Initialization of the connection with the eyetracker.
online = EyelinkInit(0, 1);
if ~online
   error('Eyelink Init aborted.\n');
   %cleanup routine: Shutdown Eyelink:
   Eyelink('Shutdown');
   online = 0;
return;
end

%Calibrate the eyetracker
EyelinkDoTrackerSetup(el);
    
%edf link
edfFile = sprintf('%s.edf', num2str(SubjectNumber));
res = Eyelink('Openfile', edfFile);
Eyelink('Command', 'add_file_preamble_text = "Experiment recording of participant %s', num2str(SubjectNumber));
if res~=0
   fprintf('Cannot create EDF file ''%s'' ', edfFile);
   % Cleanup routine:Shutdown Eyelink
   Eyelink('Shutdown');
   eye.online = 0;
return;
end
    
%Make sure we're still connected.
if Eyelink('IsConnected')~=1
return;
end
    
%Eyetracker settings
%Use conservative online saccade detection (cognitive setting)
Eyelink('Command', 'recording_parse_type = GAZE');
Eyelink('Command', 'saccade_velocity_threshold = 30');
Eyelink('Command', 'saccade_acceleration_threshold = 9500');
Eyelink('Command', 'saccade_motion_threshold = 0.1');
Eyelink('Command', 'saccade_pursuit_fixup = 60');
Eyelink('Command', 'fixation_update_interval = 0');

%Other tracker configurations
Eyelink('Command', 'calibration_type = HV5');
Eyelink('Command', 'generate_default_targets = YES');
Eyelink('Command', 'enable_automatic_calibration = YES');
Eyelink('Command', 'automatic_calibration_pacing = 1000');
Eyelink('Command', 'screen_pixel_coords = 0 0 585 585'); %%% This has to be changed based on the size of the current screen
Eyelink('Command', 'binocular_enabled = NO');
Eyelink('Command', 'use_ellipse_fitter = NO');
Eyelink('Command', 'sample_rate = 2000');
Eyelink('Command', 'elcl_tt_power = %d', 3); % illumination, 1 = 100%, 2 = 75%, 3 = 50%

%Set edf data (what we want to save)
Eyelink('Command', 'file_event_filter = LEFT,FIXATION,SACCADE,BLINK,MESSAGE,INPUT');
Eyelink('Command', 'file_sample_data  = LEFT,GAZE,GAZERES,HREF,PUPIL,AREA,STATUS,INPUT');

%Set link data (can be used to react to events online)
Eyelink('Command', 'link_event_filter = LEFT,FIXATION,SACCADE,BLINK,MESSAGE,FIXUPDATE,INPUT');
Eyelink('Command', 'link_sample_data  = LEFT,GAZE,GAZERES,HREF,PUPIL,AREA,STATUS,INPUT');

%Starts recording and sends message to experimenter on eyelink monitor
Eyelink('Command', 'record_status_message "Start recording"');
Eyelink('Message', 'START RECORDING...');
Eyelink('StartRecording', [], [], [], 1);

end

%% Task

% -- create stimuli

% this sets up the list of tones (1 1 1 1, 2 2 2 2, as columns, etc.)
% to add a third tone, for example, add "ones(numberOFtones,1)*3"
% command should look like this:
%   tmp3=[ones(numberOFtones,1);ones(numberOFtones,1)*2;ones(numberOFtones,1)*3];
tmp3=[ones(numberOFtones,1);ones(numberOFtones,1)];
index=Shuffle(tmp3); % this will shuffle (or pseudo-randomize the order of tones
    
% this creates a random list of three ITI lengths
ITI=[0.9 1.1 1.5];
ITImtx=mod(ceil(rand(length(index),1)*10),3)+1;


% -- start task

PTBSetupExperiment('singletone');
%PTBInitUSBBox;
PTBInitStimTracker;


%Trigger to eyelink for start task
if record_eye == 1
   Eyelink('Command', 'record_status_message "Start tones..."'); %message to experimenter
   Eyelink('Message', 'STARTEXP'); %codes for beginning of the task
end

%Instructions
PTBDisplayParagraph({'Please listen to the tones, do not close your eyes'}, {'center', 15}, {5}, 2);%display instructions and wait for 5 secs
PTBDisplayBlank({1},'');


for n=1:floor(length(index)/2) 
    if index(n) == 1

       if record_eye == 1
       Eyelink('Command', 'record_status_message "Tone n.%d"', n); %message to experimenter
       Eyelink('Message', 'TONE %d', n); %codes for tone
       end
                     
       PTBPlaySoundFile('1000Hz.wav',{'end','any'}, 1, 0) % 1, 0 trigger for high tone (line 2)
        %elseif index(n) == 2
        %PTBPlaySoundFile('250Hz.wav',{'end','any'},32,0) % trigger for low tone (line 1)
 
    end
    curr_ITI = ITI(ITImtx(n));
    PTBDisplayBlank({curr_ITI},'');    
end

%Trigger to eyelink for end task
if record_eye == 1
   Eyelink('Command', 'record_status_message "End tones..."'); %message to experimenter
   Eyelink('Message', 'ENDEXP'); %codes for end of the task
end

%Endexp
PTBDisplayParagraph({'Done!'}, {'center', 15}, {3}, 2);%display done and wait for 5 secs
save(sprintf('%s_ITImtx.mat', SubjectNumber), 'ITImtx');

%% Cleanup
PTBDisplayBlank({.1},'');
PTBCleanupExperiment;

%Quit eyelink
if record_eye == 1
   if online      
   %Stop writing to edf
   disp('Stop Eyelink recording...')
   Eyelink('Command', 'set_idle_mode');  
   WaitSecs(0.5);
   Eyelink('CloseFile'); 
        
   %Shut down connection
   Eyelink('Shutdown'); 
   end
end