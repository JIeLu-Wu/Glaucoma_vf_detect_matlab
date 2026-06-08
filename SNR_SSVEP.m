function SNR = SNR_SSVEP(Mean_Sta,fre_list)
% 计算SSVEP的信噪比
% input： Mean_Sta: Spectrum of the averaged SSVEPs
%         fre_list: index of target freqs
% output: Signal to noise ratios 
fre_num = length(fre_list);
for i = 1:fre_num
    Ps = Mean_Sta(fre_list(i));
    Noise = [fre_list(i)-10:fre_list(i)-1,fre_list(i)+1:fre_list(i)+10];
    Pn = mean(Mean_Sta(Noise));
    SNR(i,1)=10*log10(Ps/Pn);
end
