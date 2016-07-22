%To recoed and save an audio file.

deviceReader = audioDeviceReader;
setup(deviceReader);

fileWriter = dsp.AudioFileWriter(...
    'mySpeech.wav',...
    'FileFormat','WAV');

disp('Speak into microphone now.');
tic;
while toc < 6
    acquiredAudio = record(deviceReader);
    step(fileWriter, acquiredAudio);
end
disp('Recording complete.');

release(deviceReader);
release(fileWriter);