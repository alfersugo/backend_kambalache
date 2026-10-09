#!/usr/bin/env python3
import os
import sys
import time

import psycopg2
from psycopg2 import InterfaceError, OperationalError

PROJECT_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", "..", ".."))
BACKEND_DIR = os.path.join(PROJECT_ROOT, "backend")
SRC_DIR = os.path.join(BACKEND_DIR, "src")
if SRC_DIR not in sys.path:
    sys.path.insert(0, SRC_DIR)

from application.services.mail_queue_service import MailQueueService
from infrastructure.config.env_loader import load_env
from infrastructure.mail.local_mail_sender import LocalMailSender
from infrastructure.postgres.mail_queue_repository import PsycopgMailQueueRepository


def log(msg, level="INFO"):
    print(f"[{level}] {msg}")


def build_db_url():
    db_url = os.getenv("DB_URL")
    if db_url:
        return db_url

    db_host = os.getenv("DB_HOST", "localhost")
    db_port = os.getenv("DB_PORT", "5432")
    db_name = os.getenv("DB_NAME", "kambalache")
    db_user = os.getenv("DB_USER", "postgres")
    db_pass = os.getenv("DB_PASS", "postgres")
    return f"postgres://{db_user}:{db_pass}@{db_host}:{db_port}/{db_name}"


def get_connection():
    db_url = build_db_url()
    if not db_url:
        raise RuntimeError("DB_URL not set")
    connect_timeout = int(os.getenv("DB_CONNECT_TIMEOUT", "5"))
    return psycopg2.connect(db_url, connect_timeout=connect_timeout)


def create_service(connection):
    repository = PsycopgMailQueueRepository(connection)
    sender = LocalMailSender()
    return MailQueueService(repository, sender)


def close_connection(connection):
    if connection is None:
        return
    try:
        connection.close()
    except Exception:
        pass


def connect_with_retry(retry_delay_seconds):
    while True:
        try:
            connection = get_connection()
            log("Database connection ready")
            return connection
        except OperationalError as exc:
            log(f"Database not ready yet: {exc}", level="WARN")
            time.sleep(retry_delay_seconds)


def main():
    env_path = os.path.join(PROJECT_ROOT, ".env")
    load_env(env_path)
    poll_interval_seconds = int(os.getenv("MAIL_WORKER_POLL_INTERVAL", "5"))
    reconnect_delay_seconds = int(os.getenv("MAIL_WORKER_RECONNECT_DELAY", "5"))
    conn = None
    service = None

    log("Mail worker started")
    while True:
        try:
            if service is None:
                conn = connect_with_retry(reconnect_delay_seconds)
                service = create_service(conn)

            result = service.process_pending(limit=10)
            if result["processed"] > 0:
                log(f"Processed {result['processed']} queued mails")
            if result["errors"] > 0:
                log(f"Failed to process {result['errors']} mails", level="ERROR")
            time.sleep(poll_interval_seconds)
        except (OperationalError, InterfaceError) as exc:
            log(f"Database connection lost; reconnecting: {exc}", level="WARN")
            close_connection(conn)
            conn = None
            service = None
            time.sleep(reconnect_delay_seconds)


if __name__ == "__main__":
    main()
