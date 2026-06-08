%% 低通
function newdata=lowpass(data2,Fs)

% fp=90; % 通带截止频率 
% fs=95; % 阻带截止频率 
fp=85; % 通带截止频率 
fs=90; % 阻带截止频率 
Rp=4;  % 通带波动，passband ripple no more than Rp DB,  Rp=4,Rs=30是针对SSVEP来设计的
Rs=30; % 阻带最小衰减，stopband attenuation at least Rs DB
[n,wn]=cheb1ord(2*fp/Fs,2*fs/Fs,Rp,Rs); % Gives mimimum order of filter
[fb,fa]=cheby1(n,0.5,wn,'low');%fb是系统函数的分子，fa是系统函数的分母 

filtdata=filtfilt(fb,fa,double(data2'));
newdata=filtdata';