from datetime import datetime, timedelta
from typing import List


def notice_fetcher_by_date_pipeline(date_wild_card: str = None) -> List[str]:
    from pymongo import MongoClient
    from ted_sws import config
    from ted_sws.data_manager.adapters.notice_repository import NoticeRepository
    from ted_sws.notice_fetcher.adapters.ted_api import TedAPIAdapter, TedRequestAPI
    from ted_sws.notice_fetcher.services.notice_fetcher import NoticeFetcher
    from ted_sws.supra_notice_manager.services.daily_supra_notice_manager import \
        create_and_store_in_mongo_db_daily_supra_notice
    from ted_sws.event_manager.services.log import log_error
    notice_ids = None
    try:
        date_wild_card = date_wild_card if date_wild_card else (datetime.now() - timedelta(days=1)).strftime("%Y%m%d*")
        notice_publication_date = datetime.strptime(date_wild_card, "%Y%m%d*").date()
        mongodb_client = MongoClient(config.MONGO_DB_AUTH_URL)
        notice_ids = NoticeFetcher(notice_repository=NoticeRepository(mongodb_client=mongodb_client),
                                   ted_api_adapter=TedAPIAdapter(
                                       request_api=TedRequestAPI())).fetch_notices_by_date_wild_card(
            wildcard_date=date_wild_card)
        create_and_store_in_mongo_db_daily_supra_notice(notice_ids=notice_ids, mongodb_client=mongodb_client,
                                                        ted_publication_date=notice_publication_date)
    except Exception as error:
        log_error(message=str(error))

    return notice_ids


def notice_fetcher_by_query_pipeline(query: str = None) -> List[str]:
    from pymongo import MongoClient
    from ted_sws import config
    from ted_sws.data_manager.adapters.notice_repository import NoticeRepository
    from ted_sws.notice_fetcher.adapters.ted_api import TedAPIAdapter, TedRequestAPI
    from ted_sws.notice_fetcher.services.notice_fetcher import NoticeFetcher
    from ted_sws.event_manager.services.log import log_error
    notice_ids = None
    try:
        ted_api_query = {"q": query}
        mongodb_client = MongoClient(config.MONGO_DB_AUTH_URL)
        notice_ids = NoticeFetcher(notice_repository=NoticeRepository(mongodb_client=mongodb_client),
                                   ted_api_adapter=TedAPIAdapter(
                                       request_api=TedRequestAPI())).fetch_notices_by_query(query=ted_api_query)
    except Exception as error:
        log_error(message=str(error))
    return notice_ids
