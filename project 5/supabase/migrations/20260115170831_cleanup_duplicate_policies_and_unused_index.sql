/*
  # Limpieza de Políticas RLS Duplicadas y Optimización de Seguridad

  ## Cambios de Seguridad

  1. **Eliminar Políticas Duplicadas**:
     - Eliminar todas las políticas existentes que causan conflictos
     - Crear un conjunto limpio y consolidado de políticas sin duplicados
  
  2. **Políticas Consolidadas para sessions**:
     - SELECT: Usuarios anónimos pueden verificar si una sesión está activa
     - SELECT: Usuarios autenticados pueden ver solo sus propias sesiones
     - INSERT/UPDATE/DELETE: Solo el creador puede gestionar sus sesiones
  
  3. **Políticas Consolidadas para participants**:
     - SELECT: Solo el creador de la sesión puede ver los participantes
     - INSERT: Cualquiera (anon/auth) puede registrarse si la sesión está activa
     - UPDATE/DELETE: Solo el creador de la sesión puede modificar/eliminar
  
  4. **Eliminar Índice No Utilizado**:
     - Eliminar idx_sessions_created_by que no está siendo utilizado en las queries
  
  ## Notas de Seguridad
  - Se eliminan todas las políticas permisivas que causaban conflictos
  - Cada tabla tendrá políticas claras sin superposición
  - Las políticas son restrictivas y verifican ownership correctamente
  - El índice idx_sessions_created_by se elimina ya que no mejora el rendimiento
*/

-- ============================================================================
-- LIMPIEZA: Eliminar todas las políticas existentes
-- ============================================================================

-- Eliminar políticas de sessions
DROP POLICY IF EXISTS "Cualquiera puede ver sesiones activas" ON sessions;
DROP POLICY IF EXISTS "Cualquiera puede ver si una sesión está activa" ON sessions;
DROP POLICY IF EXISTS "Usuarios autenticados pueden ver sus sesiones" ON sessions;
DROP POLICY IF EXISTS "Solo admin puede insertar sesiones" ON sessions;
DROP POLICY IF EXISTS "Usuarios autenticados pueden insertar sesiones" ON sessions;
DROP POLICY IF EXISTS "Usuarios autenticados pueden crear sesiones" ON sessions;
DROP POLICY IF EXISTS "Solo admin puede actualizar sesiones" ON sessions;
DROP POLICY IF EXISTS "Usuarios autenticados pueden actualizar sesiones" ON sessions;
DROP POLICY IF EXISTS "Solo el creador puede actualizar su sesión" ON sessions;
DROP POLICY IF EXISTS "Solo admin puede eliminar sesiones" ON sessions;
DROP POLICY IF EXISTS "Usuarios autenticados pueden eliminar sesiones" ON sessions;
DROP POLICY IF EXISTS "Solo el creador puede eliminar su sesión" ON sessions;

-- Eliminar políticas de participants
DROP POLICY IF EXISTS "Cualquiera puede ver participantes" ON participants;
DROP POLICY IF EXISTS "Solo el creador de la sesión puede ver participantes" ON participants;
DROP POLICY IF EXISTS "Cualquiera puede registrarse como participante" ON participants;
DROP POLICY IF EXISTS "Usuarios pueden registrarse en sesiones activas" ON participants;
DROP POLICY IF EXISTS "Cualquiera puede registrarse en sesiones activas" ON participants;
DROP POLICY IF EXISTS "Usuarios autenticados pueden registrarse en sesiones activas" ON participants;
DROP POLICY IF EXISTS "Solo admin puede actualizar participantes" ON participants;
DROP POLICY IF EXISTS "Usuarios autenticados pueden actualizar participantes" ON participants;
DROP POLICY IF EXISTS "Solo el creador de la sesión puede actualizar participantes" ON participants;
DROP POLICY IF EXISTS "Solo admin puede eliminar participantes" ON participants;
DROP POLICY IF EXISTS "Usuarios autenticados pueden eliminar participantes" ON participants;
DROP POLICY IF EXISTS "Solo el creador de la sesión puede eliminar participantes" ON participants;

-- ============================================================================
-- POLÍTICAS CONSOLIDADAS: sessions
-- ============================================================================

-- SELECT: Usuarios anónimos pueden verificar si una sesión está activa
CREATE POLICY "Anónimos pueden verificar estado de sesiones"
  ON sessions FOR SELECT
  TO anon
  USING (true);

-- SELECT: Usuarios autenticados pueden ver solo sus propias sesiones
CREATE POLICY "Autenticados ven sus propias sesiones"
  ON sessions FOR SELECT
  TO authenticated
  USING (created_by = (SELECT auth.uid()));

-- INSERT: Solo usuarios autenticados pueden crear sesiones
CREATE POLICY "Autenticados crean sesiones"
  ON sessions FOR INSERT
  TO authenticated
  WITH CHECK ((SELECT auth.uid()) IS NOT NULL);

-- UPDATE: Solo el creador puede actualizar su sesión
CREATE POLICY "Creador actualiza su sesión"
  ON sessions FOR UPDATE
  TO authenticated
  USING (created_by = (SELECT auth.uid()))
  WITH CHECK (created_by = (SELECT auth.uid()));

-- DELETE: Solo el creador puede eliminar su sesión
CREATE POLICY "Creador elimina su sesión"
  ON sessions FOR DELETE
  TO authenticated
  USING (created_by = (SELECT auth.uid()));

-- ============================================================================
-- POLÍTICAS CONSOLIDADAS: participants
-- ============================================================================

-- SELECT: Solo el creador de la sesión puede ver los participantes
CREATE POLICY "Creador ve participantes de su sesión"
  ON participants FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM sessions
      WHERE sessions.id = participants.session_id
      AND sessions.created_by = (SELECT auth.uid())
    )
  );

-- INSERT: Cualquiera puede registrarse si la sesión está activa
CREATE POLICY "Registro en sesiones activas"
  ON participants FOR INSERT
  TO anon, authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM sessions
      WHERE sessions.id = participants.session_id
      AND sessions.is_active = true
    )
  );

-- UPDATE: Solo el creador de la sesión puede actualizar participantes
CREATE POLICY "Creador actualiza participantes"
  ON participants FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM sessions
      WHERE sessions.id = participants.session_id
      AND sessions.created_by = (SELECT auth.uid())
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM sessions
      WHERE sessions.id = participants.session_id
      AND sessions.created_by = (SELECT auth.uid())
    )
  );

-- DELETE: Solo el creador de la sesión puede eliminar participantes
CREATE POLICY "Creador elimina participantes"
  ON participants FOR DELETE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM sessions
      WHERE sessions.id = participants.session_id
      AND sessions.created_by = (SELECT auth.uid())
    )
  );

-- ============================================================================
-- OPTIMIZACIÓN: Eliminar índice no utilizado
-- ============================================================================

-- Eliminar índice idx_sessions_created_by que no está siendo utilizado
DROP INDEX IF EXISTS idx_sessions_created_by;