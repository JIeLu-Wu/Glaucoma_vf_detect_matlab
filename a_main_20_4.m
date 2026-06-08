%% 健康检测
close all
clear 
clc
filenum = 4;

fs = 250;
t_len = 2;
t_lat = 0.05;
code_len = 0.25;
data_seg_all= [];
data_left_normal = [];
event_all = [];
chan_list = 44:64;
%% 读取建模数据
train_trial_num = 240;
for file_i = 1:filenum
    file_name = ['E:\0课题\青光眼\data\20-4\wjy240616\N-1-',num2str(file_i),'.cnt'];
%     file_name = ['E:\项目\航天AR\数据\240328wjy\holo_s',num2str(file_i),'.cnt'];
    [EEG,data_seg,type_all_normal] = EEGRead5(file_name,1000,fs,[0.05,0.35],[0.5,2,20,30]);%[25,28,40,45]  [5,7,26,30]
    data_left_normal = cat(3,data_left_normal,data_seg(:,:,1:train_trial_num/filenum,:)); % 64*100*640*4
end
chan_name = {EEG.chanlocs.labels};
[~,~,trial_num,type_num] = size(data_left_normal);
%% 绘制正常同位刺激波形和脑地形图

% 绘制不同点位的PO7(53)、PO8(59)对比
loc_list = [2,1,3,4];
loc_name = ['右上';'左上';'左下';'右下'];
t =0.05:1/fs:0.35-1/fs;
for type_i = 1:type_num
    figure(1)
    subplot(2,2,loc_list(type_i))
    plot(t,mean(data_left_normal(53,1:end,:,type_i),3),LineWidth=1.5,Color=[0,0,1])
    hold on
    plot(t,mean(data_left_normal(58,1:end,:,type_i),3),LineWidth=1.5,Color=[1,0,0])
    subtitle(loc_name(type_i,:),fontsize=12,FontWeight='bold',FontName='黑体')
    if type_i == 3
        xlabel('Time [s]')
        ylabel('Amplitude [uV]')
    end
    
    set(gca,FontSize=10,fontname='黑体',FontWeight='bold')
end
legend(['PO7';'PO8'],'Location','southwest',FontSize=12,fontname='黑体',FontWeight='bold')



%% 读取检测数据
% 垂直对称检测数据
data_left_lack_v = [];
data_seg = [];
filenum = 2;
EEG=[];
for file_i = 1:filenum 
    file_name = ['E:\0课题\青光眼\data\20-4\wjy240616\N-2-',num2str(file_i),'.cnt'];
    [EEG,data_seg,type_all_v] = EEGRead5(file_name,1000,fs,[0.05,0.35],[0.5,2,20,30]);%[25,28,40,45]  [5,7,26,30]
    data_left_lack_v = cat(3,data_left_lack_v,data_seg);
    type_all_v = mod(type_all_v,20);
end
% 水平对称检测数据
data_left_lack_h = [];
data_seg = [];
filenum = 2;
EEG=[];
for file_i = 1:filenum 
    file_name = ['E:\0课题\青光眼\data\20-4\wjy240616\N-3-',num2str(file_i),'.cnt'];
    [EEG,data_seg,type_all_h] = EEGRead5(file_name,1000,fs,[0.05,0.35],[0.5,2,20,30]);%[25,28,40,45]  [5,7,26,30]
    data_left_lack_h = cat(3,data_left_lack_h,data_seg);
    type_all_h = mod(type_all_h,20);
end

% 中心对称检测数据
data_left_lack_c = [];
data_seg = [];
filenum = 2;
EEG=[];
for file_i = 1:filenum 
    file_name = ['E:\0课题\青光眼\data\20-4\wjy240616\N-4-',num2str(file_i),'.cnt'];
    [EEG,data_seg,type_all_c] = EEGRead5(file_name,1000,fs,[0.05,0.35],[0.5,2,20,30]);%[25,28,40,45]  [5,7,26,30]
    data_left_lack_c = cat(3,data_left_lack_c,data_seg);
    type_all_c = mod(type_all_c,20);
end


%% 对检测数据进行二分类
temp_type_v = [1,2;...
    2,1;...
    3,4;...
    4,3];
temp_type_h = [1,4;...
    2,3;...
    3,2;...
    4,1];
temp_type_c = [1,3;...
    2,4;...
    3,1;...
    4,2];

% for i = 1:length(lack_index)
%     if isempty(find(type_all_v==lack_index(i)))
%         lack_type_id(i) = 0;
%     else
%         lack_type_id(i) = find(type_all_v==lack_index(i));
%     end
% end
fold_num = 8;
RR_v= [];rou_v = [];RR_h= [];rou_h = [];RR_c= [];rou_c = [];
acc_v = [];acc_h = [];acc_c = [];
test_trial_num = 320;
for type_i = 4:length(type_all_normal)
    RR_fold=[];
    if temp_type_v(type_i,1)~=0
        test_trials_v = data_left_lack_v(chan_list,:,1:test_trial_num,type_all_v == type_i);
        temp_v = data_left_normal(chan_list,:,:,temp_type_v(type_i,:));
%         RR_v = Multi_DSPm(8,temp_v,test_trials_v(:,:,:));
        RR_v = TRCA_fold(8,temp_v,test_trials_v(:,:,:),0);
        for fold_i = 1:size(RR_v,1)/fold_num
            RR_fold(fold_i,:) = mean(RR_v((fold_i-1)*fold_num+1:fold_i*fold_num,:),1);
        end
        RR_diff = RR_fold(:,1)-RR_fold(:,2);
        [~,rou_v] = max(RR_fold,[],2);
        acc_v = cat(1,acc_v,sum(rou_v == [1,2])/size(rou_v,1));
    else
        acc_v = cat(1,acc_v,[0,0]);
    end

    RR_fold=[];
    if temp_type_h(type_i,1)~=0
        test_trials_h = data_left_lack_h(chan_list,:,1:test_trial_num,type_all_h == type_i);
        temp_h = data_left_normal(chan_list,:,:,temp_type_h(type_i,:));
%         RR_h = Multi_DSPm(8,temp_h,test_trials_h(:,:,:));
        RR_h = TRCA_fold(8,temp_h,test_trials_h(:,:,:),0);
        for fold_i = 1:size(RR_h,1)/fold_num
            RR_fold(fold_i,:) = mean(RR_h((fold_i-1)*fold_num+1:fold_i*fold_num,:),1);
        end
        [~,rou_h] = max(RR_fold,[],2);
        acc_h = cat(1,acc_h,sum(rou_h == [1,2])/size(rou_h,1));
    else
        acc_h = cat(1,acc_h,[0,0]);
    end

    RR_fold=[];
    if temp_type_c(type_i,1)~=0
        test_trials_c = data_left_lack_c(chan_list,:,1:test_trial_num,type_all_c == type_i);
        temp_c = data_left_normal(chan_list,:,:,temp_type_c(type_i,:));
%         RR_c = Multi_DSPm(8,temp_c,test_trials_c(:,:,:));
        RR_c = TRCA_fold(8,temp_c,test_trials_c(:,:,:),0);
        for fold_i = 1:size(RR_c,1)/fold_num
            RR_fold(fold_i,:) = mean(RR_c((fold_i-1)*fold_num+1:fold_i*fold_num,:),1);
        end
        [~,rou_c] = max(RR_c,[],2);
        acc_c = cat(1,acc_c,sum(rou_c == [1,2])/size(rou_c,1));
    else
        acc_c = cat(1,acc_c,[0,0]);
    end
end
%% 绘制结果图

figure(2)
set(gcf,"Position",[100,100,1200,300])
subplot(1,3,1)
for i = 1:type_num
    scatter((1+0.01*(i-1))*acc_v(i,1),(1+0.01*(i-1))*acc_v(i,2),50,'Marker','*')
    hold on 
end
hold off
xlim([-0.1,1])
ylim([-0.1,1])
set(gca,'FontSize',10,'FontWeight','bold')
xlabel('与左眼对应模板的匹配准确率','FontSize',12,'FontWeight','bold')
ylabel('与右眼对应模板的匹配准确率','FontSize',12,'FontWeight','bold')
subtitle('正常垂直对称刺激分类情况','FontSize',12,'FontWeight','bold')
legend({'点位1','点位2','点位3','点位4'},'FontSize',12,'FontWeight','bold')

subplot(1,3,2)
for i = 1:type_num
    scatter((1+0.01*(i-1))*acc_h(i,1),(1+0.01*(i-1))*acc_h(i,2),50,'Marker','*')
    hold on 
end
hold off
xlim([-0.1,1])
ylim([-0.1,1])
set(gca,'FontSize',10,'FontWeight','bold')
xlabel('与左眼对应模板的匹配准确率','FontSize',12,'FontWeight','bold')
ylabel('与右眼对应模板的匹配准确率','FontSize',12,'FontWeight','bold')
subtitle('正常水平对称刺激分类情况','FontSize',12,'FontWeight','bold')
legend({'点位1','点位2','点位3','点位4'},'FontSize',12,'FontWeight','bold')

subplot(1,3,3)
for i = 1:type_num
    scatter((1+0.01*(i-1))*acc_c(i,1),(1+0.01*(i-1))*acc_c(i,2),50,'Marker','*')
    hold on 
end
hold off
xlim([-0.1,1])
ylim([-0.1,1])
set(gca,'FontSize',10,'FontWeight','bold')
xlabel('与左眼对应模板的匹配准确率','FontSize',12,'FontWeight','bold')
ylabel('与右眼对应模板的匹配准确率','FontSize',12,'FontWeight','bold')
subtitle('正常中心对称刺激分类情况','FontSize',12,'FontWeight','bold')
legend({'点位1','点位2','点位3','点位4'},'FontSize',12,'FontWeight','bold')


sgtitle(['叠加',num2str(fold_num),'次，训练试次为',num2str(trial_num)],'FontSize',12,'FontWeight','bold')









%% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% 左眼检测
clear 
clc
close all
filenum = 4;

fs = 250;
t_len = 2;
t_lat = 0.05;
code_len = 0.25;
data_seg_all= [];
data_left_normal_ori = [];
event_all = [];
chan_list = 44:64;
% 读取建模数据
for file_i = 1:filenum
    file_name = ['E:\课题\青光眼\data\wjy240616\L-1-',num2str(file_i),'.cnt'];
    [EEG,data_seg,type_all_lack] = EEGRead5(file_name,1000,fs,[-0.1,0.3],[0.5,2,20,30]);%[25,28,40,45]  [5,7,26,30]
    data_left_normal_ori = cat(3,data_left_normal_ori,data_seg);
end
% 截取指定数量的训练试次
train_trail_num = 240;
data_left_normal = data_left_normal_ori(:,:,1:train_trail_num,:);
data_left_lack = [];
data_seg = [];
filenum = 2;
EEG=[];
for file_i = 1:filenum 
    file_name = ['E:\课题\青光眼\data\wjy240616\L-2-',num2str(file_i),'.cnt'];
    [EEG,data_seg,type_all_v] = EEGRead5(file_name,1000,fs,[-0.1,0.3],[0.5,2,20,30]);%[25,28,40,45]  [5,7,26,30]
    data_left_lack = cat(3,data_left_lack,data_seg);
    type_all_v = mod(type_all_v,20);
end

%% 对检测数据进行二分类
temp_type_v = [1,2;...
    2,1;...
    3,4;...
    4,3];
temp_type_h = [1,4;...
    2,3;...
    3,2;...
    4,1];
temp_type_c = [1,3;...
    2,4;...
    3,1;...
    4,2];

% for i = 1:length(lack_index)
%     if isempty(find(type_all_v==lack_index(i)))
%         lack_type_id(i) = 0;
%     else
%         lack_type_id(i) = find(type_all_v==lack_index(i));
%     end
% end
acc_all = [];
test_trail_num = 320;
for fold_num = 4%[1,2,4,8,16]
[~,~,~,type_num] = size(data_left_lack);
acc_v = [];acc_h = [];acc_c = [];
RR_v = [];rou_v=[];acc_v=[];
RR_h = [];rou_h=[];acc_h=[];
RR_c = [];rou_c=[];acc_c=[];
for type_i = 1:length(type_all_lack)
    RR_fold = [];
    if temp_type_v(type_i,1)~=0
        test_trials_v = data_left_lack(chan_list,:,1:test_trail_num,type_all_v == type_i);
        temp_v = data_left_normal(chan_list,:,:,temp_type_v(type_i,:));
        RR_v = Multi_DSPm(8,temp_v,test_trials_v(:,:,:));
        
        for fold_i = 1:size(RR_v,1)/fold_num
            RR_fold(fold_i,:) = mean(RR_v((fold_i-1)*fold_num+1:fold_i*fold_num,:),1);
        end
        [~,rou_v] = max(RR_fold,[],2);
        acc_v = cat(1,acc_v,sum(rou_v == [1,2])/size(rou_v,1));
    else
        acc_v = cat(1,acc_v,[0,0]);
    end
    
    RR_fold = [];
    if temp_type_h(type_i,1)~=0
        test_trials_h = data_left_lack(chan_list,:,1:test_trail_num,type_all_v == type_i);
        temp_h = data_left_normal(chan_list,:,:,temp_type_h(type_i,:));
        RR_h = Multi_DSPm(8,temp_h,test_trials_h(:,:,:));
        
        for fold_i = 1:size(RR_h,1)/fold_num
            RR_fold(fold_i,:) = mean(RR_h((fold_i-1)*fold_num+1:fold_i*fold_num,:),1);
        end
        [~,rou_h] = max(RR_fold,[],2);
        acc_h = cat(1,acc_h,sum(rou_h == [1,2])/size(rou_h,1));
    else
        acc_h = cat(1,acc_h,[0,0]);
    end
    
    RR_fold = [];
    if temp_type_c(type_i,1)~=0
        test_trials_c = data_left_lack(chan_list,:,1:test_trail_num,type_all_v == type_i);
        temp_c = data_left_normal(chan_list,:,:,temp_type_c(type_i,:));
        RR_c = Multi_DSPm(8,temp_c,test_trials_c(:,:,:));
        
        for fold_i = 1:size(RR_c,1)/fold_num
            RR_fold(fold_i,:) = mean(RR_c((fold_i-1)*fold_num+1:fold_i*fold_num,:),1);
        end
        [~,rou_c] = max(RR_fold,[],2);
        acc_c = cat(1,acc_c,sum(rou_c == [1,2])/size(rou_c,1));
    else
        acc_c = cat(1,acc_c,[0,0]);
    end
end

acc_mean(:,log2(fold_num)+1) = [mean(acc_v(:,1),1);mean(acc_h(:,1),1);mean(acc_c(:,1),1);];
acc_all(:,:,:,log2(fold_num)+1) = cat(3,acc_v,acc_h,acc_c);% 4个点，2个模板，3种对称，5种叠加试次
end

%% 绘制结果图
fold_id = 3;
figure(3)
set(gcf,"Position",[100,100,1200,300])
subplot(1,3,1)
for i = 1:type_num
    scatter((1+0.01*(i-1))*acc_all(i,2,1,fold_id),(1+0.01*(i-1))*acc_all(i,1,1,fold_id),50,'Marker','*')
    hold on 
end
hold off
xlim([-0.1,1.05])
ylim([-0.1,1.05])
set(gca,'FontSize',10,'FontWeight','bold')
xlabel('与左眼对应模板的匹配准确率','FontSize',12,'FontWeight','bold')
ylabel('与右眼对应模板的匹配准确率','FontSize',12,'FontWeight','bold')
subtitle('左眼垂直对称刺激分类情况','FontSize',12,'FontWeight','bold')
legend({'点位1','点位2','点位3','点位4'},'FontSize',12,'FontWeight','bold')

subplot(1,3,2)
for i = 1:type_num
    scatter((1+0.01*(i-1))*acc_all(i,2,2,fold_id),(1+0.01*(i-1))*acc_all(i,1,2,fold_id),50,'Marker','*')
    hold on 
end
hold off
xlim([-0.1,1.05])
ylim([-0.1,1.05])
set(gca,'FontSize',10,'FontWeight','bold')
xlabel('与左眼对应模板的匹配准确率','FontSize',12,'FontWeight','bold')
ylabel('与右眼对应模板的匹配准确率','FontSize',12,'FontWeight','bold')
subtitle('左眼水平对称刺激分类情况','FontSize',12,'FontWeight','bold')
legend({'点位1','点位2','点位3','点位4'},'FontSize',12,'FontWeight','bold')

subplot(1,3,3)
for i = 1:type_num
    scatter((1+0.01*(i-1))*acc_all(i,2,3,fold_id),(1+0.01*(i-1))*acc_all(i,1,3,fold_id),50,'Marker','*')
    hold on 
end
hold off
xlim([-0.1,1.05])
ylim([-0.1,1.05])
set(gca,'FontSize',10,'FontWeight','bold')
xlabel('与左眼对应模板的匹配准确率','FontSize',12,'FontWeight','bold')
ylabel('与右眼对应模板的匹配准确率','FontSize',12,'FontWeight','bold')
subtitle('左眼中心对称刺激分类情况','FontSize',12,'FontWeight','bold')
legend({'点位1','点位2','点位3','点位4'},'FontSize',12,'FontWeight','bold')


sgtitle(['叠加',num2str(fold_num),'次，训练试次为',num2str(train_trail_num)],'FontSize',12,'FontWeight','bold')







%% 右眼检测
clear 
clc
close all
filenum = 4;

fs = 250;
t_len = 2;
t_lat = 0.05;
code_len = 0.25;
data_seg_all= [];
data_left_normal_ori = [];
event_all = [];
chan_list = 44:64;
%% 读取右眼缺损建模数据
for file_i = 1:filenum
    file_name = ['E:\课题\青光眼\data\wjy240616\R-1-',num2str(file_i),'.cnt'];
    [EEG,data_seg,type_all_lack] = EEGRead5(file_name,1000,fs,[-0.1,0.3],[0.5,2,20,30]);%[25,28,40,45]  [5,7,26,30]
    data_left_normal_ori = cat(3,data_left_normal_ori,data_seg);
end
% 截取指定数量的训练试次
train_trail_num = 240;
data_left_normal = data_left_normal_ori(:,:,1:train_trail_num,:);
data_left_lack = [];
data_seg = [];
filenum = 2;
EEG=[];
for file_i = 1:filenum 
    file_name = ['E:\课题\青光眼\data\wjy240616\R-2-',num2str(file_i),'.cnt'];
    [EEG,data_seg,type_all_v] = EEGRead5(file_name,1000,fs,[-0.1,0.3],[0.5,2,20,30]);%[25,28,40,45]  [5,7,26,30]
    data_left_lack = cat(3,data_left_lack,data_seg);
    type_all_v = mod(type_all_v,20);
end

%% 对检测数据进行二分类
temp_type_v = [1,2;...
    2,1;...
    3,4;...
    4,3];
temp_type_h = [1,4;...
    2,3;...
    3,2;...
    4,1];
temp_type_c = [1,3;...
    2,4;...
    3,1;...
    4,2];
acc_all = [];
test_trial_num = 80;
for fold_num = 4%[1,2,4,8,16]
[~,~,~,type_num] = size(data_left_lack);
acc_v = [];acc_h = [];acc_c = [];
RR_v = [];rou_v=[];acc_v=[];
RR_h = [];rou_h=[];acc_h=[];
RR_c = [];rou_c=[];acc_c=[];
for type_i = 1:length(type_all_lack)
    RR_fold = [];
    if temp_type_v(type_i,1)~=0
        test_trials_v = data_left_lack(chan_list,:,1:test_trial_num,type_all_v == type_i);
        temp_v = data_left_normal(chan_list,:,:,temp_type_v(type_i,:));
        RR_v = Multi_DSPm(8,temp_v,test_trials_v(:,:,:));
        
        for fold_i = 1:size(RR_v,1)/fold_num
            RR_fold(fold_i,:) = mean(RR_v((fold_i-1)*fold_num+1:fold_i*fold_num,:),1);
        end
        [~,rou_v] = max(RR_fold,[],2);
        acc_v = cat(1,acc_v,sum(rou_v == [1,2])/size(rou_v,1));
    else
        acc_v = cat(1,acc_v,[0,0]);
    end
    
    RR_fold = [];
    if temp_type_h(type_i,1)~=0
        test_trials_h = data_left_lack(chan_list,:,1:test_trial_num,type_all_v == type_i);
        temp_h = data_left_normal(chan_list,:,:,temp_type_h(type_i,:));
        RR_h = Multi_DSPm(8,temp_h,test_trials_h(:,:,:));
        
        for fold_i = 1:size(RR_h,1)/fold_num
            RR_fold(fold_i,:) = mean(RR_h((fold_i-1)*fold_num+1:fold_i*fold_num,:),1);
        end
        [~,rou_h] = max(RR_fold,[],2);
        acc_h = cat(1,acc_h,sum(rou_h == [1,2])/size(rou_h,1));
    else
        acc_h = cat(1,acc_h,[0,0]);
    end
    
    RR_fold = [];
    if temp_type_c(type_i,1)~=0
        test_trials_c = data_left_lack(chan_list,:,1:test_trial_num,type_all_v == type_i);
        temp_c = data_left_normal(chan_list,:,:,temp_type_c(type_i,:));
        RR_c = Multi_DSPm(8,temp_c,test_trials_c(:,:,:));
        
        for fold_i = 1:size(RR_c,1)/fold_num
            RR_fold(fold_i,:) = mean(RR_c((fold_i-1)*fold_num+1:fold_i*fold_num,:),1);
        end
        [~,rou_c] = max(RR_fold,[],2);
        acc_c = cat(1,acc_c,sum(rou_c == [1,2])/size(rou_c,1));
    else
        acc_c = cat(1,acc_c,[0,0]);
    end
end

acc_mean(:,log2(fold_num)+1) = [mean(acc_v(:,1),1);mean(acc_h(:,1),1);mean(acc_c(:,1),1);];
acc_all(:,:,:,log2(fold_num)+1) = cat(3,acc_v,acc_h,acc_c);% 4个点，2个模板，3种对称，5种叠加试次
end

%% 绘制结果图
fold_id = 3;
figure(3)
set(gcf,"Position",[100,100,1200,300])
subplot(1,3,1)
for i = 1:type_num
    scatter((1+0.01*(i-1))*acc_all(i,1,1,fold_id),(1+0.01*(i-1))*acc_all(i,2,1,fold_id),50,'Marker','*')
    hold on 
end
hold off
xlim([-0.1,1.05])
ylim([-0.1,1.05])
set(gca,'FontSize',10,'FontWeight','bold')
xlabel('与左眼对应模板的匹配准确率','FontSize',12,'FontWeight','bold')
ylabel('与右眼对应模板的匹配准确率','FontSize',12,'FontWeight','bold')
subtitle('右眼垂直对称刺激分类情况','FontSize',12,'FontWeight','bold')
legend({'点位1','点位2','点位3','点位4'},'FontSize',12,'FontWeight','bold')

subplot(1,3,2)
for i = 1:type_num
    scatter((1+0.01*(i-1))*acc_all(i,1,2,fold_id),(1+0.01*(i-1))*acc_all(i,2,2,fold_id),50,'Marker','*')
    hold on 
end
hold off
xlim([-0.1,1.05])
ylim([-0.1,1.05])
set(gca,'FontSize',10,'FontWeight','bold')
xlabel('与左眼对应模板的匹配准确率','FontSize',12,'FontWeight','bold')
ylabel('与右眼对应模板的匹配准确率','FontSize',12,'FontWeight','bold')
subtitle('右眼水平对称刺激分类情况','FontSize',12,'FontWeight','bold')
legend({'点位1','点位2','点位3','点位4'},'FontSize',12,'FontWeight','bold')

subplot(1,3,3)
for i = 1:type_num
    scatter((1+0.01*(i-1))*acc_all(i,1,3,fold_id),(1+0.01*(i-1))*acc_all(i,2,3,fold_id),50,'Marker','*')
    hold on 
end
hold off
xlim([-0.1,1.05])
ylim([-0.1,1.05])
set(gca,'FontSize',10,'FontWeight','bold')
xlabel('与左眼对应模板的匹配准确率','FontSize',12,'FontWeight','bold')
ylabel('与右眼对应模板的匹配准确率','FontSize',12,'FontWeight','bold')
subtitle('右眼中心对称刺激分类情况','FontSize',12,'FontWeight','bold')
legend({'点位1','点位2','点位3','点位4'},'FontSize',12,'FontWeight','bold')


sgtitle(['叠加',num2str(fold_num),'次，训练试次为',num2str(train_trail_num)],'FontSize',12,'FontWeight','bold')





%% 绘制平均结果图

figure(5)
set(gcf,"Position",[100,100,1200,300])
subplot(1,3,1)
for i = 1:type_num
    scatter((1+0.01*(i-1))*(acc_mean(1,1)),(1+0.01*(i-1))*(1-acc_mean(1,1)),50,'Marker','*')
    hold on 
end
hold off
xlim([-0.1,1])
ylim([-0.1,1])
set(gca,'FontSize',10,'FontWeight','bold')
xlabel('与左眼对应模板的匹配准确率','FontSize',12,'FontWeight','bold')
ylabel('与右眼对应模板的匹配准确率','FontSize',12,'FontWeight','bold')
subtitle('右眼垂直对称刺激分类情况','FontSize',12,'FontWeight','bold')
legend({'点位1','点位2','点位3','点位4'},'FontSize',12,'FontWeight','bold')

subplot(1,3,2)
for i = 1:type_num
    scatter((1+0.01*(i-1))*(acc_mean(2,1)),(1+0.01*(i-1))*(1-acc_mean(2,1)),50,'Marker','*')
    hold on 
end
hold off
xlim([-0.1,1])
ylim([-0.1,1])
set(gca,'FontSize',10,'FontWeight','bold')
xlabel('与左眼对应模板的匹配准确率','FontSize',12,'FontWeight','bold')
ylabel('与右眼对应模板的匹配准确率','FontSize',12,'FontWeight','bold')
subtitle('右眼水平对称刺激分类情况','FontSize',12,'FontWeight','bold')
legend({'点位1','点位2','点位3','点位4'},'FontSize',12,'FontWeight','bold')

subplot(1,3,3)
for i = 1:type_num
    scatter((1+0.01*(i-1))*(acc_mean(3,1)),(1+0.01*(i-1))*(1-acc_mean(3,1)),50,'Marker','*')
    hold on 
end
hold off
xlim([-0.1,1])
ylim([-0.1,1])
set(gca,'FontSize',10,'FontWeight','bold')
xlabel('与左眼对应模板的匹配准确率','FontSize',12,'FontWeight','bold')
ylabel('与右眼对应模板的匹配准确率','FontSize',12,'FontWeight','bold')
subtitle('右眼中心对称刺激分类情况','FontSize',12,'FontWeight','bold')
legend({'点位1','点位2','点位3','点位4'},'FontSize',12,'FontWeight','bold')


sgtitle(['叠加',num2str(fold_num),'次，训练试次为',num2str(train_trail_num)],'FontSize',12,'FontWeight','bold')







%% 将三种情况下的准确率绘制在一个图里
acc_v = [];acc_h = []; acc_c = []; acc_mean = [];

figure(6)
subplot(3,2,1)
mark_list = ['s','o','^'];
Color_list = [1,0,0;0,0,1;1,0.41,0.46;0.39,0.83,0.07];
for j = 1:3
for i = 1:type_num
    scatter((1+0.01*(i-1))*(acc_v(i,j)),(1+0.01*(i-1))*(1-acc_v(i,j)),50,'Marker',mark_list(j),'MarkerFaceColor',Color_list(i,:))
    hold on 
%     scatter((1+0.01*(i-1))*(acc_mean(2,j)),(1+0.01*(i-1))*(1-acc_mean(2,j)),50,'Marker',mark_list(j))
%     hold on 
%     scatter((1+0.01*(i-1))*(acc_mean(3,j)),(1+0.01*(i-1))*(1-acc_mean(3,j)),50,'Marker',mark_list(j))
%     hold on
end
end
hold off
xlim([-0.1,1.05])
ylim([-0.1,1.05])
set(gca,'FontSize',10,'FontWeight','bold')
xlabel('与左眼对应模板的匹配准确率','FontSize',12,'FontWeight','bold')
ylabel('与右眼对应模板的匹配准确率','FontSize',12,'FontWeight','bold')
subtitle('垂直对称刺激分类情况','FontSize',12,'FontWeight','bold')

subplot(3,2,2)
mark_list = ['s','o','^'];
Color_list = [1,0,0;0,0,1;1,0.41,0.46;0.39,0.83,0.07];
for j = 1:3
for i = 1:type_num
    scatter((1+0.01*(i-1))*(acc_h(i,j)),(1+0.01*(i-1))*(1-acc_h(i,j)),50,'Marker',mark_list(j),'MarkerFaceColor',Color_list(i,:))
    hold on 
%     scatter((1+0.01*(i-1))*(acc_mean(2,j)),(1+0.01*(i-1))*(1-acc_mean(2,j)),50,'Marker',mark_list(j))
%     hold on 
%     scatter((1+0.01*(i-1))*(acc_mean(3,j)),(1+0.01*(i-1))*(1-acc_mean(3,j)),50,'Marker',mark_list(j))
%     hold on
end
end
hold off
xlim([-0.1,1.05])
ylim([-0.1,1.05])
set(gca,'FontSize',10,'FontWeight','bold')
xlabel('与左眼对应模板的匹配准确率','FontSize',12,'FontWeight','bold')
ylabel('与右眼对应模板的匹配准确率','FontSize',12,'FontWeight','bold')
subtitle('水平对称刺激分类情况','FontSize',12,'FontWeight','bold')

subplot(3,2,3)
mark_list = ['s','o','^'];
Color_list = [1,0,0;0,0,1;1,0.41,0.46;0.39,0.83,0.07];
for j = 1:3
for i = 1:type_num
    scatter((1+0.01*(i-1))*(acc_c(i,j)),(1+0.01*(i-1))*(1-acc_c(i,j)),50,'Marker',mark_list(j),'MarkerFaceColor',Color_list(i,:))
    hold on 
%     scatter((1+0.01*(i-1))*(acc_mean(2,j)),(1+0.01*(i-1))*(1-acc_mean(2,j)),50,'Marker',mark_list(j))
%     hold on 
%     scatter((1+0.01*(i-1))*(acc_mean(3,j)),(1+0.01*(i-1))*(1-acc_mean(3,j)),50,'Marker',mark_list(j))
%     hold on
end
end
hold off
xlim([-0.1,1.05])
ylim([-0.1,1.05])
set(gca,'FontSize',10,'FontWeight','bold')
xlabel('与左眼对应模板的匹配准确率','FontSize',12,'FontWeight','bold')
ylabel('与右眼对应模板的匹配准确率','FontSize',12,'FontWeight','bold')
subtitle('中心对称刺激分类情况','FontSize',12,'FontWeight','bold')


subplot(3,2,4)
mark_list = ['s','o','^'];
Color_list = [1,0,0;0,0,1;1,0.41,0.46;0.39,0.83,0.07];
for j = 1:3
for i = 1:type_num
    scatter((1+0.01*(i-1))*(acc_mean(i,j)),(1+0.01*(i-1))*(1-acc_mean(i,j)),50,'Marker',mark_list(j),'MarkerFaceColor',Color_list(i,:))
    hold on 
%     scatter((1+0.01*(i-1))*(acc_mean(2,j)),(1+0.01*(i-1))*(1-acc_mean(2,j)),50,'Marker',mark_list(j))
%     hold on 
%     scatter((1+0.01*(i-1))*(acc_mean(3,j)),(1+0.01*(i-1))*(1-acc_mean(3,j)),50,'Marker',mark_list(j))
%     hold on
end
end
hold off
xlim([-0.1,1.05])
ylim([-0.1,1.05])
set(gca,'FontSize',10,'FontWeight','bold')
xlabel('与左眼对应模板的匹配准确率','FontSize',12,'FontWeight','bold')
ylabel('与右眼对应模板的匹配准确率','FontSize',12,'FontWeight','bold')
subtitle('三种对称平均分类情况','FontSize',12,'FontWeight','bold')





legend({'正常点位1','正常点位2','正常点位3','正常点位4','左眼点位1','左眼点位2','左眼点位3','左眼点位4','右眼点位1','右眼点位2','右眼点位3','右眼点位4'},'FontSize',12,'FontWeight','bold')
