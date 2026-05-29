/*
  # Optimizar RLS y Añadir Índices

  ## Cambios de Rendimiento y Seguridad
  
  1. **Índices**:
     - Agregar índice en sessions.created_by para mejorar rendimiento de foreign key
  
  2. **Optimización RLS**:
     - Reemplazar auth.uid() con (select auth.uid()) en todas las políticas
     - Esto previene re-evaluación de auth.uid() para cada fila
     - Mejora significativamente el rendimiento en queries con muchas filas
  
  3. **Función Segura**:
     - Recrear set_created_by con search_path inmutable
     - Previene ataques de search_path hijacking
  
  ## Notas
  - Las políticas RLS ahora son más eficientes
  - La función es más segura contra ataques de inyección
*/

-- Agregar índice para la clave foránea created_by
CREATE INDEX IF NOT EXISTS idx_sessions_created_by ON sessions(created_by);

-- Eliminar políticas existentes para recrearlas optimizadas
DROP POLICY IF EXISTS "Usuarios autenticados pueden crear sesiones" ON sessions;
DROP POLICY IF EXISTS "Solo el creador puede actualizar su sesión" ON sessions;
DROP POLICY IF EXISTS "Solo el creador puede eliminar su sesión" ON sessions;
DROP POLICY IF EXISTS "Solo el creador de la sesión puede actualizar participantes" ON participants;
DROP POLICY IF EXISTS "Solo el creador de la sesión puede eliminar participantes" ON participants;

-- Recrear políticas RLS optimizadas para sessions
CREATE POLICY "Usuarios autenticados pueden crear sesiones"
  ON sessions FOR INSERT
  TO authenticated
  WITH CHECK ((select auth.uid()) IS NOT NULL);

CREATE POLICY "Solo el creador puede actualizar su sesión"
  ON sessions FOR UPDATE
  TO authenticated
  USING (created_by = (select auth.uid()))
  WITH CHECK (created_by = (select auth.uid()));

CREATE POLICY "Solo el creador puede eliminar su sesión"
  ON sessions FOR DELETE
  TO authenticated
  USING (created_by = (select auth.uid()));

-- Recrear políticas RLS optimizadas para participants
CREATE POLICY "Solo el creador de la sesión puede actualizar participantes"
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

CREATE POLICY "Solo el creador de la sesión puede eliminar participantes"
  ON participants FOR DELETE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM sessions
      WHERE sessions.id = participants.session_id
      AND sessions.created_by = (select auth.uid())
    )
  );

-- Eliminar trigger primero
DROP TRIGGER IF EXISTS set_sessions_created_by ON sessions;

-- Eliminar función
DROP FUNCTION IF EXISTS set_created_by();

-- Recrear función set_created_by con search_path seguro
CREATE OR REPLACE FUNCTION set_created_by()
RETURNS TRIGGER 
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  NEW.created_by := auth.uid();
  RETURN NEW;
END;
$$;

-- Recrear trigger
CREATE TRIGGER set_sessions_created_by
  BEFORE INSERT ON sessions
  FOR EACH ROW
  EXECUTE FUNCTION set_created_by();