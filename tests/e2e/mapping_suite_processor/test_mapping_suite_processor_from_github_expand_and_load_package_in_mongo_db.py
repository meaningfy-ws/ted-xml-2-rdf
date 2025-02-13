from ted_sws.data_manager.adapters.mapping_suite_repository import MappingSuiteRepositoryMongoDB
from ted_sws.mapping_suite_processor.services.conceptual_mapping_processor import \
    mapping_suite_processor_from_github_expand_and_load_package_in_mongo_db

MAPPING_SUITE_PACKAGE_NAME = "package_F03_test"
MAPPING_SUITE_METADATA_IDENTIFIER = "package_F03"
MAPPING_SUITE_METADATA_VERSION = "6.8.1"
MAPPING_SUITE_PACKAGE_ID = f"{MAPPING_SUITE_METADATA_IDENTIFIER}_v{MAPPING_SUITE_METADATA_VERSION}"


def test_mapping_suite_processor_from_github_expand_and_load_package_in_mongo_db(fake_mongodb_client):
    mapping_suite_processor_from_github_expand_and_load_package_in_mongo_db(
        mapping_suite_package_name=MAPPING_SUITE_PACKAGE_NAME,
        mongodb_client=fake_mongodb_client,
        load_test_data=True
    )
    mapping_suite_repository = MappingSuiteRepositoryMongoDB(mongodb_client=fake_mongodb_client)
    mapping_suite = mapping_suite_repository.get(reference=MAPPING_SUITE_PACKAGE_ID)
    assert mapping_suite
