"""Validaciones para CU015/CU016/CU017."""
from application.dto.postventa_dto import (
    ActualizarEnvioDTO,
    CrearConsultaServicioDTO,
    UpsertPerfilVendedorDTO,
)


class PostventaValidator:
    ESTADOS_ENVIO = {
        "pendiente_preparacion",
        "preparando",
        "en_camino",
        "entregado",
        "incidencia",
        "cancelado",
    }

    def validar_envio(self, dto: ActualizarEnvioDTO) -> None:
        estado = dto.payload.get("estado")
        if estado and estado not in self.ESTADOS_ENVIO:
            raise ValueError("estado de envío inválido")

    def validar_perfil(self, dto: UpsertPerfilVendedorDTO) -> None:
        slug = dto.payload.get("slug_publico")
        if slug is not None and not str(slug).strip():
            raise ValueError("slug_publico inválido")

    def validar_consulta(self, dto: CrearConsultaServicioDTO) -> None:
        asunto = dto.payload.get("asunto")
        if asunto is not None and not str(asunto).strip():
            raise ValueError("asunto inválido")
