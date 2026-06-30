"""CNT 文件读取和事件提取。

这一部分主要对应 MATLAB 中的：
- `EEGRead5.m` 里读取 CNT 文件的部分
- `pop_loadcnt.m` / `loadcnt.m`

本文件只负责两件事：
1. 把 CNT 文件读成 MNE 的 Raw 对象；
2. 从 Raw 对象里提取刺激事件的类型和采样点位置。
"""

from __future__ import annotations

from pathlib import Path
from typing import Optional
import warnings

import mne
import numpy as np


def read_cnt_raw(cnt_file: str | Path, preload: bool = True):
    """读取一个 Neuroscan CNT 文件。

    参数
    ----
    cnt_file:
        CNT 文件路径，例如 `train1.cnt`。
    preload:
        是否把数据一次性读入内存。后续要滤波和降采样，所以默认设为 True。

    返回
    ----
    raw:
        MNE 的 RawCNT 对象，里面包含连续 EEG、通道名、事件标记等信息。
    """

    cnt_file = Path(cnt_file)
    if not cnt_file.exists():
        raise FileNotFoundError(f"找不到 CNT 文件：{cnt_file}")

    # 有些 CNT 文件头里的日期格式 MNE 解析不了，会提示 meas date 警告。
    # 这个警告不影响 EEG 数据和事件读取，所以这里屏蔽掉，避免检查脚本输出太乱。
    with warnings.catch_warnings():
        warnings.filterwarnings("ignore", message=".*Could not parse meas date.*", category=RuntimeWarning)
        raw = mne.io.read_raw_cnt(
            cnt_file,
            data_format="int32",
            preload=preload,
            verbose="ERROR",
        )

    return raw


def extract_cnt_events(raw, max_event_count: Optional[int] = None) -> tuple[np.ndarray, np.ndarray]:
    """从 CNT Raw 对象中提取事件类型和事件采样点。

    MATLAB 里的 `EEGRead5.m` 使用的是：

    ```matlab
    event = [EEG.event.type]';
    latency = round([EEG.event.latency]');
    ```

    Python 版这里输出两个数组：
    - event_types: 每个事件的刺激类型，例如 1、2、3、4；
    - event_samples: 每个事件在连续 EEG 中对应的采样点位置。

    参数
    ----
    raw:
        MNE 读取 CNT 后得到的 Raw 对象。
    max_event_count:
        最多保留多少个事件。训练文件一般是 400，测试文件一般是 240。
        如果为 None，就保留所有有效刺激事件。

    返回
    ----
    event_types:
        一维数组，长度为事件数，表示事件类型。
    event_samples:
        一维数组，长度为事件数，表示事件所在采样点。
    """

    events, event_id = mne.events_from_annotations(raw, verbose="ERROR")
    if len(events) == 0:
        raise ValueError("没有从 CNT 文件中读取到任何事件，请检查 CNT 文件或事件标记。")

    event_code_to_type = {}
    for event_name, event_code in event_id.items():
        event_name_text = str(event_name).strip()

        # CNT 里的刺激事件通常可以转成数字；boundary 等非刺激事件不能转成数字，需要跳过。
        try:
            event_type = int(float(event_name_text))
        except ValueError:
            continue

        if event_type > 0:
            event_code_to_type[event_code] = event_type

    event_samples = []
    event_types = []
    for event_row in events:
        event_sample = int(event_row[0])
        event_code = int(event_row[2])

        if event_code not in event_code_to_type:
            continue

        event_samples.append(event_sample)
        event_types.append(event_code_to_type[event_code])

    if len(event_types) == 0:
        raise ValueError("读取到了事件，但没有找到可以转成数字的刺激事件类型。")

    event_samples = np.asarray(event_samples, dtype=int)
    event_types = np.asarray(event_types, dtype=int)

    if max_event_count is not None and len(event_types) > max_event_count:
        event_samples = event_samples[:max_event_count]
        event_types = event_types[:max_event_count]

    return event_types, event_samples
