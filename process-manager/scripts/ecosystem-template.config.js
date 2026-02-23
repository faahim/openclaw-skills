// Process Manager — Ecosystem Configuration Template
// Copy this file and edit for your setup:
//   cp scripts/ecosystem-template.config.js ecosystem.config.js
//   bash scripts/run.sh ecosystem ecosystem.config.js

module.exports = {
  apps: [
    {
      // Web server example
      name: "web-server",
      script: "node",
      args: "server.js",
      cwd: "/home/user/web-app",
      instances: 2,                    // Number of instances (use "max" for all CPUs)
      exec_mode: "cluster",            // "cluster" for load balancing, "fork" for single
      max_memory_restart: "500M",      // Restart if memory exceeds this
      env: {
        NODE_ENV: "production",
        PORT: 3000
      },
      // Logging
      log_date_format: "YYYY-MM-DD HH:mm:ss",
      error_file: "logs/web-error.log",
      out_file: "logs/web-out.log",
      merge_logs: true,
      // Restart behavior
      autorestart: true,
      max_restarts: 10,                // Max restarts within min_uptime window
      min_uptime: 5000,                // Consider "started" after 5s
      restart_delay: 5000,             // Wait 5s between restarts
      watch: false                     // Set true for dev (auto-restart on file change)
    },
    {
      // Background worker example
      name: "bg-worker",
      script: "python3",
      args: "worker.py",
      cwd: "/home/user/workers",
      autorestart: true,
      max_restarts: 5,
      restart_delay: 10000,
      env: {
        QUEUE: "default",
        REDIS_URL: "redis://localhost:6379"
      }
    },
    {
      // Periodic task example
      name: "scheduled-task",
      script: "bash",
      args: "cleanup.sh",
      cwd: "/home/user/scripts",
      cron_restart: "0 */6 * * *",     // Run every 6 hours
      autorestart: false                // Don't auto-restart (cron handles it)
    }
  ]
};
