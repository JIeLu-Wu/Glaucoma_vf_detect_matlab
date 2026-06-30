"""临床实验生成 SAP-like 报告的主入口。

后续对应 MATLAB:
- AI_generate_sap_like_clinical_report.m
"""

from pathlib import Path
import sys


PROJECT_ROOT = Path(__file__).resolve().parents[1]
if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))

from src.common.io_utils import load_yaml
from src.common.logging_utils import setup_logger


def main() -> None:
    """临床报告主流程占位。"""
    project_root = PROJECT_ROOT
    config_path = project_root / "config" / "clinical_config.yaml"
    config = load_yaml(config_path)
    logger = setup_logger("clinical_report", project_root / "logs" / "clinical_report.log")
    logger.info("Loaded config: %s", config_path)
    logger.info("Clinical report pipeline is not implemented yet.")
    logger.info("Data dir: %s", config["data"]["data_dir"])


if __name__ == "__main__":
    main()
