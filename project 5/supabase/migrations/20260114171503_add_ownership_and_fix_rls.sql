/*
  # Agregar Ownership y Corregir Políticas RLS

  ## Cambios de Seguridad
  
  1. **Agregar campo created_by**:
     - Agregar `created_by` UUID a tabla sessions para tracking de ownership
     - Agregar trigger para auto-llenar created_by con auth.uid()
  
  2. **Actualizar Políticas RLS**:
     - Restringir INSERT de sessions solo al speaker autenticado
     - Restringir UPDATE de sessions solo al creador de la sesión
     - Restringir DELETE de sessions solo al creador de la sesión
     - Restringir UPDATE/DELETE de participants solo si el usuario creó la sesión
  
  3. **Optimización de Índices**:
     - Eliminar índice no utilizado idx_participants_session_id
     - El índice idx_participants_registered_at es suficiente para nuestras queries
  
  ## Notas
  - Solo el usuario autenticado que crea una sesión puede modificarla o eliminarla
  - Los participantes pueden registrarse en sesiones activas sin autenticación
  - Solo el creador de la sesión puede modificar/eliminar participantes de esa sesión
*/

-- Agregar campo created_by a sessions
ALTER TABLE sessions ADD COLUMN IF NOT EXISTS created_by uuid REFERENCES auth.users(id);

-- Crear función para auto-llenar created_by
CREATE OR REPLACE FUNCTION set_created_by()
RETURNS TRIGGER AS $$
BEGIN
  NEW.created_by := auth.uid();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Crear trigger para auto-llenar created_by en sessions
DROP TRIGGER IF EXISTS set_sessions_created_by ON sessions;
CREATE TRIGGER set_sessions_created_by
  BEFORE INSERT ON sessions
  FOR EACH ROW
  EXECUTE FUNCTION set_created_by();

-- Actualizar sesiones existentes sin created_by (solo si existen)
UPDATE sessions SET created_by = (SELECT id FROM auth.users LIMIT 1) WHERE created_by IS NULL;

-- Eliminar índice no utilizado
DROP INDEX IF EXISTS idx_participants_session_id;

-- Eliminar políticas inseguras existentes
DROP POLICY IF EXISTS "Usuarios autenticados pueden insertar sesiones" ON sessions;
DROP POLICY IF EXISTS "Usuarios autenticados pueden actualizar sesiones" ON sessions;
DROP POLICY IF EXISTS "Usuarios autenticados pueden eliminar sesiones" ON sessions;
DROP POLICY IF EXISTS "Usuarios autenticados pueden actualizar participantes" ON participants;
DROP POLICY IF EXISTS "Usuarios autenticados pueden eliminar participantes" ON participants;

-- Crear políticas seguras para sessions basadas en ownership
CREATE POLICY "Usuarios autenticados pueden crear sesiones"
  ON sessions FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() IS NOT NULL);

CREATE POLICY "Solo el creador puede actualizar su sesión"
  ON sessions FOR UPDATE
  TO authenticated
  USING (created_by = auth.uid())
  WITH CHECK (created_by = auth.uid());

CREATE POLICY "Solo el creador puede eliminar su sesión"
  ON sessions FOR DELETE
  TO authenticated
  USING (created_by = auth.uid());

-- Crear políticas seguras para participants basadas en ownership de la sesión
CREATE POLICY "Solo el creador de la sesión puede actualizar participantes"
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

CREATE POLICY "Solo el creador de la sesión puede eliminar participantes"
  ON participants FOR DELETE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM sessions
      WHERE sessions.id = participants.session_id
      AND sessions.created_by = auth.uid()
    )
  );