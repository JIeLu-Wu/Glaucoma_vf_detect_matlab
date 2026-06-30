"""不同 foldNum 叠加数量比较主入口。

后续对应 MATLAB:
- AI_compare_foldnum_accumulation.m
"""

from pathlib import Path
import sys


PROJECT_ROOT = Path(__file__).resolve().parents[1]
if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))

from src.common.io_utils import load_yaml
from src.common.logging_utils import setup_logger


def main() -> None:
    """foldNum 分析主流程占位。"""
    project_root = PROJECT_ROOT
    config_path = project_root / "config" / "default_config.yaml"
    _ = load_yaml(config_path)
    logger = setup_logger("foldnum_comparison", project_root / "logs" / "foldnum_comparison.log")
    logger.info("Loaded config: %s", config_path)
    logger.info("FoldNum comparison pipeline is not implemented yet.")


if __name__ == "__main__":
    main()
