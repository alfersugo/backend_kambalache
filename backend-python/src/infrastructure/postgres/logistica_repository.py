"""Repositorio PostgREST para CU056/057/058/059 — Logística e Inventario."""
from uuid import UUID

import requests

from domain.exceptions.auth_exceptions import TokenExpiradoError
from domain.exceptions.logistica_exceptions import (
    DemandaError,
    GeoDespachoError,
    InventarioError,
    SafetyStockError,
)
from domain.ports.logistica_repository_port import LogisticaRepositoryPort
from infrastructure.postgres.base_repository import BasePostgRESTRepository


# Hereda _headers(), _unwrap(), _unwrap_list(), _call_rpc() de BasePostgRESTRepository
class PostgRESTLogisticaRepository(BasePostgRESTRepository, LogisticaRepositoryPort):

    # ── CU057 — Logística PostGIS ────────────────────────────────────────────

    def buscar_productos_geo(
        self,
        search: str | None,
        latitud: float | None,
        longitud: float | None,
        radio_km: float | None,
        limit: int,
        offset: int,
    ) -> list[dict]:
        body: dict = {"p_limit": limit, "p_offset": offset}
        if search is not None:
            body["p_search"] = search
        if latitud is not None:
            body["p_latitud"] = latitud
        if longitud is not None:
            body["p_longitud"] = longitud
        if radio_km is not None:
            body["p_radio_km"] = radio_km
        resp = requests.post(
            f"{self._base}/rpc/search_products_text_geo",
            json=body,
            headers=self._headers(),
            timeout=self._timeout,
        )
        if resp.status_code == 403:
            raise GeoDespachoError("No autorizado para buscar productos geo")
        if resp.status_code == 401:
            raise TokenExpiradoError("Sesión expirada o token inválido")
        if not resp.ok:
            raise GeoDespachoError(
                f"search_products_text_geo falló ({resp.status_code}): {resp.text}"
            )
        data = resp.json()
        return data if isinstance(data, list) else ([data] if data else [])

    def listar_articulos_cercanos(self) -> list[dict]:
        resp = requests.get(
            f"{self._base}/v_articulos_cercanos",
            params={"limit": "50"},
            headers=self._headers(),
            timeout=self._timeout,
        )
        if resp.status_code == 401:
            raise TokenExpiradoError("Sesión expirada o token inválido")
        if not resp.ok:
            raise GeoDespachoError(
                f"GET /v_articulos_cercanos falló ({resp.status_code}): {resp.text}"
            )
        data = resp.json()
        return data if isinstance(data, list) else [data]

    def registrar_ubicacion_usuario(self, latitud: float, longitud: float) -> dict:
        body = {"p_latitud": latitud, "p_longitud": longitud}
        resp = requests.post(
            f"{self._base}/rpc/registrar_ubicacion_usuario",
            json=body,
            headers=self._headers(),
            timeout=self._timeout,
        )
        if resp.status_code == 403:
            raise GeoDespachoError("No autorizado para registrar ubicación")
        if resp.status_code == 401:
            raise TokenExpiradoError("Sesión expirada o token inválido")
        if not resp.ok:
            raise GeoDespachoError(
                f"registrar_ubicacion_usuario falló ({resp.status_code}): {resp.text}"
            )
        data = resp.json()
        if isinstance(data, list):
            return data[0] if data else {}
        return data or {}

    # CU057 — TSP routing optimization
    def calcular_ruta_despacho(
        self,
        puntos: list[dict],
        origen_lat: float | None = None,
        origen_lon: float | None = None,
    ) -> dict:
        body: dict = {"p_puntos": puntos}
        if origen_lat is not None:
            body["p_origen_lat"] = origen_lat
        if origen_lon is not None:
            body["p_origen_lon"] = origen_lon
        resp = requests.post(
            f"{self._base}/rpc/rpc_calcular_ruta_despacho",
            json=body,
            headers=self._headers(),
            timeout=self._timeout,
        )
        if resp.status_code == 401:
            raise TokenExpiradoError("Sesión expirada o token inválido")
        if not resp.ok:
            raise GeoDespachoError(
                f"rpc_calcular_ruta_despacho falló ({resp.status_code}): {resp.text}"
            )
        data = resp.json()
        return data[0] if isinstance(data, list) and data else data or {}

    # ── CU056 — Multi-almacén / Productos ────────────────────────────────────

    def listar_mis_productos(self) -> list[dict]:
        resp = requests.get(
            f"{self._base}/v_mis_productos",
            params={"limit": "50"},
            headers=self._headers(),
            timeout=self._timeout,
        )
        if resp.status_code == 401:
            raise TokenExpiradoError("Sesión expirada o token inválido")
        if not resp.ok:
            raise InventarioError(
                f"GET /v_mis_productos falló ({resp.status_code}): {resp.text}"
            )
        data = resp.json()
        return data if isinstance(data, list) else [data]

    def listar_catalogo_activo(self) -> list[dict]:
        resp = requests.get(
            f"{self._base}/v_catalogo_activo",
            params={"limit": "50"},
            headers=self._headers(),
            timeout=self._timeout,
        )
        if resp.status_code == 401:
            raise TokenExpiradoError("Sesión expirada o token inválido")
        if not resp.ok:
            raise InventarioError(
                f"GET /v_catalogo_activo falló ({resp.status_code}): {resp.text}"
            )
        data = resp.json()
        return data if isinstance(data, list) else [data]

    def actualizar_articulo(self, producto_id: UUID) -> dict:
        body = {"p_id": str(producto_id)}
        resp = requests.post(
            f"{self._base}/rpc/fn_actualizar_articulo",
            json=body,
            headers=self._headers(),
            timeout=self._timeout,
        )
        if resp.status_code == 403:
            raise InventarioError("No autorizado para actualizar artículo")
        if resp.status_code == 401:
            raise TokenExpiradoError("Sesión expirada o token inválido")
        if not resp.ok:
            raise InventarioError(
                f"fn_actualizar_articulo falló ({resp.status_code}): {resp.text}"
            )
        data = resp.json()
        if isinstance(data, list):
            return data[0] if data else {}
        return data or {}

    # ── CU058 — Predicción de demanda ─────────────────────────────────────────

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
            raise DemandaError(f"GET /metricas falló ({resp.status_code}): {resp.text}")
        data = resp.json()
        return data if isinstance(data, list) else [data]

    def obtener_reportes_estadisticos(self) -> list[dict]:
        resp = requests.get(
            f"{self._base}/reportes_estadisticos",
            params={"limit": "50"},
            headers=self._headers(),
            timeout=self._timeout,
        )
        if resp.status_code == 401:
            raise TokenExpiradoError("Sesión expirada o token inválido")
        if not resp.ok:
            raise DemandaError(
                f"GET /reportes_estadisticos falló ({resp.status_code}): {resp.text}"
            )
        data = resp.json()
        return data if isinstance(data, list) else [data]

    def refrescar_reportes_estadisticos(self) -> dict:
        resp = requests.post(
            f"{self._base}/rpc/fn_reportes_estadisticos_refresh",
            json={},
            headers=self._headers(),
            timeout=self._timeout,
        )
        if resp.status_code == 403:
            raise DemandaError("No autorizado para refrescar reportes (requiere db_admin)")
        if resp.status_code == 401:
            raise TokenExpiradoError("Sesión expirada o token inválido")
        if not resp.ok:
            raise DemandaError(
                f"fn_reportes_estadisticos_refresh falló ({resp.status_code}): {resp.text}"
            )
        if resp.status_code == 204 or not resp.content:
            return {"status": "refreshed"}
        data = resp.json()
        if isinstance(data, list):
            return data[0] if data else {}
        return data or {}

    # ── CU059 — Safety stock / Riesgo inventario ─────────────────────────────

    def listar_inventario_riesgo(self) -> list[dict]:
        resp = requests.get(
            f"{self._base}/vw_inventario_riesgo",
            params={"limit": "50"},
            headers=self._headers(),
            timeout=self._timeout,
        )
        if resp.status_code == 401:
            raise TokenExpiradoError("Sesión expirada o token inválido")
        if not resp.ok:
            raise SafetyStockError(
                f"GET /vw_inventario_riesgo falló ({resp.status_code}): {resp.text}"
            )
        data = resp.json()
        return data if isinstance(data, list) else [data]
