%% 检测部分代码打包
function [RR_fold,Prob_dv] = glc_detection_prob(temp,test_trials,fold_num)
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
    % 假阳样本索引和决策系数
    FP_index = rou_cross(:,2)==1;
    FP_value = RR_cross_fold(FP_index,:,2);
    % 假阴样本索引和决策系数
    FN_index = rou_cross(:,1)==2;
    FN_value = RR_cross_fold(FN_index,:,1);

    % 计算模板二分类决策值的统计量
    ave_value_1 = mean(TP_value,1);
    ave_value_2 = mean(TN_value,1);
    std_value_1 = std(TP_value,[],1);
    std_value_2 = std(TN_value,[],1);
    all_ave = cat(1,ave_value_1,ave_value_2);
    all_std = cat(1,std_value_1,std_value_2);

    % 对测试集计算决策值
    RR = Multi_DSPm(8,temp,test_trials(:,:,:));
        
    for fold_i = 1:size(RR,1)/fold_num
        RR_fold(fold_i,:) = mean(RR((fold_i-1)*fold_num+1:fold_i*fold_num,:),1);
    end
    Prob_dv = Prob_calculate(RR_fold,all_ave,all_std);
    
    RR = Multi_DSPm(8,temp,test_trials(:,:,:));
    for fold_i = 1:size(RR,1)/fold_num
        RR_fold(fold_i,:) = mean(RR((fold_i-1)*fold_num+1:fold_i*fold_num,:),1);
    end
    [~,rou] = max(RR_fold,[],2);

%% 绘制temp的两个波形和测试波形，对比相似度，正常情况下注释掉
% disp(['有代码需要注释掉'])
% t = 0:1/250:0.45;
% figure(3)
% subplot(1,2,1)
% plot(t, mean(temp(10,:,:,1),3),'-','linewidth',1,'Color',[1,0,0])
% hold on
% plot(t, mean(temp(10,:,:,2),3),'-','linewidth',1,'Color',[0,0,1])
% subplot(1,2,1)
% plot(t, mean(test_trials(10,:,:),3),'-','linewidth',1.5,'Color',[0,0,0])
% hold off
% xlabel('Time[s]')
% ylabel('Amplitude')
% legend({'Temp1-36°';'Temp2-216°';'Test(lack2)'})
% title('PO7','FontName', 'Arial', 'FontSize',12 , 'FontWeight', 'Bold')
% set(gca, 'FontName', 'Arial', 'FontSize',12 , 'FontWeight', 'Bold')
% 
% figure(3)
% subplot(1,2,2)
% plot(t, mean(temp(16,:,:,1),3),'-','linewidth',1,'Color',[1,0,0])
% hold on
% plot(t, mean(temp(16,:,:,2),3),'-','linewidth',1,'Color',[0,0,1])
% subplot(1,2,2)
% plot(t, mean(test_trials(16,:,:),3),'-','linewidth',1.5,'Color',[0,0,0])
% hold off
% xlabel('Time[s]')
% ylabel('Amplitude')
% legend({'Temp1-36°';'Temp2-216°';'Test(lack2)'})
% title('PO8','FontName', 'Arial', 'FontSize',12 , 'FontWeight', 'Bold')
% set(gca, 'FontName', 'Arial', 'FontSize',12 , 'FontWeight', 'Bold')
end
