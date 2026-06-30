"""概率计算对照测试。"""

import numpy as np

from src.visual_field.label_mapping import template_prob_to_eye_prob


def test_template_prob_to_eye_prob() -> None:
    template_prob = np.array(
        [
            [0.8, 0.1],
            [0.1, 0.7],
            [0.1, 0.2],
        ]
    )
    eye_prob = template_prob_to_eye_prob(template_prob)
    np.testing.assert_allclose(eye_prob, template_prob[[0, 2, 1], :])
