%% 绘制结果热力图
load('result02131703.mat')
acc_all = result02131446.acc_all;
acc_all_classify = result02131446.acc_all_classify;

figure(1)
mean_acc = mean(acc_diff_sub,3);
gca = heatmap(mean_acc);
title('平均识别准确率')
set(gca,'FontSize',11,'FontName','黑体')
gca.XData = {'20';'40';'60';'80';'100'};
gca.YData = {'20';'40';'60';'80';'100'};
gca.XLabel = '测试集数量';
gca.YLabel = '训练集数量';
gca.ColorLimits = [0.45,0.85];

figure(2)
mean_acc_cost_radio = mean(Acc_cost_radio,3);
gca = heatmap(mean_acc_cost_radio);
title('试次-准确率平衡')
set(gca,'FontSize',11,'FontName','黑体')
gca.XData = {'20';'40';'60';'80';'100'};
gca.YData = {'20';'40';'60';'80';'100'};
gca.XLabel = '测试集数量';
gca.YLabel = '训练集数量';

figure(3)
% mean_acc = mean(acc_diff_sub,3);
gca = heatmap(acc_threhold);
title('阈值法识别准确率')
set(gca,'FontSize',11,'FontName','黑体')
gca.XData = {'20';'40';'60';'80';'100'};
gca.YData = {'20';'40';'60';'80';'100'};
gca.XLabel = '测试集数量';
gca.YLabel = '训练集数量';
gca.ColorLimits = [0.45,0.85];

figure(4)
% mean_acc = mean(acc_diff_sub,3);
gca = heatmap(threhold_matrix);
title('阈值')
set(gca,'FontSize',11,'FontName','黑体')
gca.XData = {'20';'40';'60';'80';'100'};
gca.YData = {'20';'40';'60';'80';'100'};
gca.XLabel = '测试集数量';
gca.YLabel = '训练集数量';
gca.ColorLimits = [0.65,0.85];