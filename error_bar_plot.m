close all
X=[];

X = X*100;
X_mean = mean(X,1);
X_var = std(X,1);
figure,
b = bar(X_mean);
b.FaceColor = [0.06,1.00,1.00];
b.BarWidth = 0.4;
hold on
errorbar(X_mean,X_var(1,:),'LineStyle','none','Color',[0,0,0]/255,LineWidth=1.5)
xticklabels({'[24 85]+\newline[54,85]','[2 85]+\newline[24 85]+\newline[54 85]','[2 85]','[24,85]+\newline[54,85]+\newline same','[2 85]+[24 85]+\newline[54 85]+same'})
% ylim([60 110])
xlabel('滤波频带')
ylabel('Accuracy [%]')
title('高频SSaVEP不同频带十指令分类','FontName','宋体','FontSize',13,'FontWeight','Bold')
ax = gca;
set(ax,'FontName','微软雅黑','FontSize',13,'FontWeight','Bold')