% Initialize some variables used in configuring the System objects you
% create below.
WindowLen = 256;
AnalysisLen = 64;
SynthesisLen = 90;
Hopratio = SynthesisLen/AnalysisLen;

% Create a System object to read in the input speech signal from an audio
% file.
source = dsp.AudioFileReader(...
  which('out_female.wav'), ...
  'SamplesPerFrame', AnalysisLen, ...
  'OutputDataType', 'double');

% Create a buffer System object, which is used for the ST-FFT.
buff = dsp.Buffer(WindowLen, WindowLen - AnalysisLen);

% Create a Window System object, which is used for the ST-FFT. This object
% applies a window to the buffered input data.
win = dsp.Window('Hanning', 'Sampling', 'Periodic');

% Create an FFT System object, which is used for the ST-FFT.
fftObj = dsp.FFT;

% Create an IFFT System object, which is used for the IST-FFT.
ifftObj = dsp.IFFT('ConjugateSymmetricInput', true, ...
  'Normalize', false);

% Create a System object to play original speech signal.
Fs = 8000;
player = audioDeviceWriter('SampleRate', Fs, ...
    'SupportVariableSizeInput', true, ...
    'BufferSize', 512);

% Create a System object to log your data.
logger = dsp.SignalSink;
y = step(source);
subplot(3,1,1), periodogram(y,[],1024,Fs,'power','reassigned');

% Initialize the variables used in the processing loop.
yprevwin = zeros(WindowLen-SynthesisLen, 1);
gain = 1/(WindowLen*sum(hanning(WindowLen,'periodic').^2)/SynthesisLen);
unwrapdata = 2*pi*AnalysisLen*(0:WindowLen-1)'/WindowLen;
yangle = zeros(WindowLen, 1);
firsttime = true;

%Stream Processing Loop


while ~isDone(source)
    y = step(source);

    step(player, y);    % Play back original audio

    % ST-FFT
    % FFT of a windowed buffered signal
    yfft = step(fftObj, step(win, step(buff, y)));   

    % Convert complex FFT data to magnitude and phase.
    ymag       = abs(yfft);
    yprevangle = yangle;
    yangle     = angle(yfft);

    % Synthesis Phase Calculation
    yunwrap = (yangle - yprevangle) - unwrapdata;
    yunwrap = yunwrap - round(yunwrap/(2*pi))*2*pi;
    yunwrap = (yunwrap + unwrapdata) * Hopratio;
    if firsttime
        ysangle = yangle;
        firsttime = false;
    else
        ysangle = ysangle + yunwrap;
    end

    % Convert magnitude and phase to complex numbers.
    ys = ymag .* complex(cos(ysangle), sin(ysangle));

    % IST-FFT
    ywin  = step(win, step(ifftObj,ys));    % Windowed IFFT

    % Overlap-add operation
    olapadd  = [ywin(1:end-SynthesisLen,:) + yprevwin; ...
                ywin(end-SynthesisLen+1:end,:)];
    yistfft  = olapadd(1:SynthesisLen,:);
    yprevwin = olapadd(SynthesisLen+1:end,:);

    % Compensate for the scaling that was introduced by the overlap-add
    % operation
    yistfft = yistfft * gain;

    step(logger, yistfft);     % Log signal 
end


release(source);

% Play the time-Stretched Signals 
loggedSpeech = logger.Buffer(200:end)';
player = audioDeviceWriter('SampleRate', Fs, ...
    'SupportVariableSizeInput', true, ...
    'BufferSize', 512);
% Play time-stretched signal
disp('Playing time-stretched signal...');
step(player,loggedSpeech.');

% Play the Pitch-Scaled Signals
Fs_new = Fs*(SynthesisLen/AnalysisLen);
player = audioDeviceWriter('SampleRate', Fs_new, ...
    'SupportVariableSizeInput', true, ...
    'BufferSize', 1024);
disp('Playing pitch-scaled signal...');
step(player,loggedSpeech.');
subplot(3,1,2), periodogram(loggedSpeech,[],1024,Fs,'power','reassigned');

subplot(3,1,3);
S = spectrogram(loggedSpeech);
contour(abs(S));



% References
% A. D. Gotzen, N. Bernardini and D. Arfib, "Traditional Implementations of
% a Phase-Vocoder: The Tricks of the Trade," Proceedings of the COST G-6
% Conference on Digital Audio Effects (DAFX-00), Verona, Italy, December
% 7-9, 2000.
