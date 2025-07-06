# Compilacion del proyecto 
FROM maven:3.9.7-eclipse-temurin-17 AS build
WORKDIR /app

COPY pom.xml .
RUN mvn dependency:go-offline -B

COPY src ./src
RUN mvn package -DskipTests

#Ejecucion del proyecto
# Usando una imagen de JRE para reducir el tamaño final de la imagen
# y mejorar la seguridad al no incluir herramientas de desarrollo innecesarias.
FROM eclipse-temurin:17-jre-alpine


# Crear un usuario y grupo no root para ejecutar la aplicación
# Esto mejora la seguridad al evitar que la aplicación se ejecute como root.
RUN addgroup -S appgroup && adduser -S appuser -G appgroup

RUN mkdir /app && chown -R appuser:appgroup /app

USER appuser

WORKDIR /app
COPY --from=build /app/target/*.jar app.jar

# Establecer variables de entorno para la configuración de la aplicación
# Estas variables pueden ser sobreescritas al ejecutar el contenedor.
ENV PORT=8000
ENV NAME_DB=jdbc:h2:file:./test



EXPOSE 8000

# Configurar un healthcheck para verificar la salud de la aplicación
# Esto permite a Docker monitorear la aplicación y reiniciarla si no está saludable.
HEALTHCHECK --interval=30s --timeout=30s --start-period=5s --retries=3 \ 
    CMD wget --no-verbose --tries=1 --spider http://localhost:8000/api/actuator/health || exit 1

# Comando por defecto para ejecutar la aplicación
# Esto inicia la aplicación Java al iniciar el contenedor.
# Se puede sobreescribir al ejecutar el contenedor si es necesario.    
CMD ["java", "-jar", "app.jar"]

# Etiquetas para metadatos de la imagen
LABEL maintainer="Christian Carpio <chrcv2017@gmail.com>"
LABEL version="1.0"
LABEL app="devsu-demo-devops-java"