"""决策值转三分类概率。

目标对应 MATLAB:
- Prob_calculate.m
- glc_detection_prob.m

注意：
Prob_calculate 的原始第2/第3类是模板顺序，不是最终报告眼别顺序。
临床 BM 刺激下需要通过 visual_field.label_mapping 转换为：
[normal, left_abnormal, right_abnormal]。
"""
