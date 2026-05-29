/*
  # Agregar Campos de Cargo e Institución a Participantes

  ## Cambios en la Tabla
  
  1. **Nuevos Campos en participants**:
     - `position` (text): Cargo del participante
     - `institution` (text): Institución o empresa que representa
     - `has_participated` (boolean): Indica si ya participó (para marcar como completado)
  
  2. **Valores por defecto**:
     - position: cadena vacía
     - institution: cadena vacía
     - has_participated: false (por defecto no ha participado)
  
  ## Notas
  - Estos campos son opcionales pero se almacenarán como cadenas vacías por defecto
  - El campo has_participated permite al speaker marcar quién ya participó
*/

-- Agregar nuevos campos a la tabla participants
ALTER TABLE participants 
  ADD COLUMN IF NOT EXISTS position text DEFAULT '' NOT NULL,
  ADD COLUMN IF NOT EXISTS institution text DEFAULT '' NOT NULL,
  ADD COLUMN IF NOT EXISTS has_participated boolean DEFAULT false NOT NULL;