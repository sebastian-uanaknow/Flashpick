/*
  # Corregir Sintaxis de Políticas RLS

  ## Cambios de Seguridad

  1. **Simplificar Políticas RLS**:
     - Eliminar el uso innecesario de (SELECT auth.uid())
     - Usar directamente auth.uid() en las políticas
     - Esto mejora el rendimiento y evita posibles problemas de evaluación
  
  2. **Políticas Actualizadas**:
     - sessions: Simplificar verificación de ownership
     - participants: Simplificar verificación de ownership de sesión
  
  ## Notas Técnicas
  - auth.uid() ya es una función que retorna UUID directamente
  - No es necesario envolverla en un SELECT
  - La sintaxis simplificada es más eficiente y clara
*/

-- ============================================================================
-- ELIMINAR POLÍTICAS EXISTENTES
-- ============================================================================

DROP POLICY IF EXISTS "Anónimos pueden verificar estado de sesiones" ON sessions;
DROP POLICY IF EXISTS "Autenticados ven sus propias sesiones" ON sessions;
DROP POLICY IF EXISTS "Autenticados crean sesiones" ON sessions;
DROP POLICY IF EXISTS "Creador actualiza su sesión" ON sessions;
DROP POLICY IF EXISTS "Creador elimina su sesión" ON sessions;

DROP POLICY IF EXISTS "Creador ve participantes de su sesión" ON participants;
DROP POLICY IF EXISTS "Registro en sesiones activas" ON participants;
DROP POLICY IF EXISTS "Creador actualiza participantes" ON participants;
DROP POLICY IF EXISTS "Creador elimina participantes" ON participants;

-- ============================================================================
-- POLÍTICAS CORREGIDAS: sessions
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
  USING (created_by = auth.uid());

-- INSERT: Solo usuarios autenticados pueden crear sesiones
CREATE POLICY "Autenticados crean sesiones"
  ON sessions FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() IS NOT NULL);

-- UPDATE: Solo el creador puede actualizar su sesión
CREATE POLICY "Creador actualiza su sesión"
  ON sessions FOR UPDATE
  TO authenticated
  USING (created_by = auth.uid())
  WITH CHECK (created_by = auth.uid());

-- DELETE: Solo el creador puede eliminar su sesión
CREATE POLICY "Creador elimina su sesión"
  ON sessions FOR DELETE
  TO authenticated
  USING (created_by = auth.uid());

-- ============================================================================
-- POLÍTICAS CORREGIDAS: participants
-- ============================================================================

-- SELECT: Solo el creador de la sesión puede ver los participantes
CREATE POLICY "Creador ve participantes de su sesión"
  ON participants FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM sessions
      WHERE sessions.id = participants.session_id
      AND sessions.created_by = auth.uid()
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
      AND sessions.created_by = auth.uid()
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM sessions
      WHERE sessions.id = participants.session_id
      AND sessions.created_by = auth.uid()
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
      AND sessions.created_by = auth.uid()
    )
  );