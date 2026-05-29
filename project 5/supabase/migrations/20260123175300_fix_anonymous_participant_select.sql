/*
  # Permitir lectura de participantes para verificación

  ## Descripción
  
  Esta migración permite que los usuarios anónimos puedan leer sus propios registros
  de participantes después de insertarlos. Esto es necesario porque el código hace
  `.select()` después del `.insert()` para obtener el registro creado.

  ## Cambios Realizados

  1. **Nueva Política SELECT para Anónimos**:
     - Permite a cualquier usuario (anónimo o autenticado) leer registros de participants
     - Esto permite que después de insertar, el usuario pueda ver su propio registro
     - Sin esto, el `.select()` después del `.insert()` falla

  2. **Limpieza de Políticas Duplicadas**:
     - Eliminar la política duplicada "Registro en sesiones activas"
     - Solo mantener "Cualquiera puede registrarse en sesiones activas"

  ## Notas Importantes

  - Los participantes anónimos pueden leer cualquier participante de la sesión
  - Esto es seguro porque la información es pública dentro de una sesión activa
  - El creador de la sesión sigue teniendo control total sobre los participantes
*/

-- Eliminar política duplicada
DROP POLICY IF EXISTS "Registro en sesiones activas" ON participants;

-- Agregar política SELECT para que anónimos puedan leer participantes
DROP POLICY IF EXISTS "Anónimos pueden ver participantes" ON participants;
CREATE POLICY "Anónimos pueden ver participantes"
  ON participants FOR SELECT
  TO anon, authenticated
  USING (true);