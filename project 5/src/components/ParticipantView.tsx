import { useState, useEffect } from 'react';
import { supabase } from '../lib/supabase';
import type { Participant, ReparticipationRequest } from '../lib/database.types';

interface ParticipantViewProps {
  sessionId: string;
}

function getOrCreateParticipantUUID(): string {
  const storageKey = 'flashpick_participant_uuid';
  let uuid = localStorage.getItem(storageKey);

  if (!uuid) {
    uuid = crypto.randomUUID();
    localStorage.setItem(storageKey, uuid);
  }

  return uuid;
}

export default function ParticipantView({ sessionId }: ParticipantViewProps) {
  const [firstName, setFirstName] = useState('');
  const [lastName, setLastName] = useState('');
  const [position, setPosition] = useState('');
  const [institution, setInstitution] = useState('');
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [registrationPosition, setRegistrationPosition] = useState<number | null>(null);
  const [isSessionActive, setIsSessionActive] = useState(true);
  const [previousParticipation, setPreviousParticipation] = useState<Participant | null>(null);
  const [isCheckingPrevious, setIsCheckingPrevious] = useState(true);
  const [currentParticipant, setCurrentParticipant] = useState<Participant | null>(null);
  const [hasParticipated, setHasParticipated] = useState(false);
  const [reparticipationRequest, setReparticipationRequest] = useState<ReparticipationRequest | null>(null);

  useEffect(() => {
    const checkSession = async () => {
      const { data } = await supabase
        .from('sessions')
        .select('is_active')
        .eq('id', sessionId)
        .maybeSingle();

      if (!data || !data.is_active) {
        setIsSessionActive(false);
      }
    };

    const checkPreviousParticipation = async () => {
      const participantUUID = getOrCreateParticipantUUID();

      const { data } = await supabase
        .from('participants')
        .select('*')
        .eq('session_id', sessionId)
        .eq('participant_uuid', participantUUID)
        .order('registered_at', { ascending: false })
        .limit(1)
        .maybeSingle();

      if (data) {
        setPreviousParticipation(data);

        const { data: requestData } = await supabase
          .from('reparticipation_requests')
          .select('*')
          .eq('session_id', sessionId)
          .eq('participant_uuid', participantUUID)
          .in('status', ['pending', 'denied'])
          .order('created_at', { ascending: false })
          .limit(1)
          .maybeSingle();

        if (requestData) {
          setReparticipationRequest(requestData as ReparticipationRequest);
        }
      }

      setIsCheckingPrevious(false);
    };

    checkSession();
    checkPreviousParticipation();

    const channel = supabase
      .channel(`session-status-${sessionId}`)
      .on(
        'postgres_changes',
        {
          event: 'UPDATE',
          schema: 'public',
          table: 'sessions',
          filter: `id=eq.${sessionId}`
        },
        (payload) => {
          if (!payload.new.is_active) {
            setIsSessionActive(false);
          }
        }
      )
      .subscribe();

    return () => {
      supabase.removeChannel(channel);
    };
  }, [sessionId]);

  useEffect(() => {
    if (!currentParticipant) return;

    const channel = supabase
      .channel(`participant-${currentParticipant.id}`)
      .on(
        'postgres_changes',
        {
          event: 'UPDATE',
          schema: 'public',
          table: 'participants',
          filter: `id=eq.${currentParticipant.id}`
        },
        (payload) => {
          const updatedParticipant = payload.new as Participant;
          if (updatedParticipant.has_participated) {
            setHasParticipated(true);
            setRegistrationPosition(null);
            setReparticipationRequest(null);
            setIsSubmitting(false);
          }
        }
      )
      .subscribe();

    return () => {
      supabase.removeChannel(channel);
    };
  }, [currentParticipant]);

  useEffect(() => {
    if (!reparticipationRequest) return;

    const channel = supabase
      .channel(`reparticipation-${reparticipationRequest.id}`)
      .on(
        'postgres_changes',
        {
          event: 'UPDATE',
          schema: 'public',
          table: 'reparticipation_requests',
          filter: `id=eq.${reparticipationRequest.id}`
        },
        async (payload) => {
          const updated = payload.new as ReparticipationRequest;
          setReparticipationRequest(updated);

          if (updated.status === 'approved') {
            const participantUUID = getOrCreateParticipantUUID();
            const { data: insertedData } = await supabase
              .from('participants')
              .insert({
                session_id: sessionId,
                first_name: updated.first_name,
                last_name: updated.last_name,
                position: updated.position,
                institution: updated.institution,
                participant_uuid: participantUUID
              })
              .select()
              .single();

            if (insertedData) {
              setHasParticipated(false);
              setCurrentParticipant(insertedData);
              setRegistrationPosition(1);
              setReparticipationRequest(null);
            }
          }
        }
      )
      .subscribe();

    return () => {
      supabase.removeChannel(channel);
    };
  }, [reparticipationRequest, sessionId]);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();

    if (!firstName.trim() || !lastName.trim() || !position.trim() || !institution.trim()) {
      return;
    }

    setIsSubmitting(true);

    try {
      const participantUUID = getOrCreateParticipantUUID();

      const { data, error } = await supabase
        .from('participants')
        .insert({
          session_id: sessionId,
          first_name: firstName.trim(),
          last_name: lastName.trim(),
          position: position.trim(),
          institution: institution.trim(),
          participant_uuid: participantUUID
        })
        .select()
        .single();

      if (error) throw error;

      if (data) {
        setCurrentParticipant(data);
      }

      setRegistrationPosition(1);
    } catch (error) {
      console.error('Error al registrarse:', error);
      alert('Hubo un error al registrarte. Por favor intenta de nuevo.');
      setIsSubmitting(false);
    }
  };

  const handleRequestReparticipation = async () => {
    const participantData = currentParticipant || previousParticipation;
    if (!participantData) return;

    setIsSubmitting(true);

    try {
      const participantUUID = getOrCreateParticipantUUID();

      const { data, error } = await supabase
        .from('reparticipation_requests')
        .insert({
          session_id: sessionId,
          participant_uuid: participantUUID,
          first_name: participantData.first_name,
          last_name: participantData.last_name,
          position: participantData.position,
          institution: participantData.institution
        })
        .select()
        .single();

      if (error) throw error;

      if (data) {
        setReparticipationRequest(data as ReparticipationRequest);
      }
    } catch (error) {
      console.error('Error al solicitar reparticipacion:', error);
      alert('Hubo un error al enviar tu solicitud. Intenta de nuevo.');
    } finally {
      setIsSubmitting(false);
    }
  };

  if (!isSessionActive) {
    return (
      <div className="min-h-screen flex items-center justify-center p-4" style={{ backgroundColor: '#0C0B0B' }}>
        <div className="text-center">
          <img src="/FlashPick-Castoryadis_img.png" alt="FlashPick by Castoryadis" className="h-20 w-auto mx-auto mb-8" />
          <h2 className="text-3xl font-bold text-white mb-3">
            Esperando la pregunta del speaker...
          </h2>
          <p className="text-white/70 text-lg">
            La sesion esta inactiva. Por favor espera.
          </p>
        </div>
      </div>
    );
  }

  if (isCheckingPrevious) {
    return (
      <div className="min-h-screen flex items-center justify-center p-4" style={{ backgroundColor: '#0C0B0B' }}>
        <div className="text-center">
          <img src="/FlashPick-Castoryadis_img.png" alt="FlashPick by Castoryadis" className="h-16 w-auto mx-auto mb-6 animate-pulse" />
          <p className="text-white text-lg">Cargando...</p>
        </div>
      </div>
    );
  }

  // Participant already participated and has a pending/denied request
  if ((hasParticipated || previousParticipation?.has_participated) && reparticipationRequest) {
    const status = reparticipationRequest.status;

    return (
      <div className="min-h-screen flex items-center justify-center p-4" style={{ backgroundColor: '#0C0B0B' }}>
        <div className="w-full max-w-md">
          <div className="text-center mb-8">
            <img src="/FlashPick-Castoryadis_img.png" alt="FlashPick by Castoryadis" className="h-16 w-auto mx-auto" />
          </div>

          <div className="rounded-2xl shadow-2xl p-8" style={{ backgroundColor: '#F2F2F2' }}>
            {status === 'pending' && (
              <div className="text-center">
                <div className="w-16 h-16 rounded-full bg-amber-100 flex items-center justify-center mx-auto mb-4">
                  <div className="w-4 h-4 rounded-full bg-amber-500 animate-pulse" />
                </div>
                <h2 className="text-2xl font-bold mb-2" style={{ color: '#0C0B0B' }}>
                  Solicitud enviada
                </h2>
                <p className="mb-4" style={{ color: '#0C0B0B' }}>
                  Tu solicitud para volver a participar ha sido enviada. Espera a que el speaker la apruebe.
                </p>
                <div className="bg-amber-50 border border-amber-200 rounded-lg p-4">
                  <p className="text-amber-800 text-sm font-medium">
                    Pendiente de aprobacion...
                  </p>
                </div>
              </div>
            )}

            {status === 'denied' && (
              <div className="text-center">
                <div className="w-16 h-16 rounded-full bg-red-100 flex items-center justify-center mx-auto mb-4">
                  <div className="w-6 h-0.5 bg-red-500 rotate-45 absolute" />
                  <div className="w-6 h-0.5 bg-red-500 -rotate-45 absolute" />
                </div>
                <h2 className="text-2xl font-bold mb-2" style={{ color: '#0C0B0B' }}>
                  Solicitud denegada
                </h2>
                <p style={{ color: '#0C0B0B' }}>
                  El speaker ha denegado tu solicitud. No es posible volver a participar en esta sesion.
                </p>
              </div>
            )}
          </div>
        </div>
      </div>
    );
  }

  // Participant already participated - show request button
  if (hasParticipated && currentParticipant) {
    return (
      <div className="min-h-screen flex items-center justify-center p-4" style={{ backgroundColor: '#0C0B0B' }}>
        <div className="w-full max-w-md">
          <div className="text-center mb-8">
            <img src="/FlashPick-Castoryadis_img.png" alt="FlashPick by Castoryadis" className="h-16 w-auto mx-auto mb-4" />
            <p className="text-white/70 text-lg">Ya participaste</p>
          </div>

          <div className="rounded-2xl shadow-2xl p-8" style={{ backgroundColor: '#F2F2F2' }}>
            <div className="mb-6">
              <h2 className="text-2xl font-bold mb-4 text-center" style={{ color: '#0C0B0B' }}>
                Gracias por participar
              </h2>
              <div className="bg-white rounded-lg p-4 border border-gray-200">
                <p className="text-center" style={{ color: '#0C0B0B' }}>
                  El speaker ha registrado tu participacion
                </p>
              </div>
            </div>

            <button
              onClick={handleRequestReparticipation}
              disabled={isSubmitting}
              className="w-full py-4 rounded-lg font-bold text-xl transition-all transform hover:scale-105 shadow-lg disabled:opacity-50 disabled:cursor-not-allowed disabled:transform-none"
              style={{ backgroundColor: '#DE3C4B', color: '#F2F2F2' }}
            >
              {isSubmitting ? 'Enviando...' : 'Solicitar nueva participacion'}
            </button>

            <p className="text-center text-sm mt-4" style={{ color: '#0C0B0B' }}>
              El speaker debe aprobar tu solicitud
            </p>
          </div>
        </div>
      </div>
    );
  }

  // Registered and waiting
  if (registrationPosition !== null) {
    return (
      <div className="min-h-screen flex items-center justify-center p-4" style={{ backgroundColor: '#0C0B0B' }}>
        <div className="text-center">
          <img src="/FlashPick-Castoryadis_img.png" alt="FlashPick by Castoryadis" className="h-20 w-auto mx-auto mb-8" />
          <h2 className="text-4xl font-bold text-white mb-4">
            Registro Completado
          </h2>
          <div className="rounded-2xl p-8 inline-block" style={{ backgroundColor: '#F2F2F2' }}>
            <p className="text-lg mb-2" style={{ color: '#0C0B0B' }}>
              Tu informacion ha sido registrada correctamente
            </p>
            <p className="text-sm mt-4 opacity-70" style={{ color: '#0C0B0B' }}>
              El speaker te contactara pronto
            </p>
          </div>
        </div>
      </div>
    );
  }

  // Previous participation exists - show re-request option
  if (previousParticipation) {
    return (
      <div className="min-h-screen flex items-center justify-center p-4" style={{ backgroundColor: '#0C0B0B' }}>
        <div className="w-full max-w-md">
          <div className="text-center mb-8">
            <img src="/FlashPick-Castoryadis_img.png" alt="FlashPick by Castoryadis" className="h-16 w-auto mx-auto mb-4" />
            <p className="text-white/70 text-lg">Bienvenido de nuevo</p>
          </div>

          <div className="rounded-2xl shadow-2xl p-8" style={{ backgroundColor: '#F2F2F2' }}>
            <div className="mb-6">
              <h2 className="text-2xl font-bold mb-4 text-center" style={{ color: '#0C0B0B' }}>
                Ya participaste antes
              </h2>
              <div className="bg-white rounded-lg p-4 space-y-2 border border-gray-200">
                <p style={{ color: '#0C0B0B' }}>
                  <span className="font-semibold">Nombre:</span>{' '}
                  {previousParticipation.first_name} {previousParticipation.last_name}
                </p>
                <p style={{ color: '#0C0B0B' }}>
                  <span className="font-semibold">Cargo:</span>{' '}
                  {previousParticipation.position}
                </p>
                <p style={{ color: '#0C0B0B' }}>
                  <span className="font-semibold">Institucion:</span>{' '}
                  {previousParticipation.institution}
                </p>
              </div>
            </div>

            <button
              onClick={handleRequestReparticipation}
              disabled={isSubmitting}
              className="w-full py-4 rounded-lg font-bold text-xl transition-all transform hover:scale-105 shadow-lg disabled:opacity-50 disabled:cursor-not-allowed disabled:transform-none"
              style={{ backgroundColor: '#DE3C4B', color: '#F2F2F2' }}
            >
              {isSubmitting ? 'Enviando...' : 'Solicitar participacion'}
            </button>

            <p className="text-center text-sm mt-4" style={{ color: '#0C0B0B' }}>
              El speaker debe aprobar tu solicitud
            </p>
          </div>
        </div>
      </div>
    );
  }

  // New participant form
  return (
    <div className="min-h-screen flex items-center justify-center p-4" style={{ backgroundColor: '#0C0B0B' }}>
      <div className="w-full max-w-md">
        <div className="text-center mb-8">
          <img src="/FlashPick-Castoryadis_img.png" alt="FlashPick by Castoryadis" className="h-16 w-auto mx-auto mb-4" />
          <p className="text-white/70 text-lg">Registra tu informacion</p>
        </div>

        <div className="rounded-2xl shadow-2xl p-8" style={{ backgroundColor: '#F2F2F2' }}>
          <form onSubmit={handleSubmit} className="space-y-5">
            <div>
              <label htmlFor="firstName" className="block text-sm font-semibold mb-2" style={{ color: '#0C0B0B' }}>
                Nombre
              </label>
              <input
                type="text"
                id="firstName"
                value={firstName}
                onChange={(e) => setFirstName(e.target.value)}
                className="w-full px-4 py-3 border-2 border-gray-300 rounded-lg focus:ring-2 focus:ring-[#DE3C4B] focus:border-transparent outline-none transition text-lg"
                style={{ color: '#0C0B0B' }}
                placeholder="Tu nombre"
                required
                autoFocus
                disabled={isSubmitting}
              />
            </div>

            <div>
              <label htmlFor="lastName" className="block text-sm font-semibold mb-2" style={{ color: '#0C0B0B' }}>
                Apellido
              </label>
              <input
                type="text"
                id="lastName"
                value={lastName}
                onChange={(e) => setLastName(e.target.value)}
                className="w-full px-4 py-3 border-2 border-gray-300 rounded-lg focus:ring-2 focus:ring-[#DE3C4B] focus:border-transparent outline-none transition text-lg"
                style={{ color: '#0C0B0B' }}
                placeholder="Tu apellido"
                required
                disabled={isSubmitting}
              />
            </div>

            <div>
              <label htmlFor="position" className="block text-sm font-semibold mb-2" style={{ color: '#0C0B0B' }}>
                Cargo
              </label>
              <input
                type="text"
                id="position"
                value={position}
                onChange={(e) => setPosition(e.target.value)}
                className="w-full px-4 py-3 border-2 border-gray-300 rounded-lg focus:ring-2 focus:ring-[#DE3C4B] focus:border-transparent outline-none transition text-lg"
                style={{ color: '#0C0B0B' }}
                placeholder="Tu cargo o rol"
                required
                disabled={isSubmitting}
              />
            </div>

            <div>
              <label htmlFor="institution" className="block text-sm font-semibold mb-2" style={{ color: '#0C0B0B' }}>
                Institucion / Empresa
              </label>
              <input
                type="text"
                id="institution"
                value={institution}
                onChange={(e) => setInstitution(e.target.value)}
                className="w-full px-4 py-3 border-2 border-gray-300 rounded-lg focus:ring-2 focus:ring-[#DE3C4B] focus:border-transparent outline-none transition text-lg"
                style={{ color: '#0C0B0B' }}
                placeholder="Tu empresa o institucion"
                required
                disabled={isSubmitting}
              />
            </div>

            <button
              type="submit"
              disabled={isSubmitting}
              className="w-full py-4 rounded-lg font-bold text-xl transition-all transform hover:scale-105 shadow-lg disabled:opacity-50 disabled:cursor-not-allowed disabled:transform-none"
              style={{ backgroundColor: '#DE3C4B', color: '#F2F2F2' }}
            >
              {isSubmitting ? 'Enviando...' : 'Enviar Informacion'}
            </button>
          </form>

          <p className="text-center text-sm mt-6" style={{ color: '#0C0B0B' }}>
            Completa todos los campos para participar
          </p>
        </div>
      </div>
    </div>
  );
}
