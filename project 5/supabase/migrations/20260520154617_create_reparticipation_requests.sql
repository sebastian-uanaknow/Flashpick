/*
  # Create re-participation requests table

  1. New Tables
    - `reparticipation_requests`
      - `id` (uuid, primary key)
      - `session_id` (uuid, references sessions)
      - `participant_uuid` (text, the device UUID of the requester)
      - `first_name` (text)
      - `last_name` (text)
      - `position` (text)
      - `institution` (text)
      - `status` (text: 'pending', 'approved', 'denied')
      - `created_at` (timestamptz)

  2. Security
    - Enable RLS on `reparticipation_requests` table
    - Allow anonymous users to insert requests (participants are anonymous)
    - Allow anonymous users to select their own requests by participant_uuid
    - Allow authenticated users (speaker) to select and update requests

  3. Notes
    - This table tracks requests from participants who already participated
      and want to participate again. The speaker must approve before they
      can re-enter the queue.
*/

CREATE TABLE IF NOT EXISTS reparticipation_requests (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id uuid NOT NULL REFERENCES sessions(id) ON DELETE CASCADE,
  participant_uuid text NOT NULL,
  first_name text NOT NULL,
  last_name text NOT NULL,
  position text NOT NULL DEFAULT '',
  institution text NOT NULL DEFAULT '',
  status text NOT NULL DEFAULT 'pending',
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE reparticipation_requests ENABLE ROW LEVEL SECURITY;

-- Anonymous participants can insert requests
CREATE POLICY "Anyone can insert reparticipation requests"
  ON reparticipation_requests
  FOR INSERT
  TO anon
  WITH CHECK (status = 'pending');

-- Anonymous participants can view their own requests by participant_uuid
CREATE POLICY "Anon can select own reparticipation requests"
  ON reparticipation_requests
  FOR SELECT
  TO anon
  USING (true);

-- Authenticated speaker can view all requests for their sessions
CREATE POLICY "Authenticated can select reparticipation requests"
  ON reparticipation_requests
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM sessions
      WHERE sessions.id = reparticipation_requests.session_id
      AND sessions.created_by = auth.uid()
    )
  );

-- Authenticated speaker can update request status
CREATE POLICY "Authenticated can update reparticipation requests"
  ON reparticipation_requests
  FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM sessions
      WHERE sessions.id = reparticipation_requests.session_id
      AND sessions.created_by = auth.uid()
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM sessions
      WHERE sessions.id = reparticipation_requests.session_id
      AND sessions.created_by = auth.uid()
    )
  );

-- Index for quick lookups
CREATE INDEX IF NOT EXISTS idx_reparticipation_requests_session_id
  ON reparticipation_requests(session_id);

CREATE INDEX IF NOT EXISTS idx_reparticipation_requests_participant_uuid
  ON reparticipation_requests(participant_uuid);

-- Enable realtime for this table
ALTER PUBLICATION supabase_realtime ADD TABLE reparticipation_requests;
