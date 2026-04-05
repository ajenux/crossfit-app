# CrossFit App - Backend API

A REST API for managing CrossFit coaches, athletes, and workouts, built with Spring Boot.

## Tech Stack

- **Java 21**
- **Spring Boot 4**
- **Spring Security + JWT**
- **Spring Data JPA + Hibernate**
- **PostgreSQL**
- **Lombok**
- **Flutter** (mobile frontend - in progress)

## Prerequisites

- Java 21+
- Maven
- PostgreSQL 17+

## Database Setup

```sql
CREATE USER crossfit_user WITH PASSWORD 'crossfit123';
CREATE DATABASE crossfit_db OWNER crossfit_user;
```

## Configuration

Edit `src/main/resources/application.properties`:

```properties
spring.datasource.url=jdbc:postgresql://localhost:5432/crossfit_db
spring.datasource.username=crossfit_user
spring.datasource.password=crossfit123

jwt.secret=your-secret-key-at-least-256-bits-long
jwt.expiration-ms=86400000
```

## Running the App

```bash
./mvnw spring-boot:run
```

App runs on `http://localhost:8080`.

## Authentication

All `/api/**` endpoints require a JWT token except `/api/auth/**`.

### Register

```http
POST /api/auth/register
Content-Type: application/json

{
  "email": "coach@example.com",
  "password": "yourpassword",
  "role": "COACH"
}
```

Roles: `COACH`, `ATHLETE`

### Login

```http
POST /api/auth/login
Content-Type: application/json

{
  "email": "coach@example.com",
  "password": "yourpassword"
}
```

Both return a token:

```json
{ "token": "eyJ..." }
```

Use it in all subsequent requests:

```
Authorization: Bearer eyJ...
```

## API Endpoints

### Coaches

| Method | URL | Description |
|--------|-----|-------------|
| GET | `/api/coaches` | List all coaches |
| GET | `/api/coaches/{id}` | Get coach by ID |
| POST | `/api/coaches` | Create coach |
| PUT | `/api/coaches/{id}` | Update coach |
| DELETE | `/api/coaches/{id}` | Delete coach |

**Create coach example:**
```json
{ "name": "John", "email": "john@crossfit.com" }
```

### Athletes

| Method | URL | Description |
|--------|-----|-------------|
| GET | `/api/athletes` | List all athletes |
| GET | `/api/athletes?coachId=1` | List athletes by coach |
| GET | `/api/athletes/{id}` | Get athlete by ID |
| POST | `/api/athletes` | Create athlete |
| PUT | `/api/athletes/{id}` | Update athlete |
| DELETE | `/api/athletes/{id}` | Delete athlete |

**Create athlete example:**
```json
{ "name": "Maria", "email": "maria@crossfit.com", "coachId": 1 }
```

### Workouts

| Method | URL | Description |
|--------|-----|-------------|
| GET | `/api/workouts` | List all workouts |
| GET | `/api/workouts?athleteId=1` | Workouts for an athlete |
| GET | `/api/workouts?coachId=1` | Workouts by a coach |
| GET | `/api/workouts/{id}` | Get workout by ID |
| POST | `/api/workouts` | Create workout |
| PUT | `/api/workouts/{id}` | Update workout |
| DELETE | `/api/workouts/{id}` | Delete workout |

**Workout types:** `AMRAP`, `FOR_TIME`, `EMOM`, `STRENGTH`, `ENDURANCE`

**Create workout example:**
```json
{
  "name": "Fran",
  "description": "21-15-9 Thrusters and Pull-ups",
  "type": "FOR_TIME",
  "scheduledDate": "2026-04-06",
  "athleteId": 1,
  "coachId": 1
}
```

## Project Structure

```
src/main/java/com/example/demo/
├── config/          # Security and app configuration
├── controller/      # REST controllers (HTTP layer)
├── dto/             # Request and response objects
├── model/           # JPA entities
├── repository/      # Database access (Spring Data)
├── security/        # JWT filter and service
└── service/         # Business logic
```

## Branching Strategy

- `master` — stable releases only
- `develop` — active development branch