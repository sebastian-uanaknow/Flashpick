/*
  # Optimizar Rendimiento de Políticas RLS

  ## Cambios Realizados

  1. **Optimización de Políticas RLS**:
     - Reemplazar `auth.uid()` con `(select auth.uid())` en todas las políticas
     - Esto evita la re-evaluación de la función por cada fila
     - Mejora significativa de rendimiento en queries con muchas filas
  
  2. **Limpieza de Índices**:
     - Eliminar índice no utilizado `idx_sessions_created_by`
  
  ## Políticas Actualizadas

  ### Sessions:
  - "Autenticados crean sesiones" - INSERT policy
  - "Creador actualiza su sesión" - UPDATE policy  
  - "Creador elimina su sesión" - DELETE policy

  ### Participants:
  - "Creador ve participantes de su sesión" - SELECT policy
  - "Creador actualiza participantes" - UPDATE policy
  - "Creador elimina participantes" - DELETE policy

  ## Notas
  - El uso de `(select auth.uid())` cachea el valor por query
  - Esto evita múltiples llamadas al sistema de autenticación
  - Mejora el rendimiento sin comprometer la seguridad
*/

-- ============================================================================
-- ELIMINAR ÍNDICE NO UTILIZADO
-- ============================================================================

DROP INDEX IF EXISTS idx_sessions_created_by;

-- ============================================================================
-- OPTIMIZAR POLÍTICAS RLS DE SESSIONS
-- ============================================================================

-- Política INSERT: Autenticados crean sesiones
DROP POLICY IF EXISTS "Autenticados crean sesiones" ON sessions;
CREATE POLICY "Autenticados crean sesiones"
  ON sessions FOR INSERT
  TO authenticated
  WITH CHECK ((select auth.uid()) IS NOT NULL);

-- Política UPDATE: Solo el creador puede actualizar su sesión
DROP POLICY IF EXISTS "Creador actualiza su sesión" ON sessions;
CREATE POLICY "Creador actualiza su sesión"
  ON sessions FOR UPDATE
  TO authenticated
  USING (created_by = (select auth.uid()))
  WITH CHECK (created_by = (select auth.uid()));

-- Política DELETE: Solo el creador puede eliminar su sesión
DROP POLICY IF EXISTS "Creador elimina su sesión" ON sessions;
CREATE POLICY "Creador elimina su sesión"
  ON sessions FOR DELETE
  TO authenticated
  USING (created_by = (select auth.uid()));

-- ============================================================================
-- OPTIMIZAR POLÍTICAS RLS DE PARTICIPANTS
-- ============================================================================

-- Política SELECT: Creador ve participantes de su sesión
DROP POLICY IF EXISTS "Creador ve participantes de su sesión" ON participants;
CREATE POLICY "Creador ve participantes de su sesión"
  ON participants FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM sessions
      WHERE sessions.id = participants.session_id
      AND sessions.created_by = (select auth.uid())
    )
  );

-- Política UPDATE: Creador actualiza participantes
DROP POLICY IF EXISTS "Creador actualiza participantes" ON participants;
CREATE POLICY "Creador actualiza participantes"
  ON participants FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM sessions
      WHERE sessions.id = participants.session_id
      AND sessions.created_by = (select auth.uid())
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM sessions
      WHERE sessions.id = participants.session_id
      AND sessions.created_by = (select auth.uid())
    )
  );

-- Política DELETE: Creador elimina participantes
DROP POLICY IF EXISTS "Creador elimina participantes" ON participants;
CREATE POLICY "Creador elimina participantes"
  ON participants FOR DELETE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM sessions
      WHERE sessions.id = participants.session_id
      AND sessions.created_by = (select auth.uid())
    )
  );
