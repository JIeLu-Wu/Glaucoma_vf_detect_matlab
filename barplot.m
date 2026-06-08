close all
X=[];
figure,
X = X'*100;

b = bar(X,'FaceColor','flat');

% title('不同算法的分类效果','FontName','宋体','FontSize',13,'FontWeight','Bold')
color= [0.78,0.67,0.95;0.58,0.88,0.94;0.9,0.94,0.58;0.78,0.67,0.95;0.58,0.88,0.94;0.9,0.94,0.58;0.78,0.67,0.95;0.58,0.88,0.94;0.9,0.94,0.58];
% aaa = [4,2,1];
for k = 1:2
    b(k).CData = color(k,:);
end
xlabel('被试')
ylabel('Accuracy')
a=legend({'对照组';'引入测试数据先验'},'location','northwest');

% a=legend({'正常水平对称内圈';'正常垂直对称内圈';'正常中心对称内圈';'缺损垂直对称内圈';'缺损垂直对称内圈';'缺损垂直对称内圈';'缺损垂直对称外圈';'缺损垂直对称外圈';'缺损垂直对称外圈'},'location','northwest');
% a.NumColumns = 3;
% yticklabels({'-3';'-2';'-1';'0';'1';'Sub6';'Ave'})
% % legend({'1s','1.5s','2s'},'location','southeast')
% xticklabels({'[2,20]';'[58,85]';'[28,85]';'[2,85]';'[28,85]+[58,85]';'[2,85]+[28,85]+[58,85]'})
xticklabels({'Sub1';'Sub2';'Sub3';'Sub4';'Sub5'; 'Mean'})
% ylim([0 105])
title('检测结果','FontName','黑体','FontSize',16,'FontWeight','Bold')
% legend({'Hololens相位补偿后数据','标准数据'},'location','northwest')
% % legend({'1s','1.5s','2s'},'location','southeast')
% xticklabels({'S','C'})

% xticklabels({'全部编码的字符','编码为4321的字符','编码为3214的字符','编码为3142的字符','编码为1432的字符','编码为1234的字符',})
% xticklabels({'8/12Hz','9/10Hz','10/11Hz','10/12Hz','11/12Hz','11/13Hz','11/14Hz','12/14Hz'})
% xticklabels({'10/11/12Hz','10/11/13Hz','10/11/14Hz','11/12/13Hz','11/12/14Hz'})
% xticklabels({'9/10/11/12Hz','9/10/11/13Hz','10/11/12/13Hz','10/11/12/14Hz','10/11/13/14Hz','11/12/13/14Hz'})
ax = gca;
set(ax,'FontName','黑体','FontSize',16,'FontWeight','Bold')

%% 绘制多个点集成的结果
% 分类决策值叠加结果
X = [];
close all
b = bar(X,'FaceColor','flat');
color= [0.78,0.67,0.95;0.58,0.88,0.94;0.9,0.94,0.58;0.78,0.67,0.95;0.58,0.88,0.94];
% aaa = [4,2,1];
for k = 1:4
    b(k).CData = color(k,:);
end
xlabel('被试')
ylabel('Accuracy')
a=legend({'叠加1点';'叠加2点';'叠加3点';'叠加4点';'叠加5点'},'location','southeast');
xticklabels({'Sub1';'Sub2';'Sub3';'Sub4';'Sub5';'被试叠加'})
ax = gca;
set(ax,'FontName','微软雅黑','FontSize',13,'FontWeight','Bold')
