%% 期刊论文 决策值计算与检测
%% 健康检测
% close all
%%%%%%%% 对比特征分布
clear 
clc


fs = 250;
t_len = 2;
t_lat = 0.05;
code_len = 0.25;
data_seg_all= [];
data_left_normal = [];
sub_list = [1,1,1,1,1,2,2,2,2,2,3,3,3,3,3,4,4,4,4,4,5,5,5,5,5];
chan_list = 44:64;
sub_name_list = {...
                 'D:\0课题\青光眼\data\临床实验\260520xkx\';...
                 };
loc_list = {'B4','B11','B18';'M4','M11','M18';'X4','X11','X18';...
            'B26','B33','B40';'M26','M33','M40';...
            'B48','B55','B62';'M48','M55','M62';...
            'B70','B77','B84';'M70','M77','M84'};

para.tp_legend = {'X11','X12','X11','X12'};
para.tn_legend = {'X21','X22','X21','X22'};
para.test_legend = {'Y1','Y2','Y1','Y2'};

para.pa_model = {'X11','X22','X11','X22'};
para.pb_model = {'X11','X12','X11','X12'};
para.pc_model = {'X21','X22','X21','X22'};

para.pa_test = {'Y1','Y2','Y1','Y2'};
para.pb_test = {'Y1','Y2','Y1','Y2'};
para.pc_test = {'Y1','Y2','Y1','Y2'};

para.pos1 = [100,100,1200,400];
para.pos2 = [100,100,1200,700];

train_trial_num_list =  [40:20:120];%[40:20:100];
test_trial_num_list = [40:20:80];%[40:20:100];
rou_all = cell(5,3);
acc_all = [];rou_v_all = [];acc_all_classify = [];
RR_all = cell(5,3);
Prob_dv_all = cell(5,3);
% 模拟正常
sub_i = 1;
lack_idx = [1,1,1,1;...
            1,1,1,1;...
            2,2,2,2;...
            1,2,2,1;...
            2,2,2,1;...
            1,1,1,1;...
            0,0,0,0];

for group_i = 1:7
    
    clearvars -except fs t_len t_lat code_len   chan_list sub_name_list loc_list train_trial_num_list test_trial_num_list excel_file...
        sub_i train_trial_num_i test_trial_num_i acc_all fold_num acc_all_classify para sub_list rou_v_all...
        group_i rou_all RR_all Prob_dv_all lack_idx
    t_start = 0;
    t_end = 0.45;
    Wn_para = [0.5,2,20,30];
    sub_name = sub_name_list{sub_i};
    file_type1 = ['train',num2str(group_i)];
    file_type2 = ['test',num2str(group_i)];
    trial_num = 480;
    
    if strcmp(sub_name(end-1),'N')
        file_type3 = ['3-'];
        file_type4 = ['4-'];
    end
    data_left_normal = [];
    
    filenum = 1;
    for file_i = 1:filenum
        data_seg = [];
        file_name = [sub_name,file_type1,'.cnt'];
    %     file_name = ['E:\项目\航天AR\数据\240328wjy\holo_s',num2str(file_i),'.cnt'];
        [EEG,data_seg,type_all_normal] = EEGRead5(file_name,1000,fs,[t_start,t_end],Wn_para,trial_num);%[25,28,40,45]  [5,7,26,30]
        data_left_normal = cat(3,data_left_normal,data_seg(1:64,:,:,:)); % 64*100*640*4
    end
    chan_name = {EEG.chanlocs.labels};
    [~,~,~,type_num] = size(data_left_normal);



    %% 读取检测数据
    % 垂直对称检测数据
    data_left_lack_v = [];
    data_seg = [];
    filenum = 1;
    trial_num = 360;
    EEG=[];
    for file_i = 1:filenum 
        data_seg = [];
        file_name = [sub_name,file_type2,'.cnt'];
        [EEG,data_seg,type_all_v] = EEGRead5(file_name,1000,fs,[t_start,t_end],Wn_para,trial_num);%[25,28,40,45]  [5,7,26,30]
        data_left_lack_v = cat(3,data_left_lack_v,data_seg(1:64,:,:,:));
    
    end
    % 水平对称检测数据
    
    
    trial_num = size(data_left_lack_v,3);
    index = 1:trial_num;
    data_left_lack_v = data_left_lack_v(:,:,index,:);



    for train_trial_num_i = 1:length(train_trial_num_list)
        for test_trial_num_i = 1:length(test_trial_num_list)

            for fold_num=[4]
                excel_file = ['D:\0课题\青光眼\data\小论文数据\test1',num2str(fold_num),'.xlsx'];
                train_trial_num = train_trial_num_list(train_trial_num_i);
                test_trial_num = test_trial_num_list(test_trial_num_i);
                index = 1:train_trial_num;
                test_index = 1:test_trial_num;
        %         test_index = [];
        %         for fold_i = 1:test_trial_num/fold_num
        %             test_index = cat(1, test_index, [(fold_i-1)*5+1:(fold_i-1)*5+fold_num]');
        %         end
                data_left_normal_i = data_left_normal(:,:,index,:);
                size(data_left_normal_i,3)





                %% 对训练数据和测试数据进行多次二分类
                temp_type_v = [1,2;...
                    2,1;...
                    3,4;...
                    4,3];
                [acc] = data_classify(data_left_normal_i,temp_type_v);
                %% 对检测数据进行二分类
                RR_v= [];rou_v = [];
                acc_v = [];
                all_normal_ave = [];all_normal_std = [];
                Prob_dv_v = [];
                Prob_dv_v_mean = []; 
                for type_i = 1:length(type_all_normal)
                    RR_fold=[];
    
                    para.title1 = ['被试',num2str(sub_list(sub_i)),'-',sub_name(end-3),'-点',num2str(type_i),'-决策值分布，训练样本数',num2str(train_trial_num),'，测试样本数',num2str(test_trial_num)];
                    para.title2 = ['被试',num2str(sub_list(sub_i)),'-',sub_name(end-3),'-点',num2str(type_i),'-概率估计，训练样本数',num2str(train_trial_num),'，测试样本数',num2str(test_trial_num)];
                        
                    if temp_type_v(type_i,1)~=0
                        test_trials_v = data_left_lack_v(chan_list,:,1:test_trial_num,type_i);
                        temp_v = data_left_normal_i(chan_list,:,1:train_trial_num,temp_type_v(type_i,:));
                        if strcmp(sub_name(end-3),'R')
                            [RR_fold,Prob_dv] = glc_detection_prob(temp_v(:,:,:,[2,1]),test_trials_v,fold_num);
                %             glc_prob_plot(temp_v(:,:,:,[2,1]),test_trials_v,fold_num,para);
                        else
                            [RR_fold,Prob_dv] = glc_detection_prob(temp_v,test_trials_v,fold_num);
                %             glc_prob_plot(temp_v(:,:,:,:),test_trials_v,fold_num,para);
                        end
                %         Prob_dv = Prob_dv(:,1:5);
                        [~,rou_v] = max(RR_fold,[],2);
                        acc_v = cat(2,acc_v,[sum(rou_v == [1,2])/size(rou_v,1)]');
                        Prob_dv_v = cat(2,Prob_dv_v,Prob_dv);
                        Prob_dv_v_mean = cat(2,Prob_dv_v_mean,mean(Prob_dv,2));
                        [~,max_loc] = max(mean(Prob_dv,2))
                        a = 1;
                    else
                        acc_v = cat(1,acc_v,[0;0]);
                        Prob_dv_v_mean = cat(2,Prob_dv_v_mean,[0;0;0]);
                    end
                    RR_all{train_trial_num_i, test_trial_num_i} = cat(3, RR_all{train_trial_num_i, test_trial_num_i}, RR_fold);
                    
    
                end
    %             sheet_name = ['训练',num2str(train_trial_num_list(train_trial_num_i)),'测试',num2str(test_trial_num_list(test_trial_num_i))];
    %             xlswrite(excel_file,cat(2,Prob_dv_v_mean,mean(Prob_dv_v_mean,2)),sheet_name,loc_list{sub_i,1})
    %             xlswrite(excel_file,cat(2,Prob_dv_h_mean,mean(Prob_dv_h_mean,2)),sheet_name,loc_list{sub_i,2})
    %             xlswrite(excel_file,cat(2,Prob_dv_c_mean,mean(Prob_dv_c_mean,2)),sheet_name,loc_list{sub_i,3})
                [~,rou_v] = max(Prob_dv_v_mean,[],1);
    
                rou = rou_v;
                rou_all{train_trial_num_i, test_trial_num_i} = cat(1,rou_all{train_trial_num_i, test_trial_num_i}, rou);
                Prob_dv_all{train_trial_num_i, test_trial_num_i} = cat(2, Prob_dv_all{train_trial_num_i, test_trial_num_i}, Prob_dv_v_mean);
                % acc = mean(rou == ones(1,size(rou,2)),2);
                % fprintf('被试 %d 的准确率为 %.3f\n', sub_i, acc);
                
%                 acc_all(train_trial_num_i,test_trial_num_i,sub_i) = acc;
%                 rou_v_all(sub_i,:) = mean(Prob_dv_v_mean,2)';
    %             acc_all{sub_i,fold_num}(:,(train_trial_num_i-1)*4+test_trial_num_i) = acc;
    %             acc_file = [excel_file(1:end-4),'mat'];
    %             save(acc_file,'acc_all')
            end % test_trial_num_i end
        end % train_trial_num_i end
    end % sub_i end
end

% save([sub_name_list{sub_i},'result_all.mat',],'rou_all','RR_all','Prob_dv_all', 'lack_idx')
for train_i = 1:5
    for test_i = 1:3
        fprintf(['训练试次 = %.d\n', train_trial_num_list(train_i), '测试试次 = %.d\n', test_trial_num_list(test_i) ]);
        acc(train_i, test_i) = mean(rou_all{train_i, test_i} == lack_idx, 'all');
        fprintf('训练试次 = %.d\n', acc(train_i, test_i))
        fprintf('28个点识别结果：\n')
        fprintf('真实标签：');
        fprintf('%d ', reshape(lack_idx',[28,1])');
        fprintf('\n');
        fprintf('预测标签：');
        fprintf('%d ', reshape(rou_all{train_i, test_i}',[28,1])');
        fprintf('\n');

%         % 分析每个点的决策值分布
%         RR = RR_all{train_i, test_i};
%         for stim_i = 1:28
%             fig = figure(1);
%             
%             set(fig, "position",[50,50,1600,800])
%             ax = subplot(4,7,stim_i);
%             ax = connected_dot_plot(RR(:,:,stim_i), ['Point', num2str(stim_i)]);
%             
%         end

    end
end


