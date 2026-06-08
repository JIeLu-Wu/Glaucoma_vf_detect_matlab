function RR_cross = DCPM_cross_valid(temp_v,n_component,cross_num)
RR_cross = [];
[~, ~, trial_num, type_num] = size(temp_v);
test_trial_num = trial_num/cross_num;

for cross_i = 1:cross_num
    test_idx = (cross_i-1)*test_trial_num+1:cross_i*test_trial_num;
    train_idx = 1:trial_num;
    train_idx(test_idx) = [];

    train_data = temp_v(:,:,train_idx,:);
    test_data = temp_v(:,:,test_idx,:);

    for test_i = 1:type_num
        rr(:,:,test_i) = Multi_DSPm(n_component,train_data,test_data(:,:,:,test_i));
    end
    
    RR_cross = cat(1,RR_cross,rr);
end
