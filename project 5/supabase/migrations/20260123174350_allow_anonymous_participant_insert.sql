/*
  # Permitir inserción anónima de participantes

  ## Descripción
  
  Esta migración permite que usuarios no autenticados (anónimos) puedan registrarse
  como participantes en sesiones activas. Los participantes NO necesitan estar logueados
  para escanear un QR y unirse a una sesión.

  ## Cambios Realizados

  1. **Nueva Política de Inserción Anónima**:
     - Permite a cualquier usuario (anónimo o público) insertar registros en `participants`
     - Valida que la sesión esté activa antes de permitir la inserción
     - Esta es la política que faltaba y causaba el error de registro

  ## Notas Importantes

  - Los participantes son anónimos por diseño
  - Solo el creador de la sesión (autenticado) puede ver/editar/eliminar participantes
  - La validación de sesión activa previene registros en sesiones cerradas
*/

-- Política INSERT: Permitir a cualquier usuario registrarse en sesiones activas
DROP POLICY IF EXISTS "Cualquiera puede registrarse en sesiones activas" ON participants;
CREATE POLICY "Cualquiera puede registrarse en sesiones activas"
  ON participants FOR INSERT
  TO anon, authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM sessions
      WHERE sessions.id = participants.session_id
      AND sessions.is_active = true
    )
  );