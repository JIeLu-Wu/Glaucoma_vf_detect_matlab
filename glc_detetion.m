%% 检测部分代码打包
function rou = glc_detection(temp,test_trials,fold_num)
    RR = Multi_DSPm(8,temp,test_trials(:,:,:));
    for fold_i = 1:size(RR,1)/fold_num
        RR_fold(fold_i,:) = mean(RR((fold_i-1)*fold_num+1:fold_i*fold_num,:),1);
    end
    [~,rou] = max(RR_fold,[],2);