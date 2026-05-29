/*
  # Agregar identificador único de participante para reingreso

  ## Descripción
  
  Esta migración agrega un campo `participant_uuid` a la tabla `participants` para permitir
  identificar de manera única a los usuarios que regresan a participar en una misma sesión.

  ## Cambios Realizados

  1. **Nueva Columna**:
     - `participant_uuid` (text): Identificador único del participante generado en el cliente
     - Este campo permite reconocer a un usuario cuando vuelve a escanear el QR de la misma sesión
     - No es obligatorio para mantener compatibilidad con registros existentes

  2. **Índice de Rendimiento**:
     - `idx_participants_session_uuid`: Índice compuesto para búsquedas rápidas
     - Optimiza las consultas que buscan si un usuario ya participó en una sesión específica

  ## Notas Importantes

  - El campo es opcional (nullable) para no afectar registros existentes
  - El índice mejora el rendimiento al buscar participaciones previas del usuario en la sesión
  - Este cambio habilita la funcionalidad de "Volver a ponerme en lista"
*/

-- Agregar columna participant_uuid a la tabla participants
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'participants' AND column_name = 'participant_uuid'
  ) THEN
    ALTER TABLE participants ADD COLUMN participant_uuid text;
  END IF;
END $$;

-- Crear índice compuesto para búsquedas rápidas de usuarios en sesiones
CREATE INDEX IF NOT EXISTS idx_participants_session_uuid 
  ON participants(session_id, participant_uuid);