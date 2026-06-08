function [V,D]= trca_matrix(X)
% Task-related component analysis (TRCA)
%   X : eeg data (Num of channels * num of sample points * number of trials)
%   X:单个靶刺激的多轮trail数组，（channels,samples,trails）
%   V:特征向量

nChans  = size(X,1); %Num of channels
nTrials = size(X,3); %Num of trials
S = zeros(nChans, nChans);  %(9*9)

% Computation of correlation matrices 计算相关矩阵
for trial_i = 1:1:nTrials    %两两trail之间计算,提取数据
    for trial_j = 1:1:nTrials
        %if trial_i ~= trial_j
        x_i = X(:, :, trial_i);
        x_j = X(:, :,trial_j);
        S = S + x_i*x_j';  %（9*126）×（126*9）=（9*9）
        %end %if
    end % trial_j
end % trial_i

%直接计算方差矩阵
X1 = X(:,:);  %将3维以2维取出,相当于把第三维的数据按顺序接在第二维后面
X1 = X1 - repmat(mean(X1,2),1,size(X1,2)); %mean（a,b）中b为指定维数 repmat用于快速产生新矩阵
                                           %mean(X1,2)得到的是每一行的平均值（m行n列，得到m个数）（消掉第2个维度）
                                           %repmat(mean(X1,2),1,size(X1,2))得到n列相同的平均值，结果为m*n矩阵
Q = X1*X1';   

% TRCA eigenvalue algorithm
[V,D] = eig(Q\S); %[a,b]=eig(x)计算矩阵的特征值构成向量D，特征向量V(nChans, nChans)
%Y = V'*X;        %每个特征值对应一列特征向量