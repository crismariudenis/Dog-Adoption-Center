# Frontend: Docker-based build & run

This frontend is built inside Docker so you do not need to run `npm install` locally.

Quick commands (from repository root):

Build the frontend image (runs `npm install` and `npm run build` inside container):

```bash
docker compose build frontend
```

Run the frontend (served by the `frontend` service):

```bash
docker compose up -d frontend ingress
```

Show logs:

```bash
docker compose logs -f frontend
```

If you want to develop with hot-reload locally, use the normal `npm install` + `npm run dev` inside the `frontend` folder — but for CI and reproducible builds prefer Docker.
