function [EEG,data_ori,type_all] = EEGRead5(adress,Fs_ori,Fs_resample,win,Wn_para,trial_num)
%% 该函数用于读取PC的cnt文件
Fs_pre = Fs_ori;%降采样后的采样频率
Fs = Fs_resample;
event_list = [1,2,1,2,1,2,1,2,1,2,1,2,1,2,1,2,1,2,1,2;...
              2,1,2,1,2,1,2,1,2,1,2,1,2,1,2,1,2,1,2,1];

try
    EEG = pop_loadcnt(adress,'dataformat','int32');
catch
    eeglab
    
    EEG = pop_loadcnt(adress,'dataformat','int32');
    close 'EEGLAB v2019.1'
end

% if Fs~=Fs_pre
%     data_org = double(EEG.data);
%     data_filted = lowpass(data_org,Fs_pre);
%     EEG.data = data_filted;
%     EEG = pop_resample(EEG,Fs);
% else
%     EEG = pop_resample(EEG,Fs);
%    
% end
t_len = 0.05;
data = double(EEG.data);
event = [EEG.event.type]';
latency = round([EEG.event.latency]');
event_trial = [];

if length(event)>trial_num
    event = event(1:trial_num);
    latency = latency(1:trial_num);
%     event = double(event)-48;
end


type_all = unique(event);
type_num = length(type_all);
% 90Hz低通滤波
data_low_filted = lowpass(data,1000);
% 降采样
for ch_i = 1:size(data_low_filted,1)
    data_resample(ch_i,:) = resample(data_low_filted(ch_i,:),1,EEG.srate/Fs);
end
% 带通滤波
if all(Wn_para == [0,0,0,0])
    data_char = data_resample;
else
%             data_band_filted = DataPrePro(data_resample,Fs,Wn_para);
    data_char = DataPrePro(data_resample,Fs,Wn_para);
end
latency_resample = round(latency/(Fs_pre/Fs));


for type_i = 1:type_num
    label_idx = find(event == type_all(type_i));%+char_i*trial_len;
    for trial_i = 1:length(label_idx)
        char_start_time = latency_resample(label_idx(trial_i))+round(win(1)*Fs)+1;
        char_end_time = latency_resample(label_idx(trial_i))+round(win(2)*Fs);
        data_ori(:,:,trial_i,type_i) = data_char(:,char_start_time:char_end_time);
    end
end
