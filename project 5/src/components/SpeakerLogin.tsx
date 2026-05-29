import { useState } from 'react';
import { supabase } from '../lib/supabase';

interface SpeakerLoginProps {
  onLogin: () => void;
}

const SPEAKER_EMAIL = 'speaker@flashpick.app';

export default function SpeakerLogin({ onLogin }: SpeakerLoginProps) {
  const [password, setPassword] = useState('');
  const [error, setError] = useState('');
  const [isLoading, setIsLoading] = useState(false);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setIsLoading(true);
    setError('');

    try {
      const { data, error: loginError } = await supabase.auth.signInWithPassword({
        email: SPEAKER_EMAIL,
        password: password,
      });

      if (loginError) {
        if (loginError.message.includes('Invalid login credentials')) {
          if (password === 'flashpick2026') {
            const { error: signUpError } = await supabase.auth.signUp({
              email: SPEAKER_EMAIL,
              password: password,
            });

            if (signUpError) {
              setError('Error al crear cuenta: ' + signUpError.message);
              setIsLoading(false);
              return;
            }

            const { error: retryLoginError } = await supabase.auth.signInWithPassword({
              email: SPEAKER_EMAIL,
              password: password,
            });

            if (retryLoginError) {
              setError('Error al iniciar sesion despues del registro');
              setIsLoading(false);
              return;
            }

            onLogin();
          } else {
            setError('Contraseña incorrecta');
            setPassword('');
          }
        } else {
          setError('Error de autenticacion');
        }
        setIsLoading(false);
        return;
      }

      if (data.user) {
        onLogin();
      }
    } catch (err) {
      setError('Error inesperado al iniciar sesion');
      setIsLoading(false);
    }
  };

  return (
    <div className="min-h-screen flex items-center justify-center p-4" style={{ backgroundColor: '#0C0B0B' }}>
      <div className="w-full max-w-md">
        <div className="rounded-2xl shadow-2xl p-8" style={{ backgroundColor: '#F2F2F2' }}>
          <div className="flex justify-center mb-4">
            <img
              src="/FlashPick-Castoryadis_img.png"
              alt="FlashPick by Castoryadis"
              className="h-16 w-auto"
              style={{ filter: 'brightness(0)' }}
            />
          </div>
          <p className="text-center mb-8 font-medium" style={{ color: '#0C0B0B' }}>
            Accede al panel
          </p>

          <form onSubmit={handleSubmit} className="space-y-6">
            <div>
              <label htmlFor="password" className="block text-sm font-medium mb-2" style={{ color: '#0C0B0B' }}>
                Contraseña
              </label>
              <input
                type="password"
                id="password"
                value={password}
                onChange={(e) => {
                  setPassword(e.target.value);
                  setError('');
                }}
                className="w-full px-4 py-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-[#DE3C4B] focus:border-transparent outline-none transition"
                style={{ color: '#0C0B0B' }}
                placeholder="Ingresa tu contraseña"
                autoFocus
                disabled={isLoading}
              />
              {error && (
                <p className="mt-2 text-sm text-red-600">{error}</p>
              )}
            </div>

            <button
              type="submit"
              disabled={isLoading}
              className="w-full py-3 rounded-lg font-semibold transition-all hover:opacity-90 disabled:opacity-50 disabled:cursor-not-allowed"
              style={{ backgroundColor: '#DE3C4B', color: '#F2F2F2' }}
            >
              {isLoading ? 'Autenticando...' : 'Acceder'}
            </button>
          </form>
        </div>
      </div>
    </div>
  );
}
