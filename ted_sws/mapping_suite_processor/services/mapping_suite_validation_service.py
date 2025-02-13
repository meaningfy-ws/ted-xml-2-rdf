import json
import pathlib
from typing import Optional

from ted_sws.data_manager.adapters.mapping_suite_repository import MS_METADATA_FILE_NAME, \
    MS_STANDARD_METADATA_VERSION_KEY, MS_METADATA_IDENTIFIER_KEY, \
    MS_EFORMS_METADATA_VERSION_KEY
from ted_sws.mapping_suite_processor.adapters.mapping_suite_structure_checker import MappingSuiteStructureValidator


def get_mapping_suite_id_from_file_system(mapping_suite_path: pathlib.Path) -> Optional[str]:
    """
        This function return mapping_suite_id from file system location.
    :param mapping_suite_path:
    :return:
    """
    mapping_suite_metadata_path = mapping_suite_path / MS_METADATA_FILE_NAME

    if mapping_suite_metadata_path.exists() and mapping_suite_metadata_path.is_file():
        mapping_suite_metadata = json.loads(mapping_suite_metadata_path.read_text(encoding="utf-8"))
        identifier_value = mapping_suite_metadata[MS_METADATA_IDENTIFIER_KEY]
        version_value = mapping_suite_metadata[
            MS_STANDARD_METADATA_VERSION_KEY] if MS_STANDARD_METADATA_VERSION_KEY in mapping_suite_metadata else \
        mapping_suite_metadata[MS_EFORMS_METADATA_VERSION_KEY]
        return f"{identifier_value}_v{version_value}"
    return None


def validate_mapping_suite(mapping_suite_path: pathlib.Path) -> bool:
    """
        This function validate mapping suite structure in file system.
    :param mapping_suite_path:
    :return:
    """
    mapping_suite_validator = MappingSuiteStructureValidator(mapping_suite_path)

    return mapping_suite_validator.is_valid()
