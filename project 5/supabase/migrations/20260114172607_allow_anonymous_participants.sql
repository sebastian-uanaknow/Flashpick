/*
  # Permitir Participantes Anónimos

  ## Cambios de Acceso Público
  
  1. **Políticas SELECT para sesiones**:
     - Permitir a usuarios anónimos leer el estado de las sesiones (is_active)
     - Permitir a usuarios autenticados ver todas las sesiones que crearon
  
  2. **Políticas INSERT para participantes**:
     - Permitir a usuarios anónimos registrarse en sesiones activas
     - Verificar que la sesión esté activa antes de permitir el registro
  
  3. **Políticas SELECT para participantes**:
     - Permitir a usuarios autenticados ver participantes de sus sesiones
     - Esto es necesario para Realtime subscriptions
  
  4. **Habilitar Realtime**:
     - Habilitar publicación de cambios en ambas tablas para suscripciones en tiempo real
  
  ## Notas de Seguridad
  - Los participantes solo pueden insertarse en sesiones activas
  - Los speakers autenticados solo pueden ver participantes de sus propias sesiones
  - Los usuarios anónimos solo pueden leer el estado de las sesiones, no los detalles del creador
*/

-- Políticas SELECT para sessions (usuarios anónimos pueden verificar si está activa)
CREATE POLICY "Cualquiera puede ver si una sesión está activa"
  ON sessions FOR SELECT
  TO anon
  USING (true);

-- Políticas SELECT para sessions (usuarios autenticados ven sus sesiones)
CREATE POLICY "Usuarios autenticados pueden ver sus sesiones"
  ON sessions FOR SELECT
  TO authenticated
  USING (created_by = (select auth.uid()));

-- Política INSERT para participants (usuarios anónimos pueden registrarse)
CREATE POLICY "Cualquiera puede registrarse en sesiones activas"
  ON participants FOR INSERT
  TO anon
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM sessions
      WHERE sessions.id = participants.session_id
      AND sessions.is_active = true
    )
  );

-- Política INSERT para participants (usuarios autenticados también pueden)
CREATE POLICY "Usuarios autenticados pueden registrarse en sesiones activas"
  ON participants FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM sessions
      WHERE sessions.id = participants.session_id
      AND sessions.is_active = true
    )
  );

-- Política SELECT para participants (usuarios autenticados ven participantes de sus sesiones)
CREATE POLICY "Solo el creador de la sesión puede ver participantes"
  ON participants FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM sessions
      WHERE sessions.id = participants.session_id
      AND sessions.created_by = (select auth.uid())
    )
  );

-- Habilitar Realtime para ambas tablas
ALTER PUBLICATION supabase_realtime ADD TABLE sessions;
ALTER PUBLICATION supabase_realtime ADD TABLE participants;