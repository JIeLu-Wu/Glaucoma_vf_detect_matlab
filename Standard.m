function Standard_Data = Standard(Data)
% 对数据进行标准化，去均值除方差
    chan_num = size(Data,1);
    for chan_i = 1:chan_num
        Standard_Data(chan_i,:) = (Data(chan_i,:)-mean(Data(chan_i,:)))/var(Data(chan_i,:));
    end
end