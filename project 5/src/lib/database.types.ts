export type Json =
  | string
  | number
  | boolean
  | null
  | { [key: string]: Json | undefined }
  | Json[]

export interface Database {
  public: {
    Tables: {
      sessions: {
        Row: {
          id: string
          is_active: boolean
          created_at: string
          created_by: string | null
        }
        Insert: {
          id?: string
          is_active?: boolean
          created_at?: string
          created_by?: string | null
        }
        Update: {
          id?: string
          is_active?: boolean
          created_at?: string
          created_by?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "sessions_created_by_fkey"
            columns: ["created_by"]
            isOneToOne: false
            referencedRelation: "users"
            referencedColumns: ["id"]
          }
        ]
      }
      participants: {
        Row: {
          id: string
          session_id: string
          first_name: string
          last_name: string
          position: string
          institution: string
          has_participated: boolean
          registered_at: string
          participant_uuid: string | null
        }
        Insert: {
          id?: string
          session_id: string
          first_name: string
          last_name: string
          position?: string
          institution?: string
          has_participated?: boolean
          registered_at?: string
          participant_uuid?: string | null
        }
        Update: {
          id?: string
          session_id?: string
          first_name?: string
          last_name?: string
          position?: string
          institution?: string
          has_participated?: boolean
          registered_at?: string
          participant_uuid?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "participants_session_id_fkey"
            columns: ["session_id"]
            isOneToOne: false
            referencedRelation: "sessions"
            referencedColumns: ["id"]
          }
        ]
      }
      reparticipation_requests: {
        Row: {
          id: string
          session_id: string
          participant_uuid: string
          first_name: string
          last_name: string
          position: string
          institution: string
          status: 'pending' | 'approved' | 'denied'
          created_at: string
        }
        Insert: {
          id?: string
          session_id: string
          participant_uuid: string
          first_name: string
          last_name: string
          position?: string
          institution?: string
          status?: string
          created_at?: string
        }
        Update: {
          id?: string
          session_id?: string
          participant_uuid?: string
          first_name?: string
          last_name?: string
          position?: string
          institution?: string
          status?: string
          created_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "reparticipation_requests_session_id_fkey"
            columns: ["session_id"]
            isOneToOne: false
            referencedRelation: "sessions"
            referencedColumns: ["id"]
          }
        ]
      }
    }
    Views: {
      [_ in never]: never
    }
    Functions: {
      [_ in never]: never
    }
    Enums: {
      [_ in never]: never
    }
    CompositeTypes: {
      [_ in never]: never
    }
  }
}

export type Session = Database['public']['Tables']['sessions']['Row'];
export type Participant = Database['public']['Tables']['participants']['Row'];
export type ReparticipationRequest = Database['public']['Tables']['reparticipation_requests']['Row'];
