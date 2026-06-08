function [dv_fold, rou] = Decision_value_fold(dv, fold_num)
    dv_fold = [];
    for fold_i = 1:size(dv,1)/fold_num
        dv_fold(fold_i,:,:) = mean(dv((fold_i-1)*fold_num+1:fold_i*fold_num,:,:),1);
    end
    [~,rou] = max(dv_fold,[],2);
    rou = squeeze(rou);
end