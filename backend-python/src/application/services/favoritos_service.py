"""
Servicio de aplicación — CU010: Gestión de Favoritos.

Gestiona el CRUD de favoritos sobre /favoritos y /v_mis_favoritos.
Requiere JWT de buyer; RLS garantiza aislamiento por usuario.
"""
from typing import List
from uuid import UUID

from application.dto.favoritos_dto import AgregarFavoritoDTO, FavoritoItemDTO, ListaFavoritosDTO
from domain.exceptions.favoritos_exceptions import FavoritosError, FavoritoYaExisteError
from domain.ports.favoritos_repository_port import FavoritosRepositoryPort


class FavoritosService:
    def __init__(self, repo: FavoritosRepositoryPort) -> None:
        self._repo = repo

    def agregar(self, dto: AgregarFavoritoDTO) -> FavoritoItemDTO:
        try:
            data = self._repo.agregar(dto.id_producto)
        except FavoritoYaExisteError:
            raise
        except Exception as exc:
            raise FavoritosError(f"Error al agregar favorito: {exc}") from exc

        return FavoritoItemDTO(
            id=str(data.get("id", "")),
            id_producto=str(data.get("id_producto", dto.id_producto)),
            nombre=data.get("nombre", ""),
            precio=float(data.get("precio", 0)),
            descuento_porcentaje=float(data.get("descuento_porcentaje", 0)),
            puntos_recompensa=int(data.get("puntos_recompensa", 0)),
            foto_principal=data.get("foto_principal"),
        )

    def listar(self) -> ListaFavoritosDTO:
        try:
            rows = self._repo.listar()
        except Exception as exc:
            raise FavoritosError(f"Error al listar favoritos: {exc}") from exc

        items = [
            FavoritoItemDTO(
                id=str(r.get("id", "")),
                id_producto=str(r.get("id_producto", "")),
                nombre=r.get("nombre", ""),
                precio=float(r.get("precio", 0)),
                descuento_porcentaje=float(r.get("descuento_porcentaje", 0)),
                puntos_recompensa=int(r.get("puntos_recompensa", 0)),
                foto_principal=r.get("foto_principal"),
            )
            for r in rows
        ]
        return ListaFavoritosDTO(items=items, total=len(items))

    def eliminar(self, id_producto: UUID) -> None:
        try:
            self._repo.eliminar(id_producto)
        except Exception as exc:
            raise FavoritosError(f"Error al eliminar favorito: {exc}") from exc
