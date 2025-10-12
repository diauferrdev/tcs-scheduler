import { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { useForm } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import { LoginSchema } from '../types';
import { useAuth } from '@/lib/auth';
import { Button } from '../components/ui/button';
import { Input } from '../components/ui/input';
import { Card } from '../components/ui/card';
import { Label } from '../components/ui/label';
import { toast } from 'sonner';
import { Loader2 } from 'lucide-react';

export default function Login() {
  const navigate = useNavigate();
  const { login } = useAuth();
  const [loading, setLoading] = useState(false);

  const form = useForm({
    resolver: zodResolver(LoginSchema),
    defaultValues: {
      email: '',
      password: '',
    },
  });

  const onSubmit = async (data: { email: string; password: string }) => {
    setLoading(true);

    try {
      await login(data.email, data.password);
      toast.success('Welcome! Redirecting to calendar...');
      // Use navigate with replace to prevent back button issues on iOS
      setTimeout(() => navigate('/calendar', { replace: true }), 500);
    } catch (err: any) {
      toast.error(err.response?.data?.error || 'Login failed. Please check your credentials.');
      setLoading(false);
    }
  };

  return (
    <div className="min-h-[100dvh] flex items-center justify-center bg-black px-4">
      <div className="w-full max-w-md">
        {/* Header with Logo */}
        <div className="mb-6 text-center">
          <img
            src="https://www.tcs.com/content/dam/global-tcs/en/images/home/tcs-logo-1.svg"
            alt="TCS Logo"
            className="h-10 mx-auto mb-3"
          />
          <div className="border-t border-gray-800 pt-3 mt-3">
            <h1 className="text-xl font-bold text-white">PacePort Scheduler</h1>
          </div>
        </div>

        {/* Login Card */}
        <Card className="p-6 bg-zinc-900 border-zinc-800">
          <form onSubmit={form.handleSubmit(onSubmit)} className="space-y-4">
            <div>
              <Label htmlFor="email" className="text-white text-sm">Email</Label>
              <Input
                id="email"
                type="email"
                placeholder="admin@tcs.com"
                {...form.register('email')}
                className="mt-1.5 bg-zinc-950 border-zinc-800 text-white placeholder:text-gray-500 focus:border-white h-11"
                disabled={loading}
              />
              {form.formState.errors.email && (
                <p className="text-xs text-red-400 mt-1">{form.formState.errors.email.message}</p>
              )}
            </div>

            <div>
              <Label htmlFor="password" className="text-white text-sm">Password</Label>
              <Input
                id="password"
                type="password"
                placeholder="Enter your password"
                {...form.register('password')}
                className="mt-1.5 bg-zinc-950 border-zinc-800 text-white placeholder:text-gray-500 focus:border-white h-11"
                disabled={loading}
              />
              {form.formState.errors.password && (
                <p className="text-xs text-red-400 mt-1">{form.formState.errors.password.message}</p>
              )}
            </div>

            <Button
              type="submit"
              className="w-full bg-white text-black hover:bg-gray-200 font-semibold h-11"
              disabled={loading}
            >
              {loading ? (
                <>
                  <Loader2 className="w-4 h-4 mr-2 animate-spin" />
                  Logging in...
                </>
              ) : (
                'Login'
              )}
            </Button>
          </form>

          <div className="mt-4 pt-4 border-t border-zinc-800 text-center text-xs">
            <p className="text-gray-400 mb-1.5">Demo Credentials:</p>
            <div className="space-y-0.5 text-gray-500">
              <p><span className="text-gray-400">Admin:</span> admin@tcs.com / TCSPacePort2024!</p>
              <p><span className="text-gray-400">Manager:</span> manager@tcs.com / Manager2024!</p>
            </div>
          </div>
        </Card>
      </div>
    </div>
  );
}
