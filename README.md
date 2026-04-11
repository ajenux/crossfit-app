# CrossFit App

REST API for managing CrossFit coaches and athletes, built with Spring Boot.

## Tech Stack

- Java 21
- Spring Boot 4.0
- Spring Data JPA
- Spring Security
- PostgreSQL
- Lombok
- Maven

## Prerequisites

- JDK 21
- PostgreSQL 17
- Maven (or use the included `./mvnw` wrapper)

## Database Setup

```bash
createdb crossfit_db
psql crossfit_db -c "CREATE USER crossfit_user WITH PASSWORD 'crossfit123';"
psql crossfit_db -c "GRANT ALL PRIVILEGES ON DATABASE crossfit_db TO crossfit_user;"
psql crossfit_db -c "GRANT ALL ON SCHEMA public TO crossfit_user;"
```

## Running the App

```bash
./mvnw spring-boot:run
```

The API will be available at `http://localhost:8080`.

## API Endpoints

### Coaches

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/coaches` | List all coaches |
| GET | `/api/coaches/{id}` | Get coach by ID |
| POST | `/api/coaches` | Create a coach |
| PUT | `/api/coaches/{id}` | Update a coach |
| DELETE | `/api/coaches/{id}` | Delete a coach |

### Athletes

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/athletes` | List all athletes |
| GET | `/api/athletes?coachId={id}` | List athletes by coach |
| GET | `/api/athletes/{id}` | Get athlete by ID |
| POST | `/api/athletes` | Create an athlete |
| PUT | `/api/athletes/{id}` | Update an athlete |
| DELETE | `/api/athletes/{id}` | Delete an athlete |

## Example Requests

**Create a coach:**
```bash
curl -X POST http://localhost:8080/api/coaches \
  -H "Content-Type: application/json" \
  -d '{"name": "John Doe", "email": "john@crossfit.com"}'
```

**Create an athlete:**
```bash
curl -X POST http://localhost:8080/api/athletes \
  -H "Content-Type: application/json" \
  -d '{"name": "Jane Smith", "email": "jane@crossfit.com", "coachId": 1}'
```

**List athletes by coach:**
```bash
curl http://localhost:8080/api/athletes?coachId=1
```