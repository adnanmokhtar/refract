FROM eclipse-temurin:21-jre
WORKDIR /app
COPY build/libs/refunds.jar /app/refunds.jar
USER 1000
ENTRYPOINT ["java", "-XX:MaxRAMPercentage=75", "-jar", "/app/refunds.jar"]
