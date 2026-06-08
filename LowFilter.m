function data_filter = LowFilter(data_org,Fs,Wn_para)

%% 该函数用来进行ERP数据的滤波，输入为原始信号的二维数组：导联×采样点  以及采样频率
%  输出为滤波后数据，同原始信号的二维数组；
%区别于分类的滤波！
Wp=[2*Wn_para(1)/Fs];%1.5 1   71 75
Ws=[2*Wn_para(2)/Fs];%          % %    1.5 1 21 25
[N,Wn]=cheb1ord(Wp,Ws,4,30);
[f_b,f_a] = cheby1(N,0.5,Wn);


% [h,w]=freqz(f_b,f_a,256,Fs);
% h=20*log10(abs(h));
% figure;plot(w,h);title('所设计滤波器的通带曲线');grid on;


for i = 1:size(data_org,1)
    data_cow = data_org(i,:);
    data_filter(:,i) = filtfilt(f_b,f_a,data_cow);
end
 %data_filter = filtfilt(f_b,f_a,data_org');
 data_filter = data_filter';