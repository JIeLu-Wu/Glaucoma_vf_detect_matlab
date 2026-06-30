"""概率类别和左右眼标签映射。

目标对应 MATLAB:
- AI_template_prob_to_eye_prob
- AI_ensure_clinical_result_eye_mapping
"""

import numpy as np


def template_prob_to_eye_prob(template_prob: np.ndarray) -> np.ndarray:
    """把模板顺序概率转换成报告使用的眼别顺序概率。

    输入:
        template_prob: shape = (3, n_block)
            第1行: normal
            第2行: 模板1存在、模板2缺失
            第3行: 模板1缺失、模板2存在

    输出:
        eye_prob: shape = (3, n_block)
            第1行: normal
            第2行: left_abnormal
            第3行: right_abnormal
    """
    if template_prob.shape[0] != 3:
        raise ValueError("template_prob must have shape (3, n_block).")
    return template_prob[[0, 2, 1], :]
