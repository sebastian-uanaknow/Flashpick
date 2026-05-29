/*
  # Corregir Políticas de Seguridad RLS

  ## Cambios de Seguridad
  
  1. **Políticas de sessions**:
     - Eliminar políticas que permiten acceso sin restricciones a usuarios anónimos
     - Restringir INSERT/UPDATE/DELETE solo a usuarios autenticados
     - Mantener SELECT público solo para sesiones activas
  
  2. **Políticas de participants**:
     - Mejorar política de INSERT para validar que la sesión esté activa (no solo true)
     - Restringir UPDATE/DELETE solo a usuarios autenticados
     - Mantener SELECT público para todos
  
  3. **Índices**:
     - Mantener índices existentes ya que son útiles para las consultas
  
  ## Notas Importantes
  - Los speakers deben autenticarse con Supabase antes de gestionar sesiones
  - Los participantes pueden registrarse sin autenticación si la sesión está activa
  - Solo usuarios autenticados pueden modificar o eliminar datos
*/

-- Eliminar políticas inseguras existentes
DROP POLICY IF EXISTS "Solo admin puede insertar sesiones" ON sessions;
DROP POLICY IF EXISTS "Solo admin puede actualizar sesiones" ON sessions;
DROP POLICY IF EXISTS "Solo admin puede eliminar sesiones" ON sessions;
DROP POLICY IF EXISTS "Cualquiera puede registrarse como participante" ON participants;
DROP POLICY IF EXISTS "Solo admin puede actualizar participantes" ON participants;
DROP POLICY IF EXISTS "Solo admin puede eliminar participantes" ON participants;

-- Crear políticas seguras para sessions
CREATE POLICY "Usuarios autenticados pueden insertar sesiones"
  ON sessions FOR INSERT
  TO authenticated
  WITH CHECK (true);

CREATE POLICY "Usuarios autenticados pueden actualizar sesiones"
  ON sessions FOR UPDATE
  TO authenticated
  USING (true)
  WITH CHECK (true);

CREATE POLICY "Usuarios autenticados pueden eliminar sesiones"
  ON sessions FOR DELETE
  TO authenticated
  USING (true);

-- Crear políticas seguras para participants
CREATE POLICY "Usuarios pueden registrarse en sesiones activas"
  ON participants FOR INSERT
  TO anon, authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM sessions
      WHERE sessions.id = session_id
      AND sessions.is_active = true
    )
  );

CREATE POLICY "Usuarios autenticados pueden actualizar participantes"
  ON participants FOR UPDATE
  TO authenticated
  USING (true)
  WITH CHECK (true);

CREATE POLICY "Usuarios autenticados pueden eliminar participantes"
  ON participants FOR DELETE
  TO authenticated
  USING (true);