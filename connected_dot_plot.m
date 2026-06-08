function ax = connected_dot_plot(r_mean, fig_title, ax)
    % plot dumbbell diagrams
    if nargin < 3 || isempty(ax)
        figure,
        clear gca
        set(gcf, 'Position', [100, 100, 300, 250]);
        ax = gca;
    end
    
    for i = 1:size(r_mean,1)
        plot([r_mean(i,1),r_mean(i,2),],'--','LineWidth',0.6,'Color',[0.6,0.6,0.6])
        hold on
        scatter([1],[r_mean(i,1)],'Marker','o','MarkerEdgeColor',[0.5,0.8,0.5],'LineWidth',2)%[0.93,0.78,0.38]
        scatter([2],[r_mean(i,2)],'Marker','o','MarkerEdgeColor',[0.93,0.78,0.38],'LineWidth',2)
    end                               
    plot([mean(r_mean(:,1)),mean(r_mean(:,2))],'LineWidth',0.8,'Color',[0,0,0])
    scatter([1],mean(r_mean(:,1)),'Marker','o','MarkerEdgeColor',[0,0,0],'LineWidth',3)%[0.93,0.78,0.38]
    scatter([2],mean(r_mean(:,2)),'Marker','o','MarkerEdgeColor',[0,0,0],'LineWidth',3)
    yline(0, '--', 'Color', [0.7 0.7 0.7], 'LineWidth', 1.2);
    hold off
    xlim([0.6,2.4])
%     ylim([-0.2,0.2])
    yticks([-0.2:0.1:0.2])
    yticklabels([-0.2:0.1:0.2])
    xticks([1,2])
    xticklabels({'r_1','r_2'})
    ylabel("Decision Value")
    title(fig_title,'FontName','Arial','FontSize',16,'FontWeight','Bold')
%     ax = gca;
    set(ax,'FontName','Arial','FontSize',13,'FontWeight','normal')
    box off
    
end