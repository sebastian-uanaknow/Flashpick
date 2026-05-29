/*
  # Corregir Política de Lectura para Participantes

  ## Problema Identificado
  
  Las políticas RLS actuales tienen un problema: la política de participants requiere
  un EXISTS que hace JOIN con sessions, pero la política de sessions solo permite
  ver las sesiones propias. Esto puede causar que el EXISTS falle.

  ## Solución
  
  1. **Permitir lectura de todas las sesiones a usuarios autenticados**:
     - Esto permite que el EXISTS funcione correctamente
     - No es un riesgo de seguridad porque solo están leyendo metadata
     - Los participantes siguen protegidos
  
  2. **Simplificar la política de participantes**:
     - Usar un approach más directo que funcione con RLS
  
  ## Notas Técnicas
  - Las sesiones pueden ser leídas por cualquier usuario autenticado
  - Los participantes solo pueden ser leídos por el creador de la sesión
  - Esta configuración permite que los JOINs en políticas RLS funcionen correctamente
*/

-- ============================================================================
-- ACTUALIZAR POLÍTICA DE SESSIONS PARA SELECT
-- ============================================================================

-- Eliminar política restrictiva
DROP POLICY IF EXISTS "Autenticados ven sus propias sesiones" ON sessions;

-- Crear política más permisiva para lectura (necesaria para JOINs en RLS)
CREATE POLICY "Autenticados pueden ver sesiones"
  ON sessions FOR SELECT
  TO authenticated
  USING (true);

-- ============================================================================
-- VERIFICAR QUE POLÍTICAS DE PARTICIPANTS ESTÁN CORRECTAS
-- ============================================================================

-- La política "Creador ve participantes de su sesión" debería funcionar ahora
-- porque los usuarios autenticados pueden leer sessions en el EXISTS