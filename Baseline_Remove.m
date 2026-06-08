function Baseline_Data = Baseline_Remove(Data,baseline_point)
    chan_num = size(Data,1);
    for chan_i = 1:chan_num
        Baseline_Data(chan_i,:) = Data(chan_i,baseline_point+1:end)-mean(Data(chan_i,1:baseline_point));
    end

end