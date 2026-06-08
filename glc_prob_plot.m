%% 检测部分代码打包
function RR_fold = glc_prob_plot(temp,test_trials,fold_num,para)
% para:plot的相关参数

% 模板交叉验证二分类
    RR_cross = DCPM_cross_valid(temp,8,10);
    for fold_i = 1:size(RR_cross,1)/fold_num
        RR_cross_fold(fold_i,:,:) = mean(RR_cross((fold_i-1)*fold_num+1:fold_i*fold_num,:,:),1);
    end
    [~,rou_cross] = max(RR_cross_fold,[],2);
    rou_cross = squeeze(rou_cross);
    % 找到真阳样本、真阴样本、假阳样本和假阴样本
    % 真阳样本索引和决策系数
    TP_index = rou_cross(:,1)==1;
    TP_value = RR_cross_fold(TP_index,:,1);
    % 真阴样本索引和决策系数
    TN_index = rou_cross(:,2)==2;
    TN_value = RR_cross_fold(TN_index,:,2);


    % 计算模板二分类决策值的统计量
    ave_value_1 = mean(TP_value);
    ave_value_2 = mean(TN_value);
    std_value_1 = std(TP_value);
    std_value_2 = std(TN_value);
    all_ave = cat(1,ave_value_1,ave_value_2);
    all_std = cat(1,std_value_1,std_value_2);
    RR = Multi_DSPm(8,temp,test_trials(:,:,:));
        
    for fold_i = 1:size(RR,1)/fold_num
        RR_fold(fold_i,:) = mean(RR((fold_i-1)*fold_num+1:fold_i*fold_num,:),1);
    end
%     P_dv = Prob_calculate(RR_fold,all_ave,all_std);
    fig1 = figure(1);
    set(fig1,"Position",para.pos1)
    subplot(1,3,1)
    [ave_value,std_value] = Draw_norm_line(TP_value,[-0.5,0.5],'True Positive',para.tp_legend);
    subplot(1,3,2)
    [ave_value,std_value] = Draw_norm_line(TN_value,[-0.5,0.5],'True Negative',para.tn_legend);
    subplot(1,3,3)
    [ave_value,std_value] = Draw_norm_line(RR_fold,[-0.5,0.5],'Test Trial',para.test_legend);
    sgtitle(para.title1, 'FontName','黑体','FontSize',15,'FontWeight','bold')
    % 对测试集计算决策值
    ave_diff_1 = all_ave(1,1) - mean(RR_fold(:,1)); % 测试集决策值相较于训练集交叉验证决策值的偏移量
    ave_diff_2 = all_ave(1,1) - mean(RR_fold(:,1)); % 测试集决策值相较于训练集交叉验证决策值的偏移量
    ave_diff_3 = all_ave(2,1) - mean(RR_fold(:,1)); % 测试集决策值相较于训练集交叉验证决策值的偏移量
    RR_fold_1 = RR_fold+ave_diff_1; % 标准化测试集决策值与训练集交叉验证决策值同分布
    RR_fold_2 = RR_fold+ave_diff_2; % 标准化测试集决策值与训练集交叉验证决策值同分布
    RR_fold_3 = RR_fold+ave_diff_3; % 标准化测试集决策值与训练集交叉验证决策值同分布
    min_num = min([size(TP_value,1),size(TN_value,1)]);
    
    fig2 = figure(2);
    set(fig2,"Position",para.pos2)
    subplot(2,3,1)
    [ave_value,std_value] = Draw_norm_line([TP_value(1:min_num,1),TN_value(1:min_num,2)],[-0.5,0.5],'P_A Model',para.pa_model);
    subplot(2,3,2)
    [ave_value,std_value] = Draw_norm_line(TP_value,[-0.5,0.5],'P_B Model',para.pb_model);
    subplot(2,3,3)
    [ave_value,std_value] = Draw_norm_line(TN_value,[-0.5,0.5],'P_C Model',para.pc_model);

    subplot(2,3,4)
    [ave_value,std_value] = Draw_norm_line(RR_fold_1,[-0.5,0.5],'P_A evaluation',para.pa_test);
    subplot(2,3,5)
    [ave_value,std_value] = Draw_norm_line(RR_fold_2,[-0.5,0.5],'P_B evaluation',para.pa_test);
    subplot(2,3,6)
    [ave_value,std_value] = Draw_norm_line(RR_fold_3,[-0.5,0.5],'P_C evaluation',para.pa_test);

    sgtitle(para.title2, 'FontName','黑体','FontSize',15,'FontWeight','bold')


end