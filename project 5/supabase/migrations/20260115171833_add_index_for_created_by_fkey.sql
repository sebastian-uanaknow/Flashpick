/*
  # Agregar Índice para Foreign Key created_by

  ## Cambios de Optimización

  1. **Crear Índice para sessions.created_by**:
     - Agregar índice en la columna created_by para mejorar el rendimiento de queries
     - Este índice optimiza las búsquedas de sesiones por usuario
     - Mejora el rendimiento de las políticas RLS que verifican ownership
  
  ## Notas de Rendimiento
  - El índice acelera las consultas que filtran por created_by
  - Mejora el rendimiento de las políticas RLS que verifican sessions.created_by = auth.uid()
  - Optimiza las joins entre sessions y participants cuando se verifica ownership
*/

-- Crear índice para la columna created_by en sessions
CREATE INDEX IF NOT EXISTS idx_sessions_created_by ON sessions(created_by);