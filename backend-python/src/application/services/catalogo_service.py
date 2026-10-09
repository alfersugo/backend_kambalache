"""Servicio de aplicación para CU011 — Gestión de Catálogo de Productos."""
from uuid import UUID

from application.dto.catalogo_dto import (
    ActualizarFotoDTO,
    ActualizarProductoDTO,
    AgregarFotoDTO,
    CrearCategoriaDTO,
    CrearProductoDTO,
    CrearSubcategoriaDTO,
    EliminarFotoDTO,
    ReordenarFotosDTO,
)
from application.validators.catalogo_validator import CatalogoValidator
from domain.exceptions.catalogo_exceptions import CatalogoError
from domain.ports.catalogo_repository_port import CatalogoRepositoryPort


class CatalogoService:
    def __init__(self, repo: CatalogoRepositoryPort) -> None:
        self._repo = repo
        self._validator = CatalogoValidator()

    def listar_mis_productos(self) -> list[dict]:
        try:
            return self._repo.listar_mis_productos()
        except Exception as exc:
            raise CatalogoError(f"Error listando productos: {exc}") from exc

    def crear_categoria(self, dto: CrearCategoriaDTO) -> dict:
        self._validator.validar_categoria(dto)
        try:
            return self._repo.crear_categoria(
                nombre=dto.nombre.strip(),
                descripcion=dto.descripcion,
                id_tipo_producto=str(dto.id_tipo_producto) if dto.id_tipo_producto else None,
            )
        except Exception as exc:
            raise CatalogoError(f"Error creando categoría: {exc}") from exc

    def crear_subcategoria(self, dto: CrearSubcategoriaDTO) -> dict:
        self._validator.validar_subcategoria(dto)
        try:
            return self._repo.crear_subcategoria(
                id_categoria=dto.id_categoria,
                nombre=dto.nombre.strip(),
                descripcion=dto.descripcion,
            )
        except Exception as exc:
            raise CatalogoError(f"Error creando subcategoría: {exc}") from exc

    def crear_producto(self, dto: CrearProductoDTO) -> dict:
        self._validator.validar_producto_alta(dto)
        payload = {
            "id_categoria": str(dto.id_categoria),
            "id_subcategoria": str(dto.id_subcategoria) if dto.id_subcategoria else None,
            "nombre": dto.nombre.strip(),
            "descripcion": dto.descripcion,
            "precio": float(dto.precio),
            "descuento_porcentaje": float(dto.descuento_porcentaje),
            "puntos_recompensa": int(dto.puntos_recompensa),
        }
        try:
            return self._repo.crear_producto(payload)
        except Exception as exc:
            raise CatalogoError(f"Error creando producto: {exc}") from exc

    def actualizar_producto(self, dto: ActualizarProductoDTO) -> dict:
        self._validator.validar_producto_actualizacion(dto)
        payload: dict = {}
        if dto.nombre is not None:
            payload["nombre"] = dto.nombre.strip()
        if dto.descripcion is not None:
            payload["descripcion"] = dto.descripcion
        if dto.precio is not None:
            payload["precio"] = float(dto.precio)
        if dto.descuento_porcentaje is not None:
            payload["descuento_porcentaje"] = float(dto.descuento_porcentaje)
        if dto.puntos_recompensa is not None:
            payload["puntos_recompensa"] = int(dto.puntos_recompensa)

        if not payload:
            return {}

        try:
            return self._repo.actualizar_producto(dto.id_producto, payload)
        except Exception as exc:
            raise CatalogoError(f"Error actualizando producto: {exc}") from exc

    def desactivar_producto(self, id_producto: UUID) -> dict:
        try:
            return self._repo.desactivar_producto(id_producto)
        except Exception as exc:
            raise CatalogoError(f"Error desactivando producto: {exc}") from exc

    def aprobar_producto(self, id_producto: UUID) -> dict:
        """CU019 — Admin aprueba/modera un producto (borrador → activo)."""
        return self._repo.aprobar_producto(id_producto)

    def activar_producto(self, id_producto: UUID) -> dict:
        """CU019 — Activar producto moderado (publicación moderada)."""
        try:
            return self._repo.activar_producto(id_producto)
        except Exception as exc:
            raise CatalogoError(f"Error activando producto: {exc}") from exc

    def agregar_foto(self, dto: AgregarFotoDTO) -> dict:
        self._validator.validar_foto(dto)
        payload = {
            "id_producto": str(dto.id_producto),
            "url": dto.url,
            "descripcion": dto.descripcion,
            "orden": dto.orden,
        }
        try:
            return self._repo.agregar_foto(payload)
        except Exception as exc:
            raise CatalogoError(f"Error agregando foto: {exc}") from exc

    def listar_fotos(self, id_producto: UUID) -> list[dict]:
        try:
            return self._repo.listar_fotos(id_producto)
        except Exception as exc:
            raise CatalogoError(f"Error listando fotos: {exc}") from exc

    def eliminar_foto(self, dto: EliminarFotoDTO) -> None:
        try:
            self._repo.eliminar_foto(dto.id_foto)
        except Exception as exc:
            raise CatalogoError(f"Error eliminando foto: {exc}") from exc

    def actualizar_foto(self, dto: ActualizarFotoDTO) -> dict:
        self._validator.validar_foto_actualizar(dto)
        payload: dict = {}
        if dto.url is not None:
            payload["url"] = dto.url
        if dto.descripcion is not None:
            payload["descripcion"] = dto.descripcion
        if dto.orden is not None:
            payload["orden"] = dto.orden
        if not payload:
            return {}
        try:
            return self._repo.actualizar_foto(dto.id_foto, payload)
        except Exception as exc:
            raise CatalogoError(f"Error actualizando foto: {exc}") from exc

    def reordenar_fotos(self, dto: ReordenarFotosDTO) -> None:
        self._validator.validar_reordenar_fotos(dto)
        try:
            self._repo.reordenar_fotos(dto.id_producto, dto.ids)
        except Exception as exc:
            raise CatalogoError(f"Error reordenando fotos: {exc}") from exc
