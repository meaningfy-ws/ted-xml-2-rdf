import pytest

from ted_sws import config
from ted_sws.core.model.manifestation import XMLManifestation, RDFManifestation
from ted_sws.core.model.metadata import TEDMetadata
from ted_sws.core.model.notice import Notice
from tests import TEST_DATA_PATH


@pytest.fixture
def limes_sparql_endpoint() -> str:
    return f"{config.FUSEKI_ADMIN_HOST}/test_limes/query"


@pytest.fixture
def notice_with_distilled_rdf_manifestation():
    notice = Notice(ted_id="002705-2021")
    notice.set_xml_manifestation(XMLManifestation(object_data="No XML data"))
    notice.set_original_metadata(TEDMetadata())
    rdf_content_path = TEST_DATA_PATH / "rdf_manifestations" / "002705-2021.ttl"
    notice._distilled_rdf_manifestation = RDFManifestation(object_data=rdf_content_path.read_text(encoding="utf-8"))
    return notice