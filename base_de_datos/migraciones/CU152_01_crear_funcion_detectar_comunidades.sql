-- =============================================================
-- Caso de Uso: CU152 - Detección de comunidades
-- Archivo: CU152_01_crear_funcion_detectar_comunidades.sql
-- Fecha: 2026-04-19
-- Autor: GitHub Copilot (GPT-4.1)
-- Descripción: Crea la función RPC para detección de comunidades usando AGE
-- =============================================================


CREATE OR REPLACE FUNCTION auth.detectar_comunidades(
    algoritmo text,
    parametros jsonb
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY INVOKER
AS $$
DECLARE
    resultado jsonb;
BEGIN
    -- Lógica: Invocar función de AGE para detectar comunidades
    -- (Ejemplo: louvain, label_propagation, etc.)
    -- Aquí se simula la llamada, debe integrarse con AGE real
    resultado := jsonb_build_object(
        'algoritmo', algoritmo,
        'parametros', parametros,
        'comunidades', jsonb_build_array(
            jsonb_build_object('id_comunidad', 1, 'miembros', jsonb_build_array('uuid1','uuid2'), 'metadatos', jsonb_build_object('size',2))
        ),
        'grafo_estado', jsonb_build_object('nodos', 100, 'aristas', 200)
    );
    RETURN resultado;
END;
$$;

REVOKE ALL ON FUNCTION auth.detectar_comunidades(text, jsonb) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION auth.detectar_comunidades(text, jsonb) TO admin;
GRANT EXECUTE ON FUNCTION auth.detectar_comunidades(text, jsonb) TO moderador;
GRANT EXECUTE ON FUNCTION auth.detectar_comunidades(text, jsonb) TO buyer;
GRANT EXECUTE ON FUNCTION auth.detectar_comunidades(text, jsonb) TO seller;
GRANT EXECUTE ON FUNCTION auth.detectar_comunidades(text, jsonb) TO anon;
GRANT EXECUTE ON FUNCTION auth.detectar_comunidades(text, jsonb) TO svc_postgrest_admin;
GRANT EXECUTE ON FUNCTION auth.detectar_comunidades(text, jsonb) TO svc_postgrest_user;
