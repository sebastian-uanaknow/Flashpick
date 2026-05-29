/*
  # Habilitar Realtime para Participantes y Sessions

  ## Cambios de Configuración

  1. **Habilitar Realtime**:
     - Asegurar que las tablas sessions y participants estén habilitadas para Realtime
     - Esto permite que el dashboard del speaker reciba actualizaciones en tiempo real
  
  ## Notas Técnicas
  - Realtime respeta las políticas RLS
  - El speaker autenticado podrá ver participantes de sus propias sesiones en tiempo real
  - Los usuarios anónimos no podrán suscribirse a cambios de participantes (por seguridad)
  - Si las tablas ya están en la publicación, este comando no causará error
*/

-- Asegurar que Realtime esté habilitado para sessions y participants
DO $$
BEGIN
  -- Agregar sessions a la publicación de Realtime si no está ya
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables 
    WHERE pubname = 'supabase_realtime' 
    AND schemaname = 'public' 
    AND tablename = 'sessions'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE sessions;
  END IF;

  -- Agregar participants a la publicación de Realtime si no está ya
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables 
    WHERE pubname = 'supabase_realtime' 
    AND schemaname = 'public' 
    AND tablename = 'participants'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE participants;
  END IF;
END $$;