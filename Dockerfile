FROM eclipse-temurin:17-jre-alpine
WORKDIR /app
COPY target/todo-app.jar app.jar
EXPOSE 8080
ENTRYPOINT ["java", "-jar", "app.jar"]
