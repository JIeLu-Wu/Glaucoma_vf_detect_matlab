"""根据事件把连续 EEG 截成试次数据。

这一部分对应 MATLAB `EEGRead5.m` 中的分段逻辑：

```matlab
char_start_time = latency_resample + round(win(1)*Fs) + 1;
char_end_time = latency_resample + round(win(2)*Fs);
data_ori(:,:,trial_i,type_i) = data_char(:,char_start_time:char_end_time);
```

Python 版最终输出的维度保持为：
`通道数 × 时间点数 × 试次数 × 刺激类型数`
这样后续迁移 DCPM 时可以最大程度沿用 MATLAB 的思路。
"""

from __future__ import annotations

import numpy as np


def matlab_round(sample_value: float) -> int:
    """按照 MATLAB 的 round 规则把时间换算成采样点数。

    需要单独写这个函数，是因为 Python 自带的 `round` 和 MATLAB 的 `round`
    在 0.5 这种临界值上规则不同：

    - MATLAB: round(112.5) = 113
    - Python: round(112.5) = 112

    你的时间窗 `[0, 0.45]` 在 250 Hz 下正好是 112.5 个采样点，
    所以这里必须使用 MATLAB 的规则，才能尽量保证 Python 和 MATLAB 输出一致。
    """

    if sample_value >= 0:
        return int(np.floor(sample_value + 0.5))

    return int(np.ceil(sample_value - 0.5))


def epoch_by_event_type(
    continuous_data: np.ndarray,
    event_types: np.ndarray,
    event_samples: np.ndarray,
    sample_rate: int,
    epoch_time_window: list[float],
) -> tuple[np.ndarray, np.ndarray]:
    """按照事件类型截取 EEG 试次。

    参数
    ----
    continuous_data:
        连续 EEG 数据，形状为 `通道数 × 时间点数`。
    event_types:
        每个事件的刺激类型，例如 1、2、3、4。
    event_samples:
        每个事件在连续 EEG 中对应的采样点。
    sample_rate:
        当前采样率，例如 250 Hz。
    epoch_time_window:
        截取时间窗，单位秒，例如 `[0, 0.45]`。

    返回
    ----
    epoch_data:
        分段后的 EEG 数据，形状为 `通道数 × 时间点数 × 试次数 × 刺激类型数`。
        如果不同刺激类型试次数不完全相同，会按最少试次数对齐，避免出现空数据。
    unique_event_types:
        实际保留下来的刺激类型，顺序从小到大。
    """

    channel_count, total_sample_count = continuous_data.shape
    start_offset = matlab_round(epoch_time_window[0] * sample_rate)
    end_offset = matlab_round(epoch_time_window[1] * sample_rate)
    epoch_sample_count = end_offset - start_offset

    if channel_count <= 0:
        raise ValueError("continuous_data 没有任何通道。")

    if epoch_sample_count <= 0:
        raise ValueError("epoch_time_window 设置不合理，结束时间必须大于开始时间。")

    unique_event_types = np.unique(event_types)
    epochs_by_type = []
    valid_event_types = []

    for current_event_type in unique_event_types:
        current_event_indices = np.where(event_types == current_event_type)[0]
        current_type_epochs = []

        for event_index in current_event_indices:
            event_sample = int(event_samples[event_index])
            epoch_start = event_sample + start_offset
            epoch_end = event_sample + end_offset

            # 如果事件太靠近文件开头或结尾，截取窗口会越界，这个试次就跳过。
            if epoch_start < 0 or epoch_end > total_sample_count:
                continue

            current_epoch = continuous_data[:, epoch_start:epoch_end]
            current_type_epochs.append(current_epoch)

        if len(current_type_epochs) == 0:
            continue

        current_type_epochs = np.stack(current_type_epochs, axis=2)
        epochs_by_type.append(current_type_epochs)
        valid_event_types.append(current_event_type)

    if len(epochs_by_type) == 0:
        raise ValueError("没有成功截取到任何 EEG 试次，请检查事件位置和时间窗。")

    # MATLAB 的四维数组要求每个类别的试次数一致。
    # 如果某一类因为边界原因少了试次，这里统一截到最小试次数。
    min_trial_count = min(type_epochs.shape[2] for type_epochs in epochs_by_type)
    trimmed_epochs = [type_epochs[:, :, :min_trial_count] for type_epochs in epochs_by_type]

    epoch_data = np.stack(trimmed_epochs, axis=3)
    valid_event_types = np.asarray(valid_event_types, dtype=int)

    return epoch_data, valid_event_types


def count_trials_by_event_type(event_types: np.ndarray) -> dict[int, int]:
    """统计每种刺激类型对应多少个原始事件。

    这个函数主要用于检查数据是否完整，例如 4 个刺激点是否试次数接近。
    """

    trial_count = {}
    for current_event_type in np.unique(event_types):
        trial_count[int(current_event_type)] = int(np.sum(event_types == current_event_type))

    return trial_count
