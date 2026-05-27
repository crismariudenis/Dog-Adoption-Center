# Dog-Adoption-Center

A free and open source web service that allows you to adopt a dog, with at most 3 clicks.

## Team

- **Bazon Bogdan (BB) (Lead):** User authentication and Dog adoption workflow
- **Crismariu Denis (CD):** Notifications, Reviews and Analytics
- **Meraru Ioan-Lucian (MIL):** Pet listing, search and backend logic
- **Vezeteu Andrei (VA):** Front-end and ingress

## Technologies Used

- **Cloud:** Azure Kubernetes Service (AKS), Azure Container Registry (ACR), Azure CDN
- **Databases:** Azure SQL (PostgreSQL), Azure Cosmos DB (NoSQL), Blob Storage
- **Backend:** .NET 10, Entity Framework Core, MediatR (CQRS)
- **Frontend:** React, Tailwind CSS, Vite
- **Messaging & Monitoring:** Azure Service Bus, Application Insights
- **DevOps:** GitHub Actions, Docker, OpenID Connect (OIDC)

## Future Roadmap & Enhancements

- **Rigorous Adoption Workflow:** Moving towards a document-verified process requiring legal proof of residency and pet-ownership permissions.
- **Intelligent Breed Recognition:** A mobile application powered by **Computer Vision (AI)** allowing users to scan a dog to identify its breed and view available adoption matches in real-time.

## Future Technologies

- **Mobile:** React Native / Flutter
- **AI/ML:** TensorFlow / PyTorch (Computer Vision)
- **Verification:** Azure AI Vision (Document OCR)

## Run everything with Docker (local demo)

Quick start — copy the `.env.example` to `.env` and fill in secrets if needed (for local demos you can leave blanks for optional cloud services):

```bash
cp .env.example .env
# edit .env to set POSTGRES_PASSWORD and JWT_KEY at minimum
```

Start and build the entire stack with a single command (recommended):

```bash
docker compose up --build -d
```

This builds images as needed (including running `npm install` and `npm run build` inside the `frontend` image) and starts all services.

Check service status and logs:

```bash
docker compose ps
docker compose logs -f frontend api adoption-manager
```

Access the frontend at http://localhost/ (ingress proxies services). API endpoints are exposed on their configured ports (see `docker-compose.yml`), e.g. `http://localhost:8080` for `api`.

To stop the stack:

```bash
docker compose down
```

Troubleshooting

- If a service fails to start, run `docker compose logs <service>` to see the error.
- If database migrations fail, confirm `DB_CONNECTION_STRING` and Postgres credentials in your `.env`.
- For frontend build errors: the frontend image runs `npm install` and `npm run build` inside Docker; see `frontend/README.md` for details.
