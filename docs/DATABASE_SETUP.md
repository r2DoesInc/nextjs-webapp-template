# Database Setup

This guide covers PostgreSQL setup with Prisma ORM.

## Local Development

### Using Docker

```bash
# Start PostgreSQL
docker run -d \
  --name {{APP_NAME}}-postgres \
  -e POSTGRES_USER=postgres \
  -e POSTGRES_PASSWORD=postgres \
  -e POSTGRES_DB={{APP_NAME}} \
  -p 5432:5432 \
  postgres:16
```

### Configure Environment

```bash
cp .env.example .env
```

Edit `.env`:
```
DATABASE_URL="postgresql://postgres:postgres@localhost:5432/{{APP_NAME}}?schema=public"
```

### Run Migrations

```bash
# Generate Prisma client
npm run db:generate

# Run migrations
npm run db:migrate

# Seed database
npm run db:seed
```

## Cloud SQL (Production)

### Create Cloud SQL Instance

```bash
gcloud sql instances create {{APP_NAME}}-db \
  --database-version=POSTGRES_16 \
  --tier=db-f1-micro \
  --region={{GCP_REGION}} \
  --root-password=YOUR_ROOT_PASSWORD

# Create database
gcloud sql databases create {{APP_NAME}} \
  --instance={{APP_NAME}}-db

# Create user
gcloud sql users create {{APP_NAME}}_user \
  --instance={{APP_NAME}}-db \
  --password=YOUR_USER_PASSWORD
```

### Store Connection String in GSM

```bash
# For private IP connection (recommended)
echo -n "postgresql://{{APP_NAME}}_user:YOUR_PASSWORD@PRIVATE_IP:5432/{{APP_NAME}}" | \
  gcloud secrets create {{APP_NAME}}_database_url --data-file=-
```

## Prisma Workflow

### Creating Migrations

```bash
# Create migration from schema changes
npm run db:migrate -- --name your_migration_name

# Apply migrations in production
npm run db:migrate:deploy
```

### Schema Changes

1. Edit `prisma/schema.prisma`
2. Run `npm run db:migrate -- --name describe_change`
3. Commit migration files

### Seeding Data

Edit `prisma/seed.ts` to add initial data:

```typescript
await prisma.appSetting.upsert({
  where: { key: 'my_setting' },
  update: { value: 'new_value' },
  create: { key: 'my_setting', value: 'initial_value' },
});
```

Run with:
```bash
npm run db:seed
```

### Prisma Studio

Visual database browser:

```bash
npm run db:studio
```

## Field Encryption

For sensitive data, use Prisma field encryption:

1. Install extension:
```bash
npm install prisma-field-encryption
```

2. Add to schema:
```prisma
model User {
  id       String  @id @default(cuid())
  email    String  /// @encrypted
  emailHash String? /// @encryption:hash(email)
}
```

3. Set encryption key:
```bash
# Generate key
openssl rand -base64 32

# Add to .env
PRISMA_FIELD_ENCRYPTION_KEY="your-32-byte-key"
```

## Database Backups

### Cloud SQL Automated Backups

```bash
gcloud sql instances patch {{APP_NAME}}-db \
  --backup-start-time=02:00
```

### Manual Backup

```bash
gcloud sql export sql {{APP_NAME}}-db gs://YOUR_BUCKET/backup.sql \
  --database={{APP_NAME}}
```

## Next Steps

1. [Deployment](DEPLOYMENT.md)
