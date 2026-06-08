% 牛哥的计算wPLI的代码


function [spectcoher,freqs2use]=SpectCoherence(data,EEGsrate,EEGtimes,times2save,wavelet_lowfreq,wavelet_highfreq,freq_nums,num_cycles)

%data 格式为(2)*sample的EEG data；表示2个通道的信号；可用于静息态（对静息态EEG进行epoch）和任务态EEG数据；
%EEGsrate为数据采样频率；
%EEGtimes表示sample对应的时间点，单位全部为ms；
%times2save感兴趣时间段，单位ms，如[0 500];
%num_cycles表示小波的cycle number
%wavelet_lowfreq,wavelet_highfreq感兴趣的低、高频范围

%SpectCoherence结果为1D数据，对应每个频率点下的coherence值
%freqs2use等于coherence值对应的频率点

[chan,sample]=size(data);
freqs2use  = linspace(wavelet_lowfreq,wavelet_highfreq,freq_nums); 
time          = -1:1/EEGsrate:1;
half_wavelet  = (length(time)-1)/2;
n_wavelet     = length(time);
n_data        = sample;
n_convolution = n_wavelet+n_data-1;
%time in indices
times2saveidx = dsearchn(EEGtimes',times2save');


chani=1;%第一通道信号
chanj=2;%第二通道信号
        
%data FFTs
data_fft1 = fft(data(chani,:),n_convolution);
data_fft2 = fft(data(chanj,:),n_convolution);


for fi=1:length(freqs2use)
    
    % create wavelet and take FFT
    s = num_cycles/(2*pi*freqs2use(fi));
    wavelet_fft = fft( exp(2*1i*pi*freqs2use(fi).*time) .* exp(-time.^2./(2*(s^2))) ,n_convolution);
    
    %channel 1 via convolution
    convolution_result_fft = ifft(wavelet_fft.*data_fft1,n_convolution);
    sig1 = convolution_result_fft(half_wavelet+1:end-half_wavelet);
 
    %channel 2 via convolution
    convolution_result_fft = ifft(wavelet_fft.*data_fft2,n_convolution);
    sig2 = convolution_result_fft(half_wavelet+1:end-half_wavelet);
    %计算coherence
    spec1 = mean(sig1(times2saveidx(1):times2saveidx(2)).*conj(sig1(times2saveidx(1):times2saveidx(2))));%计算Sxx，mean表示在时间点进行平均；
    spec2 = mean(sig2(times2saveidx(1):times2saveidx(2)).*conj(sig2(times2saveidx(1):times2saveidx(2))));%计算Syy
    specX = abs(mean(sig1(times2saveidx(1):times2saveidx(2)).*conj(sig2(times2saveidx(1):times2saveidx(2))))).^2;   %这里计算的是MSC
    spectcoher(fi) = specX/(spec1*spec2);
    
end


end


