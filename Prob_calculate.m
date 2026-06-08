function P_dv = Prob_calculate(RR_fold,all_normal_ave,all_normal_std)
% 根据训练集交叉验证的决策值分布，以及测试集整体的决策值，计算3种情况的概率
% RR_fold为测试集决策值，trials*2
% all_normal_ave 为交叉验证决策值分布均值
% all_normal_std 为交叉验证决策值分布方差

ave_diff_1 = all_normal_ave(1,1) - mean(RR_fold(:,1)); % 测试集决策值相较于训练集交叉验证决策值的偏移量
ave_diff_2 = all_normal_ave(1,1) - mean(RR_fold(:,1)); % 测试集决策值相较于训练集交叉验证决策值的偏移量
ave_diff_3 = all_normal_ave(2,1) - mean(RR_fold(:,1)); % 测试集决策值相较于训练集交叉验证决策值的偏移量
RR_fold_1 = RR_fold+ave_diff_1; % 标准化测试集决策值与训练集交叉验证决策值同分布
RR_fold_2 = RR_fold+ave_diff_2; % 标准化测试集决策值与训练集交叉验证决策值同分布
RR_fold_3 = RR_fold+ave_diff_3; % 标准化测试集决策值与训练集交叉验证决策值同分布
% RR_fold_1 = RR_fold_1./std(RR_fold_1);
% RR_fold_2 = RR_fold_2./std(RR_fold_2);
% RR_fold_3 = RR_fold_3./std(RR_fold_3);

X_1_1 = cat(1,all_normal_ave(1,1),all_normal_std(1,1)); % 训练集决策值的均值和方差（真阳）
X_1_2 = cat(1,all_normal_ave(1,2),all_normal_std(1,2)); % 训练集决策值的均值和方差（假阴）
X_2_1 = cat(1,all_normal_ave(2,1),all_normal_std(2,1)); % 训练集决策值的均值和方差（假阳）
X_2_2 = cat(1,all_normal_ave(2,2),all_normal_std(2,2)); % 训练集决策值的均值和方差（真阴）

for trial_i = 1:size(RR_fold)
%             test_rr_1 = RR_fold(trial_i,1);
%             test_rr_2 = RR_fold(trial_i,2);
%             X_1_1 = cat(1,all_normal_ave(1,1),all_normal_std(1,1));
%             X_1_2 = cat(1,all_normal_ave(1,2),all_normal_std(1,2));
%             X_2_1 = cat(1,all_normal_ave(2,1),all_normal_std(2,1));
%             X_2_2 = cat(1,all_normal_ave(2,2),all_normal_std(2,2));
% 
%             P_1 = normpdf(test_rr_1,X_1_1(1),X_1_1(2))*normpdf(test_rr_2,X_2_2(1),X_2_2(2));
%             P_2 = normpdf(test_rr_1,X_1_1(1),X_1_1(2))*normpdf(test_rr_2,X_1_2(1),X_1_2(2));
%             P_3 = normpdf(test_rr_2,X_2_2(1),X_2_2(2))*normpdf(test_rr_1,X_2_1(1),X_2_1(2));
% 
%             P_1 = P_1/(P_1+P_2+P_3);
%             P_2 = P_2/(P_1+P_2+P_3);
%             P_3 = P_3/(P_1+P_2+P_3);
% 
%             P(trial_i,:) = [P_1,P_2,P_3];
    P_1(trial_i) = normpdf(RR_fold_1(trial_i,1),X_1_1(1),X_1_1(2))*normpdf(RR_fold_1(trial_i,2),X_2_2(1),X_2_2(2));
    P_2(trial_i) = normpdf(RR_fold_2(trial_i,1),X_1_1(1),X_1_1(2))*normpdf(RR_fold_2(trial_i,2),X_1_2(1),X_1_2(2));
    P_3(trial_i) = normpdf(RR_fold_3(trial_i,1),X_2_1(1),X_2_1(2))*normpdf(RR_fold_3(trial_i,2),X_2_2(1),X_2_2(2));
end

P_dv = [P_1./(P_1+P_2+P_3);P_2./(P_1+P_2+P_3);P_3./(P_1+P_2+P_3)];