function data_filter = DataPrePro(data_org,Fs,Wn_para)

%% 该函数用来进行分类数据的滤波，输入为原始信号的二维数组：导联×采样点  以及采样频率
%  输出为滤波后数据，同原始信号的二维数组；
%区别与ERP的滤波
if Wn_para ~= [0 0 0 0]
Wp=[2*Wn_para(2)/Fs 2*Wn_para(3)/Fs];%6 7 67 69
Ws=[2*Wn_para(1)/Fs 2*Wn_para(4)/Fs];%15 17
[N,Wn]=cheb1ord(Wp,Ws,3,40);% 3,40
[f_b,f_a] = cheby1(N,0.5,Wn);



data_filter = filtfilt(f_b,f_a,data_org');

 %data_filter = filtfilt(f_b,f_a,data_org');
data_filter = data_filter';
else
    data_filter = data_org;
end