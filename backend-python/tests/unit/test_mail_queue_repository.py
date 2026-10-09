"""
T11-SMTP-BRAIN: unit tests del repositorio SMTP contra el esquema REAL del espejo.

Verifica que PsycopgMailQueueRepository usa las columnas reales de auth.mail_queue
(estado/intentos/fecha_actualizacion via trigger) y NO las del stub en ingles
(status/updated_at) que crasheaban el mail-worker en produccion.
"""
import pytest

from infrastructure.postgres.mail_queue_repository import PsycopgMailQueueRepository


class FakeCursor:
    def __init__(self):
        self.executed = []
        self.results = []

    def execute(self, sql, params=None):
        self.executed.append((sql, params))

    def fetchall(self):
        return self.results

    def __enter__(self):
        return self

    def __exit__(self, *args):
        return False


class FakeConnection:
    def __init__(self, results=None):
        self.cursor_obj = FakeCursor()
        self.cursor_obj.results = results or []
        self.commits = 0

    def cursor(self):
        return self.cursor_obj

    def commit(self):
        self.commits += 1


class TestPsycopgMailQueueRepository:
    def test_fetch_pending_usa_estado_real(self):
        conn = FakeConnection(results=[(1, "buyer@kambalache.com", "Test", "body")])
        repo = PsycopgMailQueueRepository(conn)
        items = repo.fetch_pending(limit=5)
        sql = conn.cursor_obj.executed[0][0]
        assert "estado='pendiente'" in sql
        assert "status" not in sql
        assert len(items) == 1
        assert items[0].id == 1
        assert items[0].recipient == "buyer@kambalache.com"

    def test_mark_sent_usa_enviado_sin_updated_at(self):
        conn = FakeConnection()
        repo = PsycopgMailQueueRepository(conn)
        repo.mark_sent(7)
        sql = conn.cursor_obj.executed[0][0]
        assert "estado='enviado'" in sql
        assert "updated_at" not in sql
        assert "status" not in sql

    def test_mark_error_usa_fallido_e_incrementa_intentos(self):
        conn = FakeConnection()
        repo = PsycopgMailQueueRepository(conn)
        repo.mark_error(9)
        sql = conn.cursor_obj.executed[0][0]
        assert "estado='fallido'" in sql
        assert "intentos=intentos+1" in sql
        # 'error' no existe en el CHECK real: pendiente|enviado|fallido|cancelado
        assert "'error'" not in sql

    def test_commit_propaga(self):
        conn = FakeConnection()
        repo = PsycopgMailQueueRepository(conn)
        repo.commit()
        assert conn.commits == 1
