function RR = TRCA_fold(n_component,train_data,test_data,ensemble)

type_num = size(train_data,4);
W = [];
train_temp = [];
for type_i = 1:type_num
    train_i = train_data(:,:,:,type_i);
    w_i = trca_matrix(train_i);
    W = cat(2,W,w_i(:,1:n_component));
    train_temp_i = mean(train_i,3);
    train_temp_i = train_temp_i - repmat(mean(train_temp_i,2),1,size(train_temp_i,2));
    train_temp = cat(3,train_temp,train_temp_i);
end

for trial_i = 1:size(test_data,3)
    test_i = test_data(:,:,trial_i);
    test_i = test_i - repmat(mean(test_i,2),1,size(test_i,2));

    for type_i = 1:type_num
        if ensemble
            w_i = W;
        else 
            w_i = W(:,(type_i-1)*n_component+1:type_i*n_component);
        end
        train = train_temp(:,:,type_i);
        RR(trial_i,type_i) = corr2(train' * w_i, test_i' * w_i);
    end
end
a = 1;