import { useState, useEffect } from 'react';
import SpeakerLogin from './components/SpeakerLogin';
import SpeakerDashboard from './components/SpeakerDashboard';
import ParticipantView from './components/ParticipantView';
import { supabase } from './lib/supabase';

function App() {
  const [isAuthenticated, setIsAuthenticated] = useState(false);
  const [currentPath, setCurrentPath] = useState('');
  const [isCheckingAuth, setIsCheckingAuth] = useState(true);

  useEffect(() => {
    const updatePath = () => {
      setCurrentPath(window.location.pathname);
    };

    updatePath();
    window.addEventListener('popstate', updatePath);

    return () => {
      window.removeEventListener('popstate', updatePath);
    };
  }, []);

  useEffect(() => {
    const checkSession = async () => {
      try {
        const { data: { session } } = await supabase.auth.getSession();
        setIsAuthenticated(!!session);
      } catch (error) {
        console.error('Error al verificar sesión:', error);
      } finally {
        setIsCheckingAuth(false);
      }
    };

    checkSession();

    const { data: { subscription } } = supabase.auth.onAuthStateChange((_event, session) => {
      setIsAuthenticated(!!session);
    });

    return () => {
      subscription.unsubscribe();
    };
  }, []);

  const handleLogin = () => {
    setIsAuthenticated(true);
  };

  const handleLogout = () => {
    setIsAuthenticated(false);
  };

  if (currentPath.startsWith('/participar/')) {
    const sessionId = currentPath.split('/participar/')[1];
    return <ParticipantView sessionId={sessionId} />;
  }

  if (currentPath === '/speaker') {
    if (isCheckingAuth) {
      return (
        <div className="min-h-screen flex items-center justify-center" style={{ backgroundColor: '#0C0B0B' }}>
          <div className="text-white text-xl">Cargando...</div>
        </div>
      );
    }
    if (!isAuthenticated) {
      return <SpeakerLogin onLogin={handleLogin} />;
    }
    return <SpeakerDashboard onLogout={handleLogout} />;
  }

  return (
    <div className="min-h-screen flex items-center justify-center p-4" style={{ backgroundColor: '#0C0B0B' }}>
      <div className="text-center">
        <img src="/FlashPick-Castoryadis_img.png" alt="FlashPick by Castoryadis" className="h-28 w-auto mx-auto mb-6" />
        <p className="text-white text-xl mb-8">
        </p>
        <a
          href="/speaker"
          onClick={(e) => {
            e.preventDefault();
            window.history.pushState({}, '', '/speaker');
            setCurrentPath('/speaker');
          }}
          className="inline-block px-8 py-4 rounded-lg font-bold text-lg transition-all hover:opacity-90"
          style={{ backgroundColor: '#DE3C4B', color: '#F2F2F2' }}
        >
          Acceder al panel
        </a>
      </div>
    </div>
  );
}

export default App;
