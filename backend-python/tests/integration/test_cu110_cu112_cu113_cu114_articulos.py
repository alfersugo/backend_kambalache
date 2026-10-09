"""
Integration tests for CU110 / CU112 / CU113 / CU114 — Artículos de Intercambio.
CU110: Publicar artículo para intercambio (crear producto, activar)
CU112: Categorizar artículos (crear/listar categorías y subcategorías)
CU113: Gestionar imágenes de artículos (agregar foto, listar)
CU114: Valorar condición del artículo (actualizar estado/condición)
Mapea a: catalogo_service.py
"""
import pytest
import requests
from unittest.mock import MagicMock
from uuid import uuid4, UUID

POSTGREST_URL = "http://localhost:3000"
TIMEOUT = 10


def _api_disponible() -> bool:
    try:
        return requests.get(f"{POSTGREST_URL}/", timeout=5).status_code == 200
    except Exception:
        return False


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


# ── CU110: Publicar artículo ──────────────────────────────────────────────────


class TestCU110PublicarArticulo:
    def test_crear_producto_mock(self):
        from application.services.catalogo_service import CatalogoService
        from application.dto.catalogo_dto import CrearProductoDTO
        repo = MagicMock()
        pid = uuid4()
        repo.crear_producto.return_value = {"id": str(pid), "nombre": "Artículo test", "activo": False}
        svc = CatalogoService(repo)
        dto = CrearProductoDTO(
            nombre="Artículo test",
            descripcion="Desc",
            precio=100.0,
            id_categoria=uuid4(),
        )
        result = svc.crear_producto(dto)
        assert "id" in result

    def test_activar_producto_mock(self):
        from application.services.catalogo_service import CatalogoService
        repo = MagicMock()
        pid = uuid4()
        repo.activar_producto.return_value = {"id": str(pid), "activo": True}
        svc = CatalogoService(repo)
        result = svc.activar_producto(pid)
        assert result["activo"] is True

    def test_desactivar_producto_mock(self):
        from application.services.catalogo_service import CatalogoService
        repo = MagicMock()
        pid = uuid4()
        repo.desactivar_producto.return_value = {"id": str(pid), "activo": False}
        svc = CatalogoService(repo)
        result = svc.desactivar_producto(pid)
        assert result["activo"] is False

    def test_listar_mis_productos_mock(self):
        from application.services.catalogo_service import CatalogoService
        repo = MagicMock()
        repo.listar_mis_productos.return_value = [
            {"id": str(uuid4()), "nombre": "Art A"},
            {"id": str(uuid4()), "nombre": "Art B"},
        ]
        svc = CatalogoService(repo)
        result = svc.listar_mis_productos()
        assert len(result) == 2

    def test_actualizar_producto_mock(self):
        from application.services.catalogo_service import CatalogoService
        from application.dto.catalogo_dto import ActualizarProductoDTO
        repo = MagicMock()
        pid = uuid4()
        repo.actualizar_producto.return_value = {"id": str(pid), "nombre": "Actualizado"}
        svc = CatalogoService(repo)
        dto = ActualizarProductoDTO(id_producto=pid, nombre="Actualizado")
        result = svc.actualizar_producto(dto)
        assert result["nombre"] == "Actualizado"

    @pytest.mark.integration
    def test_listar_productos_seller_via_postgrest(self):
        if not _api_disponible():
            pytest.skip("PostgREST no disponible")
        token = _get_jwt("seller@smtp-posix.local", "Seller123!")
        if not token:
            pytest.skip("No se pudo obtener JWT")
        r = requests.get(
            f"{POSTGREST_URL}/productos",
            headers={"Authorization": f"Bearer {token}"},
            timeout=TIMEOUT,
        )
        assert r.status_code in (200, 403), f"Unexpected: {r.status_code}"
        if r.status_code == 200:
            assert isinstance(r.json(), list)


# ── CU112: Categorizar artículos ──────────────────────────────────────────────


class TestCU112CategorizarArticulos:
    def test_crear_categoria_mock(self):
        from application.services.catalogo_service import CatalogoService
        from application.dto.catalogo_dto import CrearCategoriaDTO
        repo = MagicMock()
        cid = uuid4()
        repo.crear_categoria.return_value = {"id": str(cid), "nombre": "Electrónica"}
        svc = CatalogoService(repo)
        dto = CrearCategoriaDTO(nombre="Electrónica", descripcion="Gadgets")
        result = svc.crear_categoria(dto)
        assert result["nombre"] == "Electrónica"

    def test_crear_subcategoria_mock(self):
        from application.services.catalogo_service import CatalogoService
        from application.dto.catalogo_dto import CrearSubcategoriaDTO
        repo = MagicMock()
        sid = uuid4()
        repo.crear_subcategoria.return_value = {"id": str(sid), "nombre": "Celulares"}
        svc = CatalogoService(repo)
        dto = CrearSubcategoriaDTO(nombre="Celulares", id_categoria=uuid4())
        result = svc.crear_subcategoria(dto)
        assert result["nombre"] == "Celulares"

    @pytest.mark.integration
    def test_listar_categorias_via_postgrest(self):
        if not _api_disponible():
            pytest.skip("PostgREST no disponible")
        r = requests.get(f"{POSTGREST_URL}/categorias", timeout=TIMEOUT)
        assert r.status_code in (200, 404), f"Unexpected: {r.status_code}"
        if r.status_code == 200:
            assert isinstance(r.json(), list)


# ── CU113: Gestionar imágenes ─────────────────────────────────────────────────


class TestCU113GestionImagenes:
    def test_agregar_foto_mock(self):
        from application.services.catalogo_service import CatalogoService
        from application.dto.catalogo_dto import AgregarFotoDTO
        repo = MagicMock()
        fid = uuid4()
        repo.agregar_foto.return_value = {"id": str(fid), "url": "https://img.test/photo.jpg"}
        svc = CatalogoService(repo)
        dto = AgregarFotoDTO(id_producto=uuid4(), url="https://img.test/photo.jpg", orden=1)
        result = svc.agregar_foto(dto)
        assert "url" in result

    def test_listar_fotos_mock(self):
        from application.services.catalogo_service import CatalogoService
        repo = MagicMock()
        pid = uuid4()
        repo.listar_fotos.return_value = [
            {"id": str(uuid4()), "url": "https://img.test/a.jpg"},
            {"id": str(uuid4()), "url": "https://img.test/b.jpg"},
        ]
        svc = CatalogoService(repo)
        result = svc.listar_fotos(pid)
        assert len(result) == 2
        assert "url" in result[0]

    def test_listar_fotos_producto_inexistente_retorna_lista(self):
        from application.services.catalogo_service import CatalogoService
        repo = MagicMock()
        repo.listar_fotos.return_value = []
        svc = CatalogoService(repo)
        result = svc.listar_fotos(uuid4())
        assert result == []

    def test_eliminar_foto_mock(self):
        from application.services.catalogo_service import CatalogoService
        from application.dto.catalogo_dto import EliminarFotoDTO
        repo = MagicMock()
        repo.eliminar_foto.return_value = None
        svc = CatalogoService(repo)
        dto = EliminarFotoDTO(id_foto=uuid4())
        svc.eliminar_foto(dto)
        repo.eliminar_foto.assert_called_once()

    def test_actualizar_foto_url_mock(self):
        from application.services.catalogo_service import CatalogoService
        from application.dto.catalogo_dto import ActualizarFotoDTO
        repo = MagicMock()
        fid = uuid4()
        repo.actualizar_foto.return_value = {"id": str(fid), "url": "https://img.test/nueva.png"}
        svc = CatalogoService(repo)
        dto = ActualizarFotoDTO(id_foto=fid, url="https://img.test/nueva.png")
        result = svc.actualizar_foto(dto)
        assert result["url"] == "https://img.test/nueva.png"

    def test_actualizar_foto_sin_cambios_retorna_vacio(self):
        from application.services.catalogo_service import CatalogoService
        from application.dto.catalogo_dto import ActualizarFotoDTO
        repo = MagicMock()
        svc = CatalogoService(repo)
        dto = ActualizarFotoDTO(id_foto=uuid4())
        result = svc.actualizar_foto(dto)
        assert result == {}
        repo.actualizar_foto.assert_not_called()

    def test_reordenar_fotos_mock(self):
        from application.services.catalogo_service import CatalogoService
        from application.dto.catalogo_dto import ReordenarFotosDTO
        repo = MagicMock()
        repo.reordenar_fotos.return_value = None
        svc = CatalogoService(repo)
        ids = [str(uuid4()), str(uuid4()), str(uuid4())]
        dto = ReordenarFotosDTO(id_producto=uuid4(), ids=ids)
        svc.reordenar_fotos(dto)
        repo.reordenar_fotos.assert_called_once()

    def test_reordenar_fotos_lista_vacia_lanza(self):
        from application.services.catalogo_service import CatalogoService
        from application.dto.catalogo_dto import ReordenarFotosDTO
        repo = MagicMock()
        svc = CatalogoService(repo)
        dto = ReordenarFotosDTO(id_producto=uuid4(), ids=[])
        with pytest.raises(ValueError, match="vacía"):
            svc.reordenar_fotos(dto)

    # ── Seguridad URL (OWASP) ────────────────────────────────────────────────

    def test_url_foto_vacia_lanza(self):
        from application.dto.catalogo_dto import AgregarFotoDTO
        from application.validators.catalogo_validator import CatalogoValidator
        with pytest.raises(ValueError, match="obligatoria"):
            CatalogoValidator().validar_foto(AgregarFotoDTO(id_producto=uuid4(), url=""))

    def test_url_foto_sin_https_lanza(self):
        from application.dto.catalogo_dto import AgregarFotoDTO
        from application.validators.catalogo_validator import CatalogoValidator
        with pytest.raises(ValueError, match="HTTPS"):
            CatalogoValidator().validar_foto(
                AgregarFotoDTO(id_producto=uuid4(), url="http://cdn.example.com/img.jpg")
            )

    def test_url_foto_ssrf_localhost_lanza(self):
        from application.dto.catalogo_dto import AgregarFotoDTO
        from application.validators.catalogo_validator import CatalogoValidator
        with pytest.raises(ValueError, match="interna"):
            CatalogoValidator().validar_foto(
                AgregarFotoDTO(id_producto=uuid4(), url="https://localhost/evil.jpg")
            )

    def test_url_foto_ssrf_192_168_lanza(self):
        from application.dto.catalogo_dto import AgregarFotoDTO
        from application.validators.catalogo_validator import CatalogoValidator
        with pytest.raises(ValueError, match="interna"):
            CatalogoValidator().validar_foto(
                AgregarFotoDTO(id_producto=uuid4(), url="https://192.168.1.10/img.png")
            )

    def test_url_foto_extension_no_permitida_lanza(self):
        from application.dto.catalogo_dto import AgregarFotoDTO
        from application.validators.catalogo_validator import CatalogoValidator
        with pytest.raises(ValueError, match="Formato"):
            CatalogoValidator().validar_foto(
                AgregarFotoDTO(id_producto=uuid4(), url="https://cdn.example.com/doc.pdf")
            )

    def test_url_foto_extension_exe_lanza(self):
        from application.dto.catalogo_dto import AgregarFotoDTO
        from application.validators.catalogo_validator import CatalogoValidator
        with pytest.raises(ValueError, match="Formato"):
            CatalogoValidator().validar_foto(
                AgregarFotoDTO(id_producto=uuid4(), url="https://cdn.example.com/malware.exe")
            )

    def test_url_foto_valida_jpg(self):
        from application.dto.catalogo_dto import AgregarFotoDTO
        from application.validators.catalogo_validator import CatalogoValidator
        CatalogoValidator().validar_foto(
            AgregarFotoDTO(id_producto=uuid4(), url="https://cdn.example.com/photo.jpg")
        )

    def test_url_foto_valida_webp(self):
        from application.dto.catalogo_dto import AgregarFotoDTO
        from application.validators.catalogo_validator import CatalogoValidator
        CatalogoValidator().validar_foto(
            AgregarFotoDTO(id_producto=uuid4(), url="https://cdn.example.com/photo.webp?v=1")
        )

    def test_url_foto_valida_png(self):
        from application.dto.catalogo_dto import AgregarFotoDTO
        from application.validators.catalogo_validator import CatalogoValidator
        CatalogoValidator().validar_foto(
            AgregarFotoDTO(id_producto=uuid4(), url="https://img.test/a.png")
        )

    def test_descripcion_demasiado_larga_lanza(self):
        from application.dto.catalogo_dto import AgregarFotoDTO
        from application.validators.catalogo_validator import CatalogoValidator
        with pytest.raises(ValueError, match="descripción"):
            CatalogoValidator().validar_foto(
                AgregarFotoDTO(
                    id_producto=uuid4(),
                    url="https://cdn.example.com/photo.jpg",
                    descripcion="x" * 501,
                )
            )

    @pytest.mark.integration
    def test_agregar_listar_foto_via_postgrest(self):
        """Integración real: agregar foto y listarla via PostgREST."""
        if not _api_disponible():
            pytest.skip("PostgREST no disponible")
        token = _get_jwt("seller@smtp-posix.local", "Seller123!")
        if not token:
            pytest.skip("No se pudo obtener JWT seller")
        # Obtener un producto del seller
        r = requests.get(
            f"{POSTGREST_URL}/productos",
            headers={"Authorization": f"Bearer {token}"},
            params={"limit": "1"},
            timeout=TIMEOUT,
        )
        if r.status_code != 200 or not r.json():
            pytest.skip("No hay productos del seller para test")
        producto_id = r.json()[0]["id"]
        # Agregar foto
        r_add = requests.post(
            f"{POSTGREST_URL}/galeria_fotos",
            json={
                "id_producto": producto_id,
                "url": "https://cdn.example.com/test_foto.jpg",
                "descripcion": "Foto test integracion",
                "orden": 99,
            },
            headers={
                "Authorization": f"Bearer {token}",
                "Prefer": "return=representation",
            },
            timeout=TIMEOUT,
        )
        assert r_add.status_code in (200, 201), f"Agregar foto falló: {r_add.text}"
        foto_id = r_add.json()[0]["id"] if isinstance(r_add.json(), list) else r_add.json()["id"]
        # Listar fotos del producto
        r_list = requests.get(
            f"{POSTGREST_URL}/galeria_fotos",
            params={"id_producto": f"eq.{producto_id}", "order": "orden.asc"},
            headers={"Authorization": f"Bearer {token}"},
            timeout=TIMEOUT,
        )
        assert r_list.status_code == 200
        ids_en_lista = [f["id"] for f in r_list.json()]
        assert foto_id in ids_en_lista
        # Cleanup
        requests.post(
            f"{POSTGREST_URL}/rpc/eliminar_foto",
            json={"p_id": foto_id},
            headers={"Authorization": f"Bearer {token}"},
            timeout=TIMEOUT,
        )


# ── CU114: Valorar condición del artículo ────────────────────────────────────


class TestCU114ValorarCondicion:
    """
    CU114: la condición del artículo se gestiona como campo en el producto.
    Se valida vía actualizar_producto (campo condicion/estado).
    """

    def test_valorar_condicion_actualizar_nombre_estado(self):
        """
        CU114: la condición se gestiona como campo de descripción/precio del producto.
        Se valida que el producto puede actualizarse con nueva información de estado.
        """
        from application.services.catalogo_service import CatalogoService
        from application.dto.catalogo_dto import ActualizarProductoDTO
        repo = MagicMock()
        pid = uuid4()
        repo.actualizar_producto.return_value = {"id": str(pid), "descripcion": "Condición: nuevo"}
        svc = CatalogoService(repo)
        dto = ActualizarProductoDTO(id_producto=pid, descripcion="Condición: nuevo")
        result = svc.actualizar_producto(dto)
        assert "Condición" in result.get("descripcion", "")

    def test_actualizacion_producto_error_propagado(self):
        from application.services.catalogo_service import CatalogoService
        from application.dto.catalogo_dto import ActualizarProductoDTO
        from domain.exceptions.catalogo_exceptions import CatalogoError
        repo = MagicMock()
        repo.actualizar_producto.side_effect = CatalogoError("Producto no encontrado")
        svc = CatalogoService(repo)
        dto = ActualizarProductoDTO(id_producto=uuid4(), nombre="Nuevo")
        with pytest.raises(CatalogoError):
            svc.actualizar_producto(dto)
