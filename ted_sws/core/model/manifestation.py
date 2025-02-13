#!/usr/bin/python3

# manifestation.py
# Date:  03/02/2022
# Author: Eugeniu Costetchi
# Email: costezki.eugen@gmail.com 

""" """
from datetime import datetime
from enum import Enum
from typing import List, Union, Optional, Dict

from pydantic import Field

from ted_sws.core.model import PropertyBaseModel
from ted_sws.core.model.validation_report_data import ReportNoticeData
from ted_sws.notice_packager.model.metadata import METS_TYPE_CREATE


class ManifestationMimeType(Enum):
    """
    MIME types for manifestations used in this application
    """
    METS = "application/zip"
    XML = "application/xml"
    RDF = "application/rdf+xml"
    TURTLE = "text/turtle"


class SPARQLQueryRefinedResultType(Enum):
    """
    The aggregated SPARQL Query result
    """
    VALID = "valid"
    UNVERIFIABLE = "unverifiable"
    INVALID = "invalid"
    ERROR = "error"
    WARNING = "warning"
    UNKNOWN = "unknown"


class Manifestation(PropertyBaseModel):
    """
        A manifestation that embodies a FRBR Work/Expression.
    """

    class Config:
        validate_assignment = True
        orm_mode = True

    object_data: str = Field(..., allow_mutation=True)

    def __str__(self):
        STR_LEN = 150  # constant
        content = self.object_data if self.object_data else ""
        return f"/{str(content)[:STR_LEN]}" + ("..." if len(content) > STR_LEN else "") + "/"


class ValidationManifestation(Manifestation):
    """
        The validation report
    """
    created: str = datetime.now().isoformat()


class XPATHCoverageSummaryResult(PropertyBaseModel):
    xpath_covered: Optional[int] = 0


class XPATHCoverageSummaryReport(PropertyBaseModel):
    mapping_suite_identifier: Optional[str]
    validation_result: Optional[XPATHCoverageSummaryResult] = XPATHCoverageSummaryResult()


class XMLManifestationValidationSummaryReport(PropertyBaseModel):
    xpath_coverage_summary: Optional[XPATHCoverageSummaryReport] = XPATHCoverageSummaryReport()


class SPARQLSummaryCountReport(PropertyBaseModel):
    valid: Optional[int] = 0
    unverifiable: Optional[int] = 0
    warning: Optional[int] = 0
    invalid: Optional[int] = 0
    error: Optional[int] = 0


class SPARQLSummaryResult(PropertyBaseModel):
    test_suite_identifier: Optional[str]
    mapping_suite_identifier: Optional[str]
    aggregate: Optional[SPARQLSummaryCountReport] = SPARQLSummaryCountReport()


class SPARQLSummaryReport(PropertyBaseModel):
    validation_results: Optional[List[SPARQLSummaryResult]] = []
    aggregate: Optional[SPARQLSummaryCountReport] = SPARQLSummaryCountReport()


class SHACLSummarySeverityCountReport(PropertyBaseModel):
    info: Optional[int] = 0
    warning: Optional[int] = 0
    violation: Optional[int] = 0


class SHACLSummaryResultSeverityReport(PropertyBaseModel):
    aggregate: Optional[SHACLSummarySeverityCountReport] = SHACLSummarySeverityCountReport()


class SHACLSummaryResult(PropertyBaseModel):
    test_suite_identifier: Optional[str]
    mapping_suite_identifier: Optional[str]
    result_severity: Optional[SHACLSummaryResultSeverityReport] = SHACLSummaryResultSeverityReport()


class SHACLSummaryReport(PropertyBaseModel):
    validation_results: Optional[List[SHACLSummaryResult]] = []
    result_severity: Optional[SHACLSummaryResultSeverityReport] = SHACLSummaryResultSeverityReport()


class RDFManifestationValidationSummaryReport(PropertyBaseModel):
    sparql_summary: Optional[SPARQLSummaryReport] = SPARQLSummaryReport()
    shacl_summary: Optional[SHACLSummaryReport] = SHACLSummaryReport()


class ValidationSummaryReport(ValidationManifestation):
    notices: Optional[List[ReportNoticeData]] = []
    xml_manifestation: Optional[XMLManifestationValidationSummaryReport] = XMLManifestationValidationSummaryReport()
    rdf_manifestation: Optional[RDFManifestationValidationSummaryReport] = RDFManifestationValidationSummaryReport()
    distilled_rdf_manifestation: Optional[
        RDFManifestationValidationSummaryReport] = RDFManifestationValidationSummaryReport()


class XMLValidationManifestation(ValidationManifestation):
    """

    """
    mapping_suite_identifier: str


class XPATHCoverageValidationAssertion(PropertyBaseModel):
    """

    """
    form_field: Optional[str]
    xpath: Optional[str]
    count: Optional[int]
    notice_hit: Optional[Dict[str, int]]
    query_result: Optional[bool]


class XPATHCoverageValidationResultBase(PropertyBaseModel):
    """

    """
    xpath_assertions: Optional[List[XPATHCoverageValidationAssertion]] = []
    xpath_covered: Optional[List[str]] = []


class XPATHCoverageValidationResult(XPATHCoverageValidationResultBase):
    """
    XPATHCoverageValidationResult for Notice
    """
    notices: Optional[List[ReportNoticeData]]


class XPATHCoverageValidationReport(XMLValidationManifestation):
    """
    This is the model structure for Notice(s) XPATHs Coverage Report
    """

    validation_result: Optional[XPATHCoverageValidationResult]


class XMLManifestation(Manifestation):
    """
        Original XML Notice manifestation as published on the TED website.
    """
    xpath_coverage_validation: XPATHCoverageValidationReport = None

    def add_validation(self, validation: Union[XPATHCoverageValidationReport]):
        if type(validation) == XPATHCoverageValidationReport:
            self.xpath_coverage_validation: XPATHCoverageValidationReport = validation

    def is_validated(self) -> bool:
        if self.xpath_coverage_validation:
            return True
        return False


class METSManifestation(Manifestation):
    """

    """
    type: str = METS_TYPE_CREATE
    package_name: str = None


class RDFValidationManifestation(ValidationManifestation):
    """
        The RDF validation report

    """
    mapping_suite_identifier: str
    test_suite_identifier: Optional[str]


class SPARQLQuery(PropertyBaseModel):
    """
    Stores SPARQL query details
    """
    title: Optional[str]
    description: Optional[str]
    xpath: Optional[List[str]] = []
    query: str


class SPARQLQueryResult(PropertyBaseModel):
    """
    Stores SPARQL query execution result
    """
    query: SPARQLQuery
    result: Optional[SPARQLQueryRefinedResultType]
    query_result: Optional[str]
    fields_covered: Optional[bool] = True
    missing_fields: Optional[List[str]] = []
    error: Optional[str]
    message: Optional[str]
    identifier: Optional[str]

    class Config:
        use_enum_values = True


class SPARQLTestSuiteValidationReport(RDFValidationManifestation):
    """
    Stores execution results for a SPARQL test suite
    """
    validation_results: Union[List[SPARQLQueryResult], str]


class QueriedSHACLShapeValidationResult(PropertyBaseModel):
    """
    Queried SHACL Validation Report which contains the following variables
    ?focusNode ?message ?resultPath ?resultSeverity ?sourceConstraintComponent ?sourceShape ?value
    """
    conforms: Optional[str]
    results_dict: Optional[dict]
    error: Optional[str]
    identifier: Optional[str]


class SHACLTestSuiteValidationReport(RDFValidationManifestation):
    """
    This is validation report for a SHACL test suite that contains json and html representation
    """
    validation_results: Union[QueriedSHACLShapeValidationResult, str]


class EntityDeduplicationReport(Manifestation):
    object_data: Optional[str]
    number_of_duplicates: int
    number_of_cets: int
    uries: List[str]


class RDFManifestation(Manifestation):
    """
        Transformed manifestation in RDF format
    """
    mapping_suite_id = "unknown_mapping_suite_id"
    shacl_validations: List[SHACLTestSuiteValidationReport] = []
    sparql_validations: List[SPARQLTestSuiteValidationReport] = []
    deduplication_report: Optional[EntityDeduplicationReport]

    def validation_exists(self, validation, validations):
        """
        Checks if a a [shacl|sparql] validation was already performed and exists in saved validations
        :param validation:
        :param validations:
        :return:
        """
        return next(filter(
            (lambda record: record.mapping_suite_identifier == validation.mapping_suite_identifier and
                            record.test_suite_identifier == validation.test_suite_identifier),
            validations
        ), None)

    def add_validation(self, validation: Union[SPARQLTestSuiteValidationReport, SHACLTestSuiteValidationReport]):
        if type(validation) == SHACLTestSuiteValidationReport:
            shacl_validation: SHACLTestSuiteValidationReport = validation
            if not self.validation_exists(shacl_validation, self.shacl_validations):
                self.shacl_validations.append(shacl_validation)
        elif type(validation) == SPARQLTestSuiteValidationReport:
            sparql_validation: SPARQLTestSuiteValidationReport = validation
            if not self.validation_exists(sparql_validation, self.sparql_validations):
                self.sparql_validations.append(sparql_validation)

    def is_validated(self) -> bool:
        if len(self.shacl_validations) and len(self.sparql_validations):
            return True
        return False
