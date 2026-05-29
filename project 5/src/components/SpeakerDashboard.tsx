import { useState, useEffect } from 'react';
import { QRCodeSVG } from 'qrcode.react';
import { Users, RotateCcw, QrCode, LogOut, CheckCircle, Download, UserCheck, X } from 'lucide-react';
import { supabase } from '../lib/supabase';
import type { Participant, ReparticipationRequest } from '../lib/database.types';

interface SpeakerDashboardProps {
  onLogout: () => void;
}

export default function SpeakerDashboard({ onLogout }: SpeakerDashboardProps) {
  const [sessionId, setSessionId] = useState<string | null>(null);
  const [participants, setParticipants] = useState<Participant[]>([]);
  const [participantUrl, setParticipantUrl] = useState('');
  const [reparticipationRequests, setReparticipationRequests] = useState<ReparticipationRequest[]>([]);

  const handleLogout = async () => {
    try {
      await supabase.auth.signOut();
      onLogout();
    } catch (error) {
      console.error('Error al cerrar sesion:', error);
      onLogout();
    }
  };

  const generateNewSession = async () => {
    try {
      await supabase
        .from('sessions')
        .update({ is_active: false })
        .eq('is_active', true);

      const { data: newSession, error } = await supabase
        .from('sessions')
        .insert({ is_active: true })
        .select()
        .single();

      if (error) throw error;

      if (newSession) {
        setSessionId(newSession.id);
        setParticipants([]);
        setReparticipationRequests([]);
        const url = `${window.location.origin}/participar/${newSession.id}`;
        setParticipantUrl(url);
      }
    } catch (error) {
      console.error('Error al generar sesion:', error);
    }
  };

  const renewSession = async () => {
    if (!sessionId) return;

    try {
      await supabase
        .from('sessions')
        .update({ is_active: false })
        .eq('id', sessionId);

      const { data: newSession, error } = await supabase
        .from('sessions')
        .insert({ is_active: true })
        .select()
        .single();

      if (error) throw error;

      if (newSession) {
        setSessionId(newSession.id);
        setParticipants([]);
        setReparticipationRequests([]);
        const url = `${window.location.origin}/participar/${newSession.id}`;
        setParticipantUrl(url);
      }
    } catch (error) {
      console.error('Error al renovar sesion:', error);
    }
  };

  const markAsParticipated = async (participantId: string) => {
    try {
      const { error } = await supabase
        .from('participants')
        .update({ has_participated: true })
        .eq('id', participantId);

      if (error) throw error;

      setParticipants((prev) =>
        prev.map((p) =>
          p.id === participantId ? { ...p, has_participated: true } : p
        )
      );
    } catch (error) {
      console.error('Error al marcar participante:', error);
    }
  };

  const approveRequest = async (requestId: string) => {
    try {
      const { error } = await supabase
        .from('reparticipation_requests')
        .update({ status: 'approved' })
        .eq('id', requestId);

      if (error) throw error;

      setReparticipationRequests((prev) =>
        prev.filter((r) => r.id !== requestId)
      );
    } catch (error) {
      console.error('Error al aprobar solicitud:', error);
    }
  };

  const denyRequest = async (requestId: string) => {
    try {
      const { error } = await supabase
        .from('reparticipation_requests')
        .update({ status: 'denied' })
        .eq('id', requestId);

      if (error) throw error;

      setReparticipationRequests((prev) =>
        prev.filter((r) => r.id !== requestId)
      );
    } catch (error) {
      console.error('Error al denegar solicitud:', error);
    }
  };

  const downloadCSV = () => {
    if (participants.length === 0) {
      alert('No hay participantes para descargar');
      return;
    }

    const headers = ['Nombre', 'Apellido', 'Cargo', 'Institucion', 'Participo', 'Fecha de Registro'];
    const rows = participants.map(p => [
      p.first_name,
      p.last_name,
      p.position,
      p.institution,
      p.has_participated ? 'Si' : 'No',
      new Date(p.registered_at).toLocaleString('es-ES')
    ]);

    const csvContent = [
      headers.join(','),
      ...rows.map(row => row.map(cell => `"${cell}"`).join(','))
    ].join('\n');

    const blob = new Blob([csvContent], { type: 'text/csv;charset=utf-8;' });
    const link = document.createElement('a');
    const url = URL.createObjectURL(blob);

    link.setAttribute('href', url);
    link.setAttribute('download', `participantes_sesion_${sessionId}_${new Date().toISOString().split('T')[0]}.csv`);
    link.style.visibility = 'hidden';

    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
  };

  useEffect(() => {
    if (!sessionId) return;

    const loadParticipants = async () => {
      const { data } = await supabase
        .from('participants')
        .select('*')
        .eq('session_id', sessionId)
        .order('registered_at', { ascending: true });

      if (data) {
        setParticipants(data);
      }
    };

    const loadRequests = async () => {
      const { data } = await supabase
        .from('reparticipation_requests')
        .select('*')
        .eq('session_id', sessionId)
        .eq('status', 'pending')
        .order('created_at', { ascending: true });

      if (data) {
        setReparticipationRequests(data as ReparticipationRequest[]);
      }
    };

    loadParticipants();
    loadRequests();

    const participantsChannel = supabase
      .channel(`session-${sessionId}`)
      .on(
        'postgres_changes',
        {
          event: 'INSERT',
          schema: 'public',
          table: 'participants',
          filter: `session_id=eq.${sessionId}`
        },
        (payload) => {
          setParticipants((prev) => [...prev, payload.new as Participant]);
        }
      )
      .on(
        'postgres_changes',
        {
          event: 'UPDATE',
          schema: 'public',
          table: 'participants',
          filter: `session_id=eq.${sessionId}`
        },
        (payload) => {
          setParticipants((prev) =>
            prev.map((p) => (p.id === payload.new.id ? (payload.new as Participant) : p))
          );
        }
      )
      .subscribe();

    const requestsChannel = supabase
      .channel(`reparticipation-requests-${sessionId}`)
      .on(
        'postgres_changes',
        {
          event: 'INSERT',
          schema: 'public',
          table: 'reparticipation_requests',
          filter: `session_id=eq.${sessionId}`
        },
        (payload) => {
          const newRequest = payload.new as ReparticipationRequest;
          if (newRequest.status === 'pending') {
            setReparticipationRequests((prev) => [...prev, newRequest]);
          }
        }
      )
      .subscribe();

    return () => {
      supabase.removeChannel(participantsChannel);
      supabase.removeChannel(requestsChannel);
    };
  }, [sessionId]);

  return (
    <div className="min-h-screen p-4" style={{ backgroundColor: '#0C0B0B' }}>
      <div className="max-w-7xl mx-auto">
        <div className="flex justify-between items-center mb-8">
          <img src="/FlashPick-Castoryadis_img.png" alt="FlashPick by Castoryadis" className="h-14 w-auto" />
          <button
            onClick={handleLogout}
            className="flex items-center gap-2 px-4 py-2 rounded-lg font-semibold transition-all hover:opacity-90"
            style={{ backgroundColor: '#DE3C4B', color: '#F2F2F2' }}
          >
            <LogOut className="w-4 h-4" />
            Salir
          </button>
        </div>

        {!sessionId ? (
          <div className="flex items-center justify-center h-[70vh]">
            <button
              onClick={generateNewSession}
              className="group relative overflow-hidden px-12 py-6 rounded-2xl font-bold text-xl shadow-2xl transition-all transform hover:scale-105"
              style={{ backgroundColor: '#DE3C4B', color: '#F2F2F2' }}
            >
              <div className="flex items-center gap-3">
                <QrCode className="w-8 h-8" />
                Generar QR de Pregunta
              </div>
            </button>
          </div>
        ) : (
          <div className="grid lg:grid-cols-3 gap-6">
            <div className="lg:col-span-1 space-y-6">
              <div className="rounded-2xl shadow-2xl p-6" style={{ backgroundColor: '#F2F2F2' }}>
                <h2 className="text-xl font-bold mb-4 text-center" style={{ color: '#0C0B0B' }}>
                  Codigo QR Activo
                </h2>
                <div className="bg-white p-4 rounded-xl border-4" style={{ borderColor: '#0C0B0B' }}>
                  <QRCodeSVG
                    value={participantUrl}
                    size={256}
                    level="H"
                    className="w-full h-auto"
                  />
                </div>

                <div className="mt-6 space-y-3">
                  <div className="bg-white rounded-lg p-4 flex items-center gap-3 border border-gray-200">
                    <Users className="w-5 h-5" style={{ color: '#0C0B0B' }} />
                    <div>
                      <p className="text-sm" style={{ color: '#0C0B0B' }}>Registrados</p>
                      <p className="text-2xl font-bold" style={{ color: '#0C0B0B' }}>{participants.length}</p>
                    </div>
                  </div>

                  <button
                    onClick={downloadCSV}
                    className="w-full flex items-center justify-center gap-2 px-4 py-3 rounded-lg transition-all hover:opacity-90 font-semibold"
                    style={{ backgroundColor: '#DE3C4B', color: '#F2F2F2' }}
                  >
                    <Download className="w-5 h-5" />
                    Descargar CSV
                  </button>

                  <button
                    onClick={renewSession}
                    className="w-full flex items-center justify-center gap-2 px-4 py-3 rounded-lg transition-all hover:opacity-90 font-semibold border-2"
                    style={{ backgroundColor: 'transparent', color: '#0C0B0B', borderColor: '#DE3C4B' }}
                  >
                    <RotateCcw className="w-5 h-5" />
                    Renovar QR
                  </button>
                </div>
              </div>

              {reparticipationRequests.length > 0 && (
                <div className="rounded-2xl shadow-2xl p-6" style={{ backgroundColor: '#F2F2F2' }}>
                  <h2 className="text-lg font-bold mb-4 flex items-center gap-2" style={{ color: '#0C0B0B' }}>
                    <UserCheck className="w-5 h-5 text-amber-500" />
                    Solicitudes de reparticipacion
                    <span className="bg-amber-100 text-amber-700 text-sm font-bold px-2 py-0.5 rounded-full">
                      {reparticipationRequests.length}
                    </span>
                  </h2>

                  <div className="space-y-3">
                    {reparticipationRequests.map((request) => (
                      <div
                        key={request.id}
                        className="bg-white border border-gray-200 rounded-xl p-4"
                      >
                        <p className="font-bold" style={{ color: '#0C0B0B' }}>
                          {request.first_name} {request.last_name}
                        </p>
                        <p className="text-sm mb-3" style={{ color: '#0C0B0B' }}>
                          {request.position} - {request.institution}
                        </p>
                        <div className="flex gap-2">
                          <button
                            onClick={() => approveRequest(request.id)}
                            className="flex-1 flex items-center justify-center gap-1 bg-green-500 text-white px-3 py-2 rounded-lg hover:bg-green-600 transition-colors font-semibold text-sm"
                          >
                            <CheckCircle className="w-4 h-4" />
                            Aprobar
                          </button>
                          <button
                            onClick={() => denyRequest(request.id)}
                            className="flex-1 flex items-center justify-center gap-1 px-3 py-2 rounded-lg transition-all hover:opacity-90 font-semibold text-sm"
                            style={{ backgroundColor: '#DE3C4B', color: '#F2F2F2' }}
                          >
                            <X className="w-4 h-4" />
                            Denegar
                          </button>
                        </div>
                      </div>
                    ))}
                  </div>
                </div>
              )}
            </div>

            <div className="lg:col-span-2 rounded-2xl shadow-2xl p-6" style={{ backgroundColor: '#F2F2F2' }}>
              <h2 className="text-2xl font-bold mb-6 flex items-center gap-2" style={{ color: '#0C0B0B' }}>
                <Users className="w-7 h-7" style={{ color: '#DE3C4B' }} />
                Participantes Registrados
              </h2>

              {participants.length === 0 ? (
                <div className="text-center py-12" style={{ color: '#0C0B0B' }}>
                  <Users className="w-16 h-16 mx-auto mb-4 opacity-30" />
                  <p className="text-lg opacity-60">Esperando participantes...</p>
                </div>
              ) : (
                <div className="space-y-3">
                  {participants
                    .sort((a, b) => {
                      if (a.has_participated === b.has_participated) {
                        return new Date(a.registered_at).getTime() - new Date(b.registered_at).getTime();
                      }
                      return a.has_participated ? 1 : -1;
                    })
                    .map((participant, index) => (
                      <div
                        key={participant.id}
                        className={`flex items-center gap-4 p-4 rounded-xl transition-all ${
                          participant.has_participated
                            ? 'bg-gray-200 opacity-60'
                            : 'bg-white border-2 border-gray-200'
                        }`}
                      >
                        <div
                          className="flex items-center justify-center w-12 h-12 rounded-full font-bold text-lg"
                          style={{
                            backgroundColor: participant.has_participated ? '#ccc' : '#DE3C4B',
                            color: participant.has_participated ? '#666' : '#F2F2F2'
                          }}
                        >
                          {index + 1}
                        </div>
                        <div className="flex-1">
                          <p className="font-bold text-lg" style={{ color: '#0C0B0B' }}>
                            {participant.first_name} {participant.last_name}
                          </p>
                          <p className="text-sm" style={{ color: '#0C0B0B' }}>
                            {participant.position} - {participant.institution}
                          </p>
                          <p className="text-xs mt-1 opacity-60" style={{ color: '#0C0B0B' }}>
                            {new Date(participant.registered_at).toLocaleTimeString('es-ES', {
                              hour: '2-digit',
                              minute: '2-digit',
                              second: '2-digit'
                            })}.{new Date(participant.registered_at).getMilliseconds().toString().padStart(3, '0')}
                          </p>
                        </div>
                        {!participant.has_participated && (
                          <button
                            onClick={() => markAsParticipated(participant.id)}
                            className="flex items-center gap-2 px-4 py-2 rounded-lg font-semibold transition-all hover:opacity-90"
                            style={{ backgroundColor: '#DE3C4B', color: '#F2F2F2' }}
                          >
                            <CheckCircle className="w-4 h-4" />
                            Ya participo
                          </button>
                        )}
                      </div>
                    ))}
                </div>
              )}
            </div>
          </div>
        )}
      </div>
    </div>
  );
}
