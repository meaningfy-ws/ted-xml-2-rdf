from pathlib import Path

from ted_sws.event_manager.adapters.event_handler import EventWriterToConsoleHandler, EventWriterToNullHandler
from ted_sws.event_manager.adapters.event_handler_config import DAGLoggerConfig, CLILoggerConfig, NullLoggerConfig, \
    ConsoleLoggerConfig, EventHandlerConfig


def test_event_handler_config(mongodb_client, event_logs_filepath, prime_config_handlers):
    logger_config = DAGLoggerConfig(mongodb_client=mongodb_client, filepath=event_logs_filepath,
                                    config_handlers=prime_config_handlers)
    assert logger_config.init_logger_name()
    assert logger_config.init_log_filepath()
    assert len(logger_config.get_handlers()) == 3

    console_handler = logger_config.get_console_handler()
    assert console_handler and isinstance(console_handler, EventWriterToConsoleHandler)

    logger_config = CLILoggerConfig(mongodb_client=mongodb_client, filepath=event_logs_filepath,
                                    config_handlers='')
    assert len(logger_config.get_prime_handlers()) == 3

    event_handler_config = EventHandlerConfig()

    null_handler: EventWriterToNullHandler = EventWriterToNullHandler(name="TEST_NULL_HANDLER")
    default_handlers = [null_handler]

    handlers, prime_handlers = event_handler_config._init_handlers(
        config_handlers=None,
        default_handlers=default_handlers,
        handlers=[],
        mongodb_client=mongodb_client,
        name="TEST",
        filepath=Path("")
    )

    assert handlers == default_handlers


def test_event_null_handler_config():
    logger_config = NullLoggerConfig()
    assert len(logger_config.get_handlers()) == 1
    assert isinstance(logger_config.get_handler(EventWriterToNullHandler), EventWriterToNullHandler)


def test_event_console_handler_config():
    logger_config = ConsoleLoggerConfig()
    assert len(logger_config.get_handlers()) == 1
    assert isinstance(logger_config.get_handler(EventWriterToConsoleHandler), EventWriterToConsoleHandler)
