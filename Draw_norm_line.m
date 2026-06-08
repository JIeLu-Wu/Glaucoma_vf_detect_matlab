function [ave,stdd] = Draw_norm_line(TP_value,xlim_range,title_text,para)
[h1,p1] = lillietest(TP_value(:,1));% h 为0 则符合正态分布
[h2,p2] = lillietest(TP_value(:,2));
ave_value_1 = mean(TP_value(:,1));
ave_value_2 = mean(TP_value(:,2));
std_value_1 = std(TP_value(:,1));
std_value_2 = std(TP_value(:,2));
x = -5:0.001:5;
fx_1 = normpdf(x,ave_value_1,std_value_1);
fx_2 = normpdf(x,ave_value_2,std_value_2);

histogram(TP_value(:,1),15,'FaceColor',[0.66,0.85,0.94])
hold on 

xlim(xlim_range)
histogram(TP_value(:,2),15,'FaceColor',[0.93,0.69,0.13])
plot(x,fx_1,'LineWidth',1.5,'Color',[0,0,1])
plot(x,fx_2,'LineWidth',1.5,'Color',[1,0,0])
hold off
ave = cat(2,ave_value_1,ave_value_2);
stdd = cat(2,std_value_1,std_value_2);
set(gca,'FontName','Arial','FontSize',10,'FontWeight','bold')
title(title_text, 'FontName','Arial','FontSize',10,'FontWeight','bold')
legend(para,'FontName','Arial','FontSize',10,'FontWeight','bold','location','Northwest')