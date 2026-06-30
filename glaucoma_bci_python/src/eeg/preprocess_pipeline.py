"""CNT 到四维 EEG 试次数组的完整预处理流程。

这个文件把读取、事件提取、滤波、降采样、分段串起来。
后续临床报告和模拟实验都可以调用这里，避免每个主脚本重复写一遍。
"""

from __future__ import annotations

from pathlib import Path

from config.config import BANDPASS_PARAM, DATA_UNIT, EPOCH_TIME_WINDOW, LOWPASS_HZ, TARGET_SAMPLE_RATE
from src.eeg.cnt_reader import extract_cnt_events, read_cnt_raw
from src.eeg.epoching import count_trials_by_event_type, epoch_by_event_type
from src.eeg.preprocessing import chebyshev_bandpass_filter, get_eeg_data_array, lowpass_and_resample


def load_cnt_epochs(
    cnt_file: str | Path,
    max_event_count: int | None = None,
    target_sample_rate: int = TARGET_SAMPLE_RATE,
    epoch_time_window: list[float] = EPOCH_TIME_WINDOW,
    bandpass_param: list[float] = BANDPASS_PARAM,
    lowpass_hz: float = LOWPASS_HZ,
    data_unit: str = DATA_UNIT,
) -> dict:
    """读取一个 CNT 文件，并输出 DCPM 可以使用的四维试次数组。

    参数
    ----
    cnt_file:
        CNT 文件路径。
    max_event_count:
        最多保留多少个事件。训练数据一般为 400，测试数据一般为 240。
    target_sample_rate:
        降采样后的采样率。
    epoch_time_window:
        每个事件后截取的时间窗，单位秒。
    bandpass_param:
        Chebyshev 带通参数 `[低频阻带, 低频通带, 高频通带, 高频阻带]`。
    lowpass_hz:
        降采样前低通截止频率。
    data_unit:
        输出 EEG 单位，默认微伏 `uV`。

    返回
    ----
    result:
        字典格式结果，主要字段包括：
        - `epoch_data`: EEG 试次数据，形状为 `通道 × 时间点 × 试次 × 类型`；
        - `event_types`: 截段后保留下来的刺激类型；
        - `raw_event_types`: 原始事件类型；
        - `raw_event_count`: 原始有效事件数量；
        - `trial_count_before_epoch`: 分段前每类事件数量；
        - `channel_names`: CNT 文件中的通道名称；
        - `sample_rate`: 预处理后的采样率。
    """

    raw = read_cnt_raw(cnt_file, preload=True)
    raw_event_types, raw_event_samples = extract_cnt_events(raw, max_event_count=max_event_count)
    trial_count_before_epoch = count_trials_by_event_type(raw_event_types)

    processed_raw, resampled_event_samples = lowpass_and_resample(
        raw=raw,
        event_samples=raw_event_samples,
        target_sample_rate=target_sample_rate,
        lowpass_hz=lowpass_hz,
    )

    continuous_data = get_eeg_data_array(processed_raw, data_unit=data_unit)
    filtered_data = chebyshev_bandpass_filter(
        data=continuous_data,
        sample_rate=target_sample_rate,
        bandpass_param=bandpass_param,
    )

    epoch_data, event_types_after_epoch = epoch_by_event_type(
        continuous_data=filtered_data,
        event_types=raw_event_types,
        event_samples=resampled_event_samples,
        sample_rate=target_sample_rate,
        epoch_time_window=epoch_time_window,
    )

    result = {
        "epoch_data": epoch_data,
        "event_types": event_types_after_epoch,
        "raw_event_types": raw_event_types,
        "raw_event_count": len(raw_event_types),
        "trial_count_before_epoch": trial_count_before_epoch,
        "channel_names": processed_raw.ch_names,
        "sample_rate": target_sample_rate,
        "epoch_time_window": epoch_time_window,
        "data_unit": data_unit,
    }

    return result

