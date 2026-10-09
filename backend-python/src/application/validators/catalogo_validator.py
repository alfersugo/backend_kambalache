"""Validaciones de entrada para CU011 — Catálogo."""
import re
from application.dto.catalogo_dto import (
    ActualizarFotoDTO,
    ActualizarProductoDTO,
    AgregarFotoDTO,
    CrearCategoriaDTO,
    CrearProductoDTO,
    CrearSubcategoriaDTO,
    ReordenarFotosDTO,
)

# Extensiones permitidas en URL de imagen (OWASP: validación de tipo de archivo)
_ALLOWED_IMG_EXTS = re.compile(
    r'\.(jpg|jpeg|png|gif|webp)(\?.*)?$', re.IGNORECASE
)
# Rangos privados/loopback — previene SSRF
_SSRF_PATTERNS = re.compile(
    r'https?://(localhost|127\.|0\.0\.0\.0|10\.|192\.168\.|'
    r'172\.(1[6-9]|2[0-9]|3[01])\.|169\.254\.)',
    re.IGNORECASE,
)
_MAX_DESC_LEN = 500
_MAX_ORDEN = 200


class CatalogoValidator:
    def validar_categoria(self, dto: CrearCategoriaDTO) -> None:
        if not dto.nombre or not dto.nombre.strip():
            raise ValueError("El nombre de categoría es obligatorio")

    def validar_subcategoria(self, dto: CrearSubcategoriaDTO) -> None:
        if not dto.nombre or not dto.nombre.strip():
            raise ValueError("El nombre de subcategoría es obligatorio")

    def validar_producto_alta(self, dto: CrearProductoDTO) -> None:
        if not dto.nombre or not dto.nombre.strip():
            raise ValueError("El nombre de producto es obligatorio")
        if dto.precio < 0:
            raise ValueError("El precio no puede ser negativo")
        if dto.descuento_porcentaje < 0 or dto.descuento_porcentaje > 100:
            raise ValueError("El descuento debe estar entre 0 y 100")
        if dto.puntos_recompensa < 0:
            raise ValueError("Los puntos no pueden ser negativos")

    def validar_producto_actualizacion(self, dto: ActualizarProductoDTO) -> None:
        if dto.precio is not None and dto.precio < 0:
            raise ValueError("El precio no puede ser negativo")
        if dto.descuento_porcentaje is not None and (dto.descuento_porcentaje < 0 or dto.descuento_porcentaje > 100):
            raise ValueError("El descuento debe estar entre 0 y 100")
        if dto.puntos_recompensa is not None and dto.puntos_recompensa < 0:
            raise ValueError("Los puntos no pueden ser negativos")

    def _validar_url_imagen(self, url: str) -> None:
        """Validación de seguridad OWASP: HTTPS, extensión, anti-SSRF."""
        url = url.strip()
        if not url:
            raise ValueError("La URL de la foto es obligatoria")
        if not url.startswith("https://"):
            raise ValueError("La URL de la foto debe usar HTTPS")
        if _SSRF_PATTERNS.match(url):
            raise ValueError("URL de imagen apunta a dirección interna no permitida")
        if not _ALLOWED_IMG_EXTS.search(url):
            raise ValueError(
                "Formato de imagen no permitido. Use: jpg, jpeg, png, gif, webp"
            )
        if len(url) > 2048:
            raise ValueError("URL de imagen demasiado larga (máx 2048 caracteres)")

    def validar_foto(self, dto: AgregarFotoDTO) -> None:
        self._validar_url_imagen(dto.url)
        if dto.orden < 0:
            raise ValueError("El orden de la foto no puede ser negativo")
        if dto.orden > _MAX_ORDEN:
            raise ValueError(f"El orden de la foto no puede superar {_MAX_ORDEN}")
        if dto.descripcion and len(dto.descripcion) > _MAX_DESC_LEN:
            raise ValueError(f"La descripción no puede superar {_MAX_DESC_LEN} caracteres")

    def validar_foto_actualizar(self, dto: ActualizarFotoDTO) -> None:
        if dto.url is not None:
            self._validar_url_imagen(dto.url)
        if dto.orden is not None:
            if dto.orden < 0:
                raise ValueError("El orden de la foto no puede ser negativo")
            if dto.orden > _MAX_ORDEN:
                raise ValueError(f"El orden no puede superar {_MAX_ORDEN}")
        if dto.descripcion is not None and len(dto.descripcion) > _MAX_DESC_LEN:
            raise ValueError(f"La descripción no puede superar {_MAX_DESC_LEN} caracteres")

    def validar_reordenar_fotos(self, dto: ReordenarFotosDTO) -> None:
        if not dto.ids:
            raise ValueError("La lista de IDs para reordenar no puede estar vacía")
        if len(dto.ids) > 50:
            raise ValueError("No se pueden reordenar más de 50 fotos a la vez")
