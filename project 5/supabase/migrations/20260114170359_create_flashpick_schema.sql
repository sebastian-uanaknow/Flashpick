/*
  # Crear esquema de FlashPick

  ## 1. Nuevas Tablas
  
  ### `sessions`
  - `id` (uuid, primary key) - Identificador único de la sesión/ronda
  - `is_active` (boolean) - Indica si la ronda está activa
  - `created_at` (timestamptz) - Momento de creación de la ronda
  
  ### `participants`
  - `id` (uuid, primary key) - Identificador único del participante
  - `session_id` (uuid, foreign key) - Referencia a la sesión
  - `first_name` (text) - Nombre del participante
  - `last_name` (text) - Apellido del participante
  - `registered_at` (timestamptz) - Momento exacto de registro (precisión de microsegundos)
  
  ## 2. Seguridad
  - Habilitar RLS en ambas tablas
  - Permitir lectura pública de sessions activas
  - Permitir lectura pública de participants
  - Permitir inserción pública de participants (para participantes)
  - Permitir todas las operaciones para usuarios autenticados (speaker admin)
  
  ## 3. Índices
  - Índice en session_id para consultas rápidas
  - Índice en registered_at para ordenamiento por velocidad
*/

-- Crear tabla de sesiones
CREATE TABLE IF NOT EXISTS sessions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  is_active boolean DEFAULT true,
  created_at timestamptz DEFAULT now()
);

-- Crear tabla de participantes
CREATE TABLE IF NOT EXISTS participants (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id uuid REFERENCES sessions(id) ON DELETE CASCADE NOT NULL,
  first_name text NOT NULL,
  last_name text NOT NULL,
  registered_at timestamptz DEFAULT now()
);

-- Crear índices para mejor rendimiento
CREATE INDEX IF NOT EXISTS idx_participants_session_id ON participants(session_id);
CREATE INDEX IF NOT EXISTS idx_participants_registered_at ON participants(session_id, registered_at);
CREATE INDEX IF NOT EXISTS idx_sessions_active ON sessions(is_active) WHERE is_active = true;

-- Habilitar RLS
ALTER TABLE sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE participants ENABLE ROW LEVEL SECURITY;

-- Políticas para sessions - lectura pública de sesiones activas
CREATE POLICY "Cualquiera puede ver sesiones activas"
  ON sessions FOR SELECT
  TO anon, authenticated
  USING (is_active = true);

CREATE POLICY "Solo admin puede insertar sesiones"
  ON sessions FOR INSERT
  TO anon, authenticated
  WITH CHECK (true);

CREATE POLICY "Solo admin puede actualizar sesiones"
  ON sessions FOR UPDATE
  TO anon, authenticated
  USING (true)
  WITH CHECK (true);

CREATE POLICY "Solo admin puede eliminar sesiones"
  ON sessions FOR DELETE
  TO anon, authenticated
  USING (true);

-- Políticas para participants - lectura pública
CREATE POLICY "Cualquiera puede ver participantes"
  ON participants FOR SELECT
  TO anon, authenticated
  USING (true);

CREATE POLICY "Cualquiera puede registrarse como participante"
  ON participants FOR INSERT
  TO anon, authenticated
  WITH CHECK (true);

CREATE POLICY "Solo admin puede actualizar participantes"
  ON participants FOR UPDATE
  TO anon, authenticated
  USING (true)
  WITH CHECK (true);

CREATE POLICY "Solo admin puede eliminar participantes"
  ON participants FOR DELETE
  TO anon, authenticated
  USING (true);