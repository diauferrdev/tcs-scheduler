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
      // Redirect to login if unauthorized, but NOT for public guest booking pages
      const isGuestBookingPage = window.location.pathname.startsWith('/book/');
      if (window.location.pathname !== '/login' && !isGuestBookingPage) {
        window.location.href = '/login';
      }
    }
    return Promise.reject(error);
  }
);
