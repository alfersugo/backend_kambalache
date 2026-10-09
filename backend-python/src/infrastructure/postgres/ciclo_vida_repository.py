"""Repositorio PostgREST para CU020/021/024-028/031/032 — Ciclo de Vida."""
import requests

from domain.exceptions.auth_exceptions import TokenExpiradoError
from domain.exceptions.ciclo_vida_exceptions import CompradorError, CicloVidaError, OrdenError
from domain.ports.ciclo_vida_repository_port import CicloVidaRepositoryPort
from infrastructure.postgres.base_repository import BasePostgRESTRepository


# Hereda _headers(), _unwrap(), _unwrap_list(), _call_rpc() de BasePostgRESTRepository
class PostgRESTCicloVidaRepository(BasePostgRESTRepository, CicloVidaRepositoryPort):

    def listar_mis_ordenes(self) -> list[dict]:
        resp = requests.get(
            f"{self._base}/v_mis_ordenes",
            params={"order": "fecha_creacion.desc", "limit": "50"},
            headers=self._headers(),
            timeout=self._timeout,
        )
        if resp.status_code == 401:
            raise TokenExpiradoError("Sesión expirada o token inválido")
        if not resp.ok:
            raise OrdenError(f"GET /v_mis_ordenes falló ({resp.status_code}): {resp.text}")
        data = resp.json()
        return data if isinstance(data, list) else [data]

    def crear_orden_compra(self, items: list, moneda: str) -> dict:
        body = {"p_items": items, "p_moneda": moneda}
        resp = requests.post(
            f"{self._base}/rpc/crear_orden_compra",
            json=body,
            headers=self._headers(),
            timeout=self._timeout,
        )
        if resp.status_code == 403:
            raise OrdenError("No autorizado para crear orden")
        if resp.status_code == 401:
            raise TokenExpiradoError("Sesión expirada o token inválido")
        if not resp.ok:
            raise OrdenError(f"crear_orden_compra falló ({resp.status_code}): {resp.text}")
        data = resp.json()
        if isinstance(data, list):
            return data[0] if data else {}
        return data or {}

    def listar_ordenes_por_recibir(self) -> list[dict]:
        resp = requests.get(
            f"{self._base}/v_ordenes_por_recibir",
            params={"limit": "20"},
            headers=self._headers(),
            timeout=self._timeout,
        )
        if resp.status_code == 401:
            raise TokenExpiradoError("Sesión expirada o token inválido")
        if not resp.ok:
            raise OrdenError(
                f"GET /v_ordenes_por_recibir falló ({resp.status_code}): {resp.text}"
            )
        data = resp.json()
        return data if isinstance(data, list) else [data]

    def listar_compradores_activos(self) -> list[dict]:
        resp = requests.get(
            f"{self._base}/v_compradores_activos",
            params={"limit": "50"},
            headers=self._headers(),
            timeout=self._timeout,
        )
        if resp.status_code == 401:
            raise TokenExpiradoError("Sesión expirada o token inválido")
        if not resp.ok:
            raise CompradorError(
                f"GET /v_compradores_activos falló ({resp.status_code}): {resp.text}"
            )
        data = resp.json()
        return data if isinstance(data, list) else [data]

    def listar_canjes_puntos(self) -> list[dict]:
        resp = requests.get(
            f"{self._base}/canjes_puntos",
            params={"order": "fecha_canje.desc", "limit": "50"},
            headers=self._headers(),
            timeout=self._timeout,
        )
        if resp.status_code == 401:
            raise TokenExpiradoError("Sesión expirada o token inválido")
        if not resp.ok:
            raise CicloVidaError(
                f"GET /canjes_puntos falló ({resp.status_code}): {resp.text}"
            )
        data = resp.json()
        return data if isinstance(data, list) else [data]

    def listar_metricas(self) -> list[dict]:
        resp = requests.get(
            f"{self._base}/metricas",
            params={"limit": "50"},
            headers=self._headers(),
            timeout=self._timeout,
        )
        if resp.status_code == 401:
            raise TokenExpiradoError("Sesión expirada o token inválido")
        if not resp.ok:
            raise CicloVidaError(f"GET /metricas falló ({resp.status_code}): {resp.text}")
        data = resp.json()
        return data if isinstance(data, list) else [data]

    def listar_beneficios_catalogo(self) -> list[dict]:
        resp = requests.get(
            f"{self._base}/beneficios_catalogo",
            params={"activo": "eq.true", "limit": "50"},
            headers=self._headers(),
            timeout=self._timeout,
        )
        if resp.status_code == 401:
            raise TokenExpiradoError("Sesión expirada o token inválido")
        if not resp.ok:
            raise CicloVidaError(
                f"GET /beneficios_catalogo falló ({resp.status_code}): {resp.text}"
            )
        data = resp.json()
        return data if isinstance(data, list) else [data]

    def listar_mis_productos(self) -> list[dict]:
        resp = requests.get(
            f"{self._base}/productos",
            params={"limit": "50"},
            headers=self._headers(),
            timeout=self._timeout,
        )
        if resp.status_code == 401:
            raise TokenExpiradoError("Sesión expirada o token inválido")
        if not resp.ok:
            raise CicloVidaError(
                f"GET /productos falló ({resp.status_code}): {resp.text}"
            )
        data = resp.json()
        return data if isinstance(data, list) else [data]

    def listar_v_catalogo_activo(self) -> list[dict]:
        resp = requests.get(
            f"{self._base}/v_catalogo_activo",
            params={"limit": "50"},
            headers=self._headers(),
            timeout=self._timeout,
        )
        if resp.status_code == 401:
            raise TokenExpiradoError("Sesión expirada o token inválido")
        if not resp.ok:
            raise CicloVidaError(
                f"GET /v_catalogo_activo falló ({resp.status_code}): {resp.text}"
            )
        data = resp.json()
        return data if isinstance(data, list) else [data]

    def obtener_resumen_admin(self, payload: dict) -> dict:
        resp = requests.post(
            f"{self._base}/rpc/fn_admin_resumen_ejecutivo",
            json={"p_payload": payload},
            headers=self._headers(),
            timeout=self._timeout,
        )
        if resp.status_code == 403:
            raise CicloVidaError("No autorizado para resumen admin")
        if resp.status_code == 401:
            raise TokenExpiradoError("Sesión expirada o token inválido")
        if not resp.ok:
            raise CicloVidaError(
                f"fn_admin_resumen_ejecutivo falló ({resp.status_code}): {resp.text}"
            )
        data = resp.json()
        if isinstance(data, list):
            return data[0] if data else {}
        return data or {}

    # CU028 — campañas segmentadas del vendedor
    def crear_campania_vendedor(self, payload: dict) -> dict:
        resp = requests.post(
            f"{self._base}/rpc/rpc_crear_campania_vendedor",
            json=payload,
            headers=self._headers(),
            timeout=self._timeout,
        )
        if resp.status_code == 403:
            raise CicloVidaError("Solo vendedores pueden crear campañas")
        if resp.status_code == 401:
            raise TokenExpiradoError("Sesión expirada o token inválido")
        if not resp.ok:
            raise CicloVidaError(
                f"rpc_crear_campania_vendedor falló ({resp.status_code}): {resp.text}"
            )
        data = resp.json()
        return data[0] if isinstance(data, list) and data else data or {}

    def activar_campania_vendedor(self, campania_id) -> dict:
        from uuid import UUID
        resp = requests.post(
            f"{self._base}/rpc/rpc_activar_campania_vendedor",
            json={"p_campania_id": str(campania_id)},
            headers=self._headers(),
            timeout=self._timeout,
        )
        if resp.status_code == 403:
            raise CicloVidaError("No autorizado para activar esta campaña")
        if resp.status_code == 401:
            raise TokenExpiradoError("Sesión expirada o token inválido")
        if not resp.ok:
            raise CicloVidaError(
                f"rpc_activar_campania_vendedor falló ({resp.status_code}): {resp.text}"
            )
        data = resp.json()
        return data[0] if isinstance(data, list) and data else data or {}

    def registrar_evento_campania(self, campania_id, tipo_evento: str, metadata: dict | None) -> dict:
        body = {
            "p_campania_id": str(campania_id),
            "p_tipo_evento": tipo_evento,
        }
        if metadata:
            body["p_metadata"] = metadata
        resp = requests.post(
            f"{self._base}/rpc/rpc_registrar_evento_campania",
            json=body,
            headers=self._headers(),
            timeout=self._timeout,
        )
        if resp.status_code == 403:
            raise CicloVidaError("No autorizado para registrar evento")
        if resp.status_code == 401:
            raise TokenExpiradoError("Sesión expirada o token inválido")
        if not resp.ok:
            raise CicloVidaError(
                f"rpc_registrar_evento_campania falló ({resp.status_code}): {resp.text}"
            )
        data = resp.json()
        return data[0] if isinstance(data, list) and data else data or {}

    def metricas_campania(self, campania_id) -> dict:
        resp = requests.post(
            f"{self._base}/rpc/rpc_metricas_campania",
            json={"p_campania_id": str(campania_id)},
            headers=self._headers(),
            timeout=self._timeout,
        )
        if resp.status_code == 403:
            raise CicloVidaError("No tienes acceso a esta campaña")
        if resp.status_code == 401:
            raise TokenExpiradoError("Sesión expirada o token inválido")
        if not resp.ok:
            raise CicloVidaError(
                f"rpc_metricas_campania falló ({resp.status_code}): {resp.text}"
            )
        data = resp.json()
        return data[0] if isinstance(data, list) and data else data or {}

    def listar_campanias_vendedor(self) -> list[dict]:
        resp = requests.post(
            f"{self._base}/rpc/rpc_listar_campanias_vendedor",
            json={},
            headers=self._headers(),
            timeout=self._timeout,
        )
        if resp.status_code == 403:
            raise CicloVidaError("No autorizado para listar campañas")
        if resp.status_code == 401:
            raise TokenExpiradoError("Sesión expirada o token inválido")
        if not resp.ok:
            raise CicloVidaError(
                f"rpc_listar_campanias_vendedor falló ({resp.status_code}): {resp.text}"
            )
        data = resp.json()
        return data if isinstance(data, list) else [data]

    def recuperar_pago_fallido(self, latitud: float, longitud: float) -> dict:
        """CU021 — Registra ubicación del usuario para recuperación de pago fallido.

        RPC: registrar_ubicacion_usuario(p_latitud double precision, p_longitud double precision)
        Requiere rol buyer.
        """
        return self._call_rpc(
            "registrar_ubicacion_usuario",
            {"p_latitud": latitud, "p_longitud": longitud},
            CicloVidaError,
        )
