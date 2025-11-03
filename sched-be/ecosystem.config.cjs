module.exports = {
  apps: [
    {
      name: 'tcs-scheduler-api',
      script: 'bun',
      args: 'run src/index.ts',
      cwd: '/root/tcs/tcs-sched/sched-be',
      interpreter: 'none',
      instances: 1,
      exec_mode: 'fork',
      autorestart: true,
      watch: false,
      max_memory_restart: '1G',
      env: {
        NODE_ENV: 'production',
        PORT: '7777'
      },
      error_file: '/root/tcs/tcs-sched/sched-be/logs/error.log',
      out_file: '/root/tcs/tcs-sched/sched-be/logs/out.log',
      log_date_format: 'YYYY-MM-DD HH:mm:ss Z',
      merge_logs: true,
      time: true
    }
  ]
}
