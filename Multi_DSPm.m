function [rr]=Multi_DSPm(index1,Train_Data,Test_Data)
 % **********************************************
 % Train_Data:channel*time*trial*class  % 21*0.75s*50个试次*8类
 % Test_Data：导联*时间*试次 
 % index1:reduce demension index   % 降维参数？什么意思，特征值的数量 8 9 或21
 % **********************************************
 %% *****************多类DSP***************
 Train_Data_For_DSP=Train_Data;
 i=1;
 for x=1:size(Train_Data_For_DSP,4)% x,y 是类别，这里要两两配对计算W，维度为   *   *  28（C82）
   for y=1:size(Train_Data_For_DSP,4)
     if x<y
       TrainData_Class_1_before_DSP = Train_Data_For_DSP(:,:,:,x);
       TrainData_Class_2_before_DSP = Train_Data_For_DSP(:,:,:,y);
       [W(:,:,i), D] = Z_DSP(TrainData_Class_1_before_DSP,TrainData_Class_2_before_DSP); 
       i=i+1;
     end
   end
 end
 %%
%  index = 53+1
%  plot(TrainData_Class_1_before_DSP(19,:,index))
%  max(TrainData_Class_1_before_DSP(19,:,index))
%  temp0 = mean(TrainData_Class_1_before_DSP,3)
 %%
 
 W_Comb= reshape(W(:,1:index1,:),size(W(:,1:index1,:),1),size(W(:,1:index1,:),2)*size(W(:,1:index1,:),3),1);
 Temp=permute(squeeze(mean(Train_Data_For_DSP,3)),[2 1 3]);  % 176 * 21 * 4   % 转置
 
 for cls=1:size(Temp,3)%中心化
   Template(:,:,cls)=Temp(:,:,cls)-repmat(mean(Temp(:,:,cls)),size(Temp(:,:,cls),1),1); 
   Tmpt(:,:,cls)=real(Template(:,:,cls)) * W_Comb;
 end
 siz=size(Template,1); 
  %% *****测试集*******
 for trials=1:size(Test_Data,3)
      for cls=1:size(Tmpt,3)
         test=squeeze(Test_Data(:,:,trials))';
         test=test-repmat(mean(test),siz,1);%中心化，使其均值为0
         Test=test * W_Comb;%滤波
         rr(trials,cls)=corr2(Test,Tmpt(:,:,cls));%每一行代表一个试次和不同模板的相关系数，对角线最大
      end
 end

end