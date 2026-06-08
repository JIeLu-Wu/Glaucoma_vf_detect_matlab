function [prob, logScore] = accumulate_prob_dv(Prob_dv, temperature, weights)
%ACCUMULATE_PROB_DV 累积多个叠加单元的三类归一化似然评分
%
% 输入:
%   Prob_dv: 3 × N
%       第1行: 正常评分
%       第2行: 左眼异常评分
%       第3行: 右眼异常评分
%
%   temperature: 可选，温度参数，默认 1
%       < 1: 输出更尖锐
%       > 1: 输出更保守
%
%   weights: 可选，1 × N，每个叠加单元的权重，默认全为 1
%
% 输出:
%   prob: 3 × 1
%       累积后的三类概率
%
%   logScore: 3 × 1
%       三类累积 log 证据

    if nargin < 2 || isempty(temperature)
        temperature = 1;
    end

    if nargin < 3 || isempty(weights)
        weights = ones(1, size(Prob_dv, 2));
    end

    if size(Prob_dv, 1) ~= 3
        error('Prob_dv must be a 3 × N matrix.');
    end

    if length(weights) ~= size(Prob_dv, 2)
        error('weights must have length N.');
    end

    eps_val = 1e-12;

    % 防止 log(0)，并确保每一列重新归一化
    Prob_dv = max(Prob_dv, eps_val);
    Prob_dv = Prob_dv ./ sum(Prob_dv, 1);

    weights = reshape(weights, 1, []);
%     % 连乘
%     % 累积 log 证据，等价于对每个叠加单元的评分连乘
%     logScore = sum(log(Prob_dv) .* weights, 2);
% 
%     % 温度缩放
%     logScore_T = logScore ./ temperature;
% 
%     % stable softmax
%     logScore_T = logScore_T - max(logScore_T);
%     prob = exp(logScore_T);
%     prob = prob ./ sum(prob);

%    % log相加
    logScore = sum(log(Prob_dv) .* weights, 2);

    % 有效证据强度
    logScore = logScore .* temperature;
%     logScore = logScore/size(Prob_dv,2);
    % stable softmax
    logScore_shift = logScore - max(logScore);
    prob = exp(logScore_shift);
    prob = prob ./ sum(prob);
end