function fold_idx = fold_idx_gen(fold_num,trial_num,code_len)
idx = 1:trial_num;
round_num = trial_num/code_len;
fold_idx = [];
for round_i = 1:round_num
    fold_idx = cat(1,fold_idx,[1:fold_num]+(round_i-1)*code_len);
end