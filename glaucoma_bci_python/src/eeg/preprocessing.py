"""EEG 滤波和重采样。

这一部分主要对应 MATLAB 中的：
- `EEGRead5.m` 里的低通、降采样步骤；
- `DataPrePro.m` 里的 Chebyshev 带通滤波。

当前处理顺序保持和 MATLAB 尽量一致：
1. 对连续 EEG 做 90 Hz 低通；
2. 从原始采样率降采样到目标采样率；
3. 对降采样后的数据做 Chebyshev 带通。
"""

from __future__ import annotations

import numpy as np
from scipy.signal import cheb1ord, cheby1, filtfilt


def lowpass_and_resample(raw, event_samples: np.ndarray, target_sample_rate: int, lowpass_hz: float):
    """对连续 EEG 做低通滤波和降采样，同时更新事件采样点。

    参数
    ----
    raw:
        MNE 的 Raw 对象，包含连续 EEG。
    event_samples:
        原始采样率下的事件采样点。
    target_sample_rate:
        目标采样率，例如 250 Hz。
    lowpass_hz:
        降采样前的低通截止频率，例如 90 Hz。

    返回
    ----
    processed_raw:
        已经低通并降采样后的 Raw 对象。
    resampled_event_samples:
        降采样后的事件采样点。
    """

    processed_raw = raw.copy().load_data()

    # 先低通再降采样，目的是减少降采样时的频率混叠。
    processed_raw.filter(
        l_freq=None,
        h_freq=lowpass_hz,
        method="fir",
        phase="zero",
        fir_design="firwin",
        verbose="ERROR",
    )

    # MNE 的 resample 可以同时更新事件采样点，避免手动四舍五入造成偏差。
    mne_events = np.column_stack(
        [
            event_samples.astype(int),
            np.zeros(len(event_samples), dtype=int),
            np.ones(len(event_samples), dtype=int),
        ]
    )
    processed_raw, resampled_events = processed_raw.resample(
        target_sample_rate,
        events=mne_events,
        verbose="ERROR",
    )

    # 这里加 1 个采样点，是为了和 MATLAB 的 EEGRead5.m 分段结果对齐。
    #
    # 原因是：
    # - EEGLAB/MATLAB 中的事件 latency 更接近 1-based 采样点；
    # - MNE 中的事件 sample 是 0-based 采样点；
    # - MATLAB 代码又使用了 `char_start_time = latency_resample + round(win(1)*Fs) + 1`。
    #
    # 用 train1.cnt 和 MATLAB 导出的 data_seg 对比后，发现加 1 个采样点时，
    # Python 和 MATLAB 的平均 ERP 波形相关系数最高。
    resampled_event_samples = resampled_events[:, 0].astype(int) + 1

    return processed_raw, resampled_event_samples


def chebyshev_bandpass_filter(data: np.ndarray, sample_rate: int, bandpass_param: list[float]) -> np.ndarray:
    """使用 Chebyshev I 型滤波器做带通滤波。

    这个函数对应 MATLAB 的 `DataPrePro.m`：

    ```matlab
    Wp=[2*Wn_para(2)/Fs 2*Wn_para(3)/Fs];
    Ws=[2*Wn_para(1)/Fs 2*Wn_para(4)/Fs];
    [N,Wn]=cheb1ord(Wp,Ws,3,40);
    [f_b,f_a] = cheby1(N,0.5,Wn);
    data_filter = filtfilt(f_b,f_a,data_org');
    ```

    参数
    ----
    data:
        EEG 数据，形状为 `通道数 × 时间点数`。
    sample_rate:
        当前数据采样率，例如 250 Hz。
    bandpass_param:
        `[低频阻带, 低频通带, 高频通带, 高频阻带]`，单位 Hz。
        如果传入 `[0, 0, 0, 0]`，表示不做带通滤波。

    返回
    ----
    filtered_data:
        滤波后的 EEG 数据，形状仍为 `通道数 × 时间点数`。
    """

    if np.allclose(bandpass_param, [0, 0, 0, 0]):
        return data.copy()

    stop_low_hz, pass_low_hz, pass_high_hz, stop_high_hz = bandpass_param

    pass_band = [2 * pass_low_hz / sample_rate, 2 * pass_high_hz / sample_rate]
    stop_band = [2 * stop_low_hz / sample_rate, 2 * stop_high_hz / sample_rate]

    filter_order, natural_frequency = cheb1ord(pass_band, stop_band, 3, 40)
    filter_b, filter_a = cheby1(filter_order, 0.5, natural_frequency, btype="bandpass")

    # filtfilt 是零相位滤波，和 MATLAB 逻辑一致。axis=1 表示沿时间维滤波。
    filtered_data = filtfilt(filter_b, filter_a, data, axis=1)

    return filtered_data


def get_eeg_data_array(raw, data_unit: str = "uV") -> np.ndarray:
    """从 MNE Raw 对象中取出连续 EEG 数组。

    参数
    ----
    raw:
        MNE 的 Raw 对象。
    data_unit:
        输出单位。`uV` 表示微伏，`V` 表示伏特。

    返回
    ----
    eeg_data:
        连续 EEG 数据，形状为 `通道数 × 时间点数`。
    """

    eeg_data = raw.get_data()

    if data_unit == "uV":
        eeg_data = eeg_data * 1e6
    elif data_unit == "V":
        eeg_data = eeg_data.copy()
    else:
        raise ValueError("data_unit 只能是 'uV' 或 'V'。")

    return eeg_data
