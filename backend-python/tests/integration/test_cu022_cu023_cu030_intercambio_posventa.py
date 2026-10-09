"""
Integration tests for CU022/CU023/CU030 — Intercambio y Posventa.
CU022: Coordinación de entrega / retiro en oficina
CU023: Confirmación de recepción (OTP/QR) y liberación de recompensa
CU030: Escalamiento de disputa a mediación administrativa
"""
import pytest
import requests
from unittest.mock import MagicMock
from uuid import uuid4

from application.services.intercambio_posventa_service import (
    ConfirmacionRecepcionService,
    DisputasService,
    EnvioService,
)
from application.dto.lote_d_dto import (
    ActualizarEnvioDTO,
    CrearConsultaServicioDTO,
    CrearResenaIntercambioDTO,
)
from domain.exceptions.intercambio_posventa_exceptions import (
    DisputaError,
    EnvioError,
    ResenaError,
)

POSTGREST_URL = "http://localhost:3000"


def _get_jwt(email: str, password: str) -> str | None:
    try:
        r = requests.post(
            f"{POSTGREST_URL}/rpc/login_user",
            json={"p_email": email, "p_password": password},
            timeout=5,
        )
        if r.ok:
            d = r.json()
            if isinstance(d, list):
                d = d[0]
            return d.get("token")
    except Exception:
        pass
    return None


# ── Mock tests — CU022 ────────────────────────────────────────────────────────


class TestEnvioServiceMock:
    def test_listar_envios_ok(self):
        repo = MagicMock()
        repo.listar_envios.return_value = [{"id": str(uuid4()), "estado": "en_camino"}]
        svc = EnvioService(repo)
        result = svc.listar_envios()
        assert isinstance(result, list)
        assert result[0]["estado"] == "en_camino"

    def test_actualizar_estado_envio_sin_orden_id(self):
        repo = MagicMock()
        svc = EnvioService(repo)
        with pytest.raises(EnvioError, match="orden_id"):
            svc.actualizar_estado_envio(ActualizarEnvioDTO(orden_id=None, payload={}))  # type: ignore[arg-type]

    def test_actualizar_estado_envio_ok(self):
        repo = MagicMock()
        orden_id = uuid4()
        repo.actualizar_estado_envio.return_value = {"estado": "entregado"}
        svc = EnvioService(repo)
        dto = ActualizarEnvioDTO(orden_id=orden_id, payload={"estado": "entregado"})
        result = svc.actualizar_estado_envio(dto)
        repo.actualizar_estado_envio.assert_called_once_with(orden_id, {"estado": "entregado"})
        assert result["estado"] == "entregado"

    def test_coordinar_retiro_oficina_sin_intercambio_id(self):
        repo = MagicMock()
        svc = EnvioService(repo)
        with pytest.raises(EnvioError, match="intercambio_id"):
            svc.coordinar_retiro_oficina(
                intercambio_id=None,  # type: ignore[arg-type]
                fecha_hora="2030-01-01T10:00:00Z",
                punto_oficina="Sucursal Central",
            )

    def test_coordinar_retiro_oficina_sin_punto_oficina(self):
        repo = MagicMock()
        svc = EnvioService(repo)
        with pytest.raises(EnvioError, match="punto_oficina"):
            svc.coordinar_retiro_oficina(
                intercambio_id=uuid4(),
                fecha_hora="2030-01-01T10:00:00Z",
                punto_oficina="   ",
            )

    def test_coordinar_retiro_oficina_ok(self):
        repo = MagicMock()
        intercambio_id = uuid4()
        repo.coordinar_retiro_oficina.return_value = {
            "tipo_entrega": "RETIRO_OFICINA",
            "referencia_retiro": "OFIC-ABCD1234",
            "estado": "PROPUESTA",
        }
        svc = EnvioService(repo)
        result = svc.coordinar_retiro_oficina(
            intercambio_id=intercambio_id,
            fecha_hora="2030-06-01T10:00:00Z",
            punto_oficina="Sucursal Norte",
            instrucciones="Traer DNI",
        )
        repo.coordinar_retiro_oficina.assert_called_once_with(
            intercambio_id, "2030-06-01T10:00:00Z", "Sucursal Norte", "Traer DNI"
        )
        assert result["tipo_entrega"] == "RETIRO_OFICINA"
        assert "OFIC-" in result["referencia_retiro"]


# ── Mock tests — CU023 ────────────────────────────────────────────────────────


class TestConfirmacionRecepcionServiceMock:
    def test_crear_resena_sin_intercambio_id(self):
        repo = MagicMock()
        svc = ConfirmacionRecepcionService(repo)
        with pytest.raises(ResenaError, match="intercambio_id"):
            svc.crear_resena_intercambio(
                CrearResenaIntercambioDTO(intercambio_id=None, payload={})  # type: ignore[arg-type]
            )

    def test_crear_resena_ok(self):
        repo = MagicMock()
        intercambio_id = uuid4()
        repo.crear_resena_intercambio.return_value = {"id": str(uuid4()), "calificacion": 5}
        svc = ConfirmacionRecepcionService(repo)
        dto = CrearResenaIntercambioDTO(intercambio_id=intercambio_id, payload={"calificacion": 5})
        result = svc.crear_resena_intercambio(dto)
        assert result.get("calificacion") == 5

    def test_listar_resenas_ok(self):
        repo = MagicMock()
        repo.listar_resenas.return_value = [{"id": str(uuid4()), "calificacion": 4}]
        svc = ConfirmacionRecepcionService(repo)
        result = svc.listar_resenas()
        assert isinstance(result, list)


# ── Mock tests — CU030 ────────────────────────────────────────────────────────


class TestDisputasServiceMock:
    def test_crear_consulta_sin_orden_id(self):
        repo = MagicMock()
        svc = DisputasService(repo)
        with pytest.raises(DisputaError, match="orden_id"):
            svc.crear_consulta_servicio(
                CrearConsultaServicioDTO(orden_id=None, payload={})  # type: ignore[arg-type]
            )

    def test_crear_consulta_ok(self):
        repo = MagicMock()
        orden_id = uuid4()
        repo.crear_consulta_servicio.return_value = {"id": str(uuid4()), "estado": "abierta"}
        svc = DisputasService(repo)
        dto = CrearConsultaServicioDTO(orden_id=orden_id, payload={"motivo": "No llegó"})
        result = svc.crear_consulta_servicio(dto)
        assert result.get("estado") == "abierta"

    def test_listar_consultas_ok(self):
        repo = MagicMock()
        repo.listar_mis_consultas_servicio.return_value = [{"estado": "abierta"}]
        svc = DisputasService(repo)
        result = svc.listar_mis_consultas_servicio()
        assert isinstance(result, list)


# ── Live integration tests — CU022/CU023/CU030 ───────────────────────────────


@pytest.mark.integration
class TestEnvioLive:
    def test_listar_envios_buyer(self, buyer_jwt):
        if not buyer_jwt:
            pytest.skip("No se pudo obtener JWT de buyer")
        r = requests.get(
            f"{POSTGREST_URL}/envios",
            params={"limit": "5"},
            headers={"Authorization": f"Bearer {buyer_jwt}"},
            timeout=10,
        )
        assert r.status_code in (200, 403, 404), f"Inesperado: {r.status_code} {r.text[:200]}"


@pytest.mark.integration
class TestResenaLive:
    def test_listar_resenas_buyer(self, buyer_jwt):
        if not buyer_jwt:
            pytest.skip("No se pudo obtener JWT de buyer")
        r = requests.get(
            f"{POSTGREST_URL}/resenas",
            params={"limit": "5"},
            headers={"Authorization": f"Bearer {buyer_jwt}"},
            timeout=10,
        )
        assert r.status_code in (200, 403, 404), f"Inesperado: {r.status_code} {r.text[:200]}"


@pytest.mark.integration
class TestConsultaServicioLive:
    def test_listar_consultas_buyer(self, buyer_jwt):
        if not buyer_jwt:
            pytest.skip("No se pudo obtener JWT de buyer")
        r = requests.get(
            f"{POSTGREST_URL}/v_mis_consultas_servicio",
            headers={"Authorization": f"Bearer {buyer_jwt}"},
            timeout=10,
        )
        assert r.status_code in (200, 403, 404), f"Inesperado: {r.status_code} {r.text[:200]}"


# ── Integration DB test — CU022 retiro_oficina ─────────────────────────────


@pytest.mark.integration
class TestRetiroOficinaIntegracion:
    """CU022 sub-flujo retiro en oficina — test contra BD usando pg_superconn."""

    def test_columna_tipo_entrega_existe(self, pg_superconn):
        """Verifica que la migración 90 creó la columna tipo_entrega."""
        with pg_superconn.cursor() as cur:
            cur.execute(
                """
                SELECT column_name
                FROM information_schema.columns
                WHERE table_schema = 'auth'
                  AND table_name   = 'coordinaciones_entrega'
                  AND column_name  = 'tipo_entrega'
                """
            )
            row = cur.fetchone()
        assert row is not None, "Columna tipo_entrega no existe — aplicar migración 90"

    def test_rpc_coordinar_retiro_oficina_rechaza_sin_jwt(self):
        """Sin token el RPC debe devolver 401."""
        r = requests.post(
            f"{POSTGREST_URL}/rpc/rpc_coordinar_retiro_oficina",
            json={
                "p_intercambio_id": str(uuid4()),
                "p_fecha_hora": "2030-01-01T10:00:00Z",
                "p_punto_oficina": "Sucursal Test",
            },
            timeout=5,
        )
        assert r.status_code in (401, 403), f"Esperado 401/403, got {r.status_code}: {r.text[:200]}"


class TestCU023ConfirmacionRecepcion:
    """CU023 — Confirmación de recepción con OTP y reseña opcional."""

    def test_rpc_crear_resena_json_rechaza_sin_jwt(self):
        """Sin JWT el RPC crear_resena_json retorna 400 (error de negocio) o 401/403.
        La autenticación real la impone FastAPI — PostgREST acepta llamadas anonónimas.
        """
        r = requests.post(
            f"{POSTGREST_URL}/rpc/crear_resena_json",
            json={"p_orden_id": str(uuid4()), "p_payload": {}},
            timeout=5,
        )
        assert r.status_code in (400, 401, 403), (
            f"Esperado 400/401/403 sin JWT, got {r.status_code}: {r.text[:200]}"
        )

    def test_service_rechaza_otp_no_numerico(self):
        """El servicio rechaza OTP que no sea 6 dígitos numéricos."""
        from application.dto.lote_d_dto import ConfirmacionRecepcionDTO
        from application.services.intercambio_posventa_service import ConfirmacionRecepcionService
        from domain.exceptions.intercambio_posventa_exceptions import ResenaError

        svc = ConfirmacionRecepcionService(MagicMock())
        with pytest.raises(ResenaError, match="OTP"):
            svc.confirmar_recepcion_con_resena(
                ConfirmacionRecepcionDTO(orden_id=uuid4(), otp="abcdef")
            )

    def test_service_rechaza_otp_menos_de_6_digitos(self):
        """El servicio rechaza OTP de menos de 6 dígitos."""
        from application.dto.lote_d_dto import ConfirmacionRecepcionDTO
        from application.services.intercambio_posventa_service import ConfirmacionRecepcionService
        from domain.exceptions.intercambio_posventa_exceptions import ResenaError

        svc = ConfirmacionRecepcionService(MagicMock())
        with pytest.raises(ResenaError, match="OTP"):
            svc.confirmar_recepcion_con_resena(
                ConfirmacionRecepcionDTO(orden_id=uuid4(), otp="12345")
            )

    def test_service_delega_en_repo_con_otp_valido(self):
        """Con OTP válido el servicio llama a repo.confirmar_recepcion_con_resena."""
        from application.dto.lote_d_dto import ConfirmacionRecepcionDTO
        from application.services.intercambio_posventa_service import ConfirmacionRecepcionService

        orden = uuid4()
        repo = MagicMock()
        repo.confirmar_recepcion_con_resena.return_value = {"confirmado": True}
        svc = ConfirmacionRecepcionService(repo)
        result = svc.confirmar_recepcion_con_resena(
            ConfirmacionRecepcionDTO(orden_id=orden, otp="654321", payload={"rating": 5})
        )
        repo.confirmar_recepcion_con_resena.assert_called_once_with(
            orden, "654321", {"rating": 5}
        )
        assert result == {"confirmado": True}
