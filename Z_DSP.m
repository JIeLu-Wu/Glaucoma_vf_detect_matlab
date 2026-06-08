function [V,D]=Z_DSP(X,Y)
 % the data form of input X、Y ,is channel*time*trial. X and Y are two classes train data. 
%% **********************DSP************************************ 

% 不需要标准化吗？？？？？？？

% 将协方差矩阵分成四部分
    Template_Class_11 = mean(X,3)';
    Template_Class_22 = mean(Y,3)';
    cov_all = cov([Template_Class_11,Template_Class_22]);
    cov11 = cov_all(1:size(Template_Class_11,2),1:size(Template_Class_11,2));
    cov22 = cov_all(size(Template_Class_11,2)+1:2*size(Template_Class_11,2),size(Template_Class_11,2)+1:2*size(Template_Class_11,2));
    cov12 = cov_all(1:size(Template_Class_11,2),size(Template_Class_11,2)+1:2 * size(Template_Class_11,2));
    cov21 = cov_all(size(Template_Class_11,2)+1:2*size(Template_Class_11,2),1:size(Template_Class_11,2));
    Sb = cov11+cov22-cov12-cov21;  
  %% Sb******************
    for n = 1:size(X,3)
       cov_all1(:,:,n)=cov(X(:,:,n)'-Template_Class_11);
    end
       cov_0=mean(cov_all1,3);
    for n = 1:size(Y,3)
       cov_all2(:,:,n)=cov(Y(:,:,n)'-Template_Class_22);
    end
    cov_1 = mean(cov_all2,3);
    Sw = cov_0+cov_1;
  %% Sw******************
   A=Sw\Sb;
  [V_raw,D_raw] = eig(A); 
  eigvalue=diag(D_raw);         % 将对角矩阵中的对角线元素提取出来然后形成向量
  [D,index]=sort(eigvalue(:,1),1,'descend');% 对eigvalue中的元素进行降序排列，获取原先索引
  V=V_raw(:,index);   % ---------------- 修改--------------------- 获取索引