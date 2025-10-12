import axios from 'axios';

export const api = axios.create({
  baseURL: import.meta.env.PUBLIC_API_URL || 'http://localhost:7777',
  withCredentials: true,
  headers: {
    'Content-Type': 'application/json',
    // Skip ngrok browser warning
    'ngrok-skip-browser-warning': 'true',
  },
});

// Request interceptor
api.interceptors.request.use(
  (config) => {
    return config;
  },
  (error) => {
    return Promise.reject(error);
  }
);

// Response interceptor
api.interceptors.response.use(
  (response) => {
    return response;
  },
  (error) => {
    if (error.response?.status === 401) {
      // Only redirect to login if NOT already on login page or public routes
      const isGuestBookingPage = window.location.pathname.startsWith('/book/');
      const isPublicBadge = window.location.pathname.startsWith('/badge/') || window.location.pathname.startsWith('/attendee/');
      const isLoginPage = window.location.pathname === '/login';
      const isAuthEndpoint = error.config?.url?.includes('/api/auth/');

      // Don't redirect if:
      // - Already on login page
      // - On public routes (guest booking, badges)
      // - Error is from auth endpoints (login/logout/me) - let component handle it
      if (!isLoginPage && !isGuestBookingPage && !isPublicBadge && !isAuthEndpoint) {
        window.location.href = '/login';
      }
    }
    return Promise.reject(error);
  }
);
