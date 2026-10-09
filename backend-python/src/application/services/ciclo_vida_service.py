"""Servicios de aplicación para CU020/021/024-028/031/032 — Ciclo de Vida."""
from domain.exceptions.ciclo_vida_exceptions import CompradorError, OrdenError
from domain.ports.ciclo_vida_repository_port import CicloVidaRepositoryPort
from application.dto.lote_d_dto import CrearOrdenDTO, RecuperacionPagoDTO


class OrdenesLifecycleService:
    """CU021 — Recuperación de pago fallido / CU024 — Recompra rápida."""

    def __init__(self, repo: CicloVidaRepositoryPort) -> None:
        self._repo = repo

    def listar_mis_ordenes(self) -> list[dict]:
        return self._repo.listar_mis_ordenes()

    def listar_ordenes_por_recibir(self) -> list[dict]:
        return self._repo.listar_ordenes_por_recibir()

    def crear_orden(self, dto: CrearOrdenDTO) -> dict:
        if not dto.items:
            raise OrdenError("items no puede estar vacío")
        return self._repo.crear_orden_compra(dto.items, dto.moneda)

    def recuperar_pago_fallido(self, dto: RecuperacionPagoDTO) -> dict:
        """CU021 — Registra ubicación del comprador para recuperación de pago fallido."""
        if not (-90 <= dto.latitud <= 90):
            raise OrdenError("latitud fuera de rango [-90, 90]")
        if not (-180 <= dto.longitud <= 180):
            raise OrdenError("longitud fuera de rango [-180, 180]")
        return self._repo.recuperar_pago_fallido(dto.latitud, dto.longitud)


class CompradorLifecycleService:
    """CU026 — Reactivación de comprador inactivo / CU031 — Progresión fidelidad."""

    def __init__(self, repo: CicloVidaRepositoryPort) -> None:
        self._repo = repo

    def listar_compradores_activos(self) -> list[dict]:
        return self._repo.listar_compradores_activos()

    def listar_canjes_puntos(self) -> list[dict]:
        return self._repo.listar_canjes_puntos()

    def listar_beneficios_catalogo(self) -> list[dict]:
        return self._repo.listar_beneficios_catalogo()


class OfertaLifecycleService:
    """CU020 (catálogo), CU025 (lista espera), CU027 (referidos), CU028 (campañas), CU032 (reposición)."""

    def __init__(self, repo: CicloVidaRepositoryPort) -> None:
        self._repo = repo

    def listar_mis_productos(self) -> list[dict]:
        return self._repo.listar_mis_productos()

    def listar_catalogo_activo(self) -> list[dict]:
        return self._repo.listar_v_catalogo_activo()

    def listar_metricas(self) -> list[dict]:
        return self._repo.listar_metricas()

    def obtener_resumen_admin(self, payload: dict = None) -> dict:
        return self._repo.obtener_resumen_admin(payload or {})


class CampaniasVendedorService:
    """CU028 — Campañas segmentadas del vendedor con medición de conversión."""

    def __init__(self, repo: CicloVidaRepositoryPort) -> None:
        self._repo = repo

    def crear_campania(self, nombre: str, tipo_incentivo: str = "descuento_porcentaje",
                       valor_incentivo: float = 0.0, segmento_objetivo: dict | None = None,
                       descripcion: str | None = None) -> dict:
        """CU028 — Crear campaña en estado BORRADOR."""
        from domain.exceptions.ciclo_vida_exceptions import CicloVidaError
        if not nombre or not nombre.strip():
            raise CicloVidaError("nombre de campaña es requerido")
        payload = {
            "p_nombre": nombre,
            "p_tipo_incentivo": tipo_incentivo,
            "p_valor_incentivo": valor_incentivo,
            "p_segmento_objetivo": segmento_objetivo or {},
        }
        if descripcion:
            payload["p_descripcion"] = descripcion
        return self._repo.crear_campania_vendedor(payload)

    def activar_campania(self, campania_id) -> dict:
        """CU028 — Activar campaña BORRADOR → ACTIVA."""
        from domain.exceptions.ciclo_vida_exceptions import CicloVidaError
        if not campania_id:
            raise CicloVidaError("campania_id es requerido")
        return self._repo.activar_campania_vendedor(campania_id)

    def registrar_evento(self, campania_id, tipo_evento: str, metadata: dict | None = None) -> dict:
        """CU028 — Registrar evento de conversión/visualización en campaña."""
        from domain.exceptions.ciclo_vida_exceptions import CicloVidaError
        if not campania_id:
            raise CicloVidaError("campania_id es requerido")
        if not tipo_evento:
            raise CicloVidaError("tipo_evento es requerido")
        return self._repo.registrar_evento_campania(campania_id, tipo_evento, metadata)

    def metricas_campania(self, campania_id) -> dict:
        """CU028 — Consultar métricas de conversión de una campaña."""
        from domain.exceptions.ciclo_vida_exceptions import CicloVidaError
        if not campania_id:
            raise CicloVidaError("campania_id es requerido")
        return self._repo.metricas_campania(campania_id)

    def listar_campanias(self) -> list[dict]:
        """CU028 — Listar campañas del vendedor autenticado."""
        return self._repo.listar_campanias_vendedor()
