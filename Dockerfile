# ===== Stage 1: Build Spring Boot bằng Maven (không cần cài JDK/Maven trên máy) =====
FROM eclipse-temurin:17-jdk-alpine AS build
WORKDIR /app

# Copy wrapper + pom trước để cache layer dependency
COPY .mvn/ .mvn/
COPY mvnw pom.xml ./
RUN chmod +x mvnw && ./mvnw dependency:go-offline -B

# Copy source (đã chứa Flutter Web build tại src/main/resources/static/mobile/)
COPY src/ src/
RUN ./mvnw package -DskipTests -B

# ===== Stage 2: Runtime =====
FROM eclipse-temurin:17-jre-alpine
WORKDIR /app
COPY --from=build /app/target/*.jar app.jar

EXPOSE 8080

# Healthcheck để docker-compose biết app sẵn sàng trước khi chạy mobile test
HEALTHCHECK --interval=5s --timeout=3s --retries=30 \
  CMD wget -qO- http://localhost:8080/ > /dev/null || exit 1

ENTRYPOINT ["java", "-jar", "app.jar"]
