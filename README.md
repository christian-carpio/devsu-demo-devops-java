# Prueba Práctica Devsu Devops - Christian Carpio

Este documento detalla el proceso llevado a cabo para desplegar la aplicación devsu-demo-devops-java en Google Cloud Platform mediante un pipeline de GitHub Actions.

## Diagrama del Despliegue
![Diagrama del Despliegue](docs/devsu-demo-devops.drawio.png)

## Tecnologías empleadas
- Docker
- JaCoCo
- SpotBugs
- Trivy
- Terraform (IaC)
- Google Cloud Platform / GCP
- Google Kubernetes Engine / GKE (Servicio)
- Kubernetes (K8s)

## 1. Modificaciones al proyecto base
Se agregó la dependencia *spring-boot-starter-actuator* y los plugins *spotbugs-maven-plugin* y *jacoco-maven-plugin* con el objetivo de exponer el endpoint */api/actuator/health* (para el healthcheck del Dockerfile) y realizar las validaciones solicitadas (cobertura de código y análisis de código estático).

Adicionalmente, se modificó el archivo *application.properties* y se agregó:
- management.endpoints.web.exposure.include=health,info 
- management.endpoint.health.show-details=always

Con la finalidad de exponer correctamente el endpoint para el mencionado healthcheck.

## 2. Creación del dockerfile
Se separó el Dockerfile en 2 stages: Compilación y Ejecución.

Durante la primera fase, se descargan las dependencias definidas en el archivo pom y se compila el proyecto sin realizar las pruebas unitarias (estas se realizan durante la ejecución del pipeline).

En la segunda fase, se crean tanto un usuario como un grupo dedicado para poder ejecutar la aplicación sin tener permisos de usuario root. Luego, se copia el archivo *.jar* resultante de la fase anterior, se expone el puerto 8000 y se configuran las variables de entorno.

Posteriormente, se realiza el healthcheck usando el endpoint */api/actuator/health* para comprobar el correcto funcionamiento del contenedor y realizar un reinicio automático en caso de ser necesario.

En cuanto a los comandos que se usan cuando arranca el contenedor, se habilitó *java*, *-jar* y *app.jar*.

Finalmente, se agregaron labels con la información del maintainer, versión y nombre de aplicación.

## 3. Aprovisionamiento de GKE con Terraform en GCP
Por medio de Terraform, se aprovisionó un clúster de GKE usando los archivos:
- **main.tf :** Define el clúster y una custom pool de nodos a crearse en GCP
- **outputs.tf :** Regresa información para identificar el clúster como nombre y ubicación
- **provider :** Define la información del provider a emplear (GCP), el nombre del proyecto y región donde se va a desplegar el clúster

Con esta estructura, se crea un clúster bajo el nombre devsu-demo-devops-cluster en la zona us-central1-a. Una vez creado, se elimina el nodo creado por defecto y se crean 2 nodos para soportar la carga de trabajo deseada. Estos nodos usan una máquina tipo e2-medium para estar por debajo de los límites del plan de prueba gratuito de GCP.

Adicionalmente, se habilitaron las opciones auto_repair y auto_upgrade para tener tolerancia a fallos y actualizaciones.

Se decidió no incluir el aprovisionamiento de esta estructura en el pipeline ya que:
- No es necesario realizar reaprovisionamientos frecuentes en este escenario, la infraestructura es constante
- Su inclusión incrementaría considerablemente el tiempo de ejecución del pipeline

## 4. Creación del pipeline
Usando GitHub Actions, se creó un pipeline que abarca desde la compilación del proyecto hasta el despliegue automatizado de los contenedores en un clúster de GKE.

### Jobs creados
#### Build
Se compila el proyecto y se genera el archivo *.jar*, el cual es subido como un adjunto del pipeline para uso posterior. 

#### Unit Test & Code Coverage:
Usando el plugin JaCoCo, se ejecutan las pruebas de usuario definidas y se genera un reporte de cobertura de codigo. Este reporte es almacenado como un artefacto del pipeline con el nombre *jacoco-report-<sha>*, donde *<sha>* representa el hash del commit actual. 

#### Static Code Analysis:
Usando el plugin SpotBugs, se ejecuta un análisis estático del código fuente para identificar errores, vulnerabilidades lógicas y malas práticas. Si se llegan a detectar errores críticos, el job fallara automáticamente y el pipeline se detendria.

#### Build and Push Docker Image:
Posterior a las validaciones anteriores, se construyen 2 imagenes de la aplicación: una con el tag *latest* y la segunda con *<sha>*. Posteriormente, usando las credenciales definidas en los secrets del repositorio, estas son subidas al repositorio *christiancarpio2210/devsu-demo-devops-java*. 

#### Security Scan:
Utilizando Trivy, se escanea la imagen construida con el tag *latest* en busca de vulnerabilidades conocidads (CVEs) a nivel del sistema operativo (OS) como de las dependencias usadas en el proyecto. El resultado del escaneo es almacenado en el archivo *trivy-report.json* para ser subido como un artefacto del pipeline.

#### Deploy to GKE (usando K8s):
En el último job del pipeline se configura el depliegue hacia GKE usando los manifiestos ubicados en la carpeta k8s/. 

Primero, se accede a GCP usando las credenciales definidas en los secrets y se configura el CLI. Una vez hecho esto, se obtiene tanto el nombre y region del cluster, así como el ID del proyecto para poder interactuar con el cluster.

Posteriormente, se reemplaza el marcador __IMAGE_TAG__ dentro de deployment.yaml por el hash del commit actual para elegir la imagen de docker correspondiente al y se ejecuta el mencionado manifiesto.

En caso de que exista una configuración previa de deployment.yaml, esta es eliminada para reemplazarla por la versión actual. Una vez hecho esto, se ejecutan los siguientes archivos:
- **deployment.yaml :** Crea dos réplicas a partir de la imagen etiquetada con el hash del commit actual, expone el puerto 8000 y define los recursos que puede utilizar cada réplica. Además, se agregan los probes de readiness y liveness para validar el correcto funcionamiento de la aplicación, mediante el endpoint /api/actuator/health.

- **ingress.yaml :** Define el Ingress que expone la aplicación para conexiones externas y lo asocia al BackendConfig previamente definido. Este Ingress enruta las solicitudes que comienzan con /api al servicio correspondiente a través del puerto 80.

- **service.yaml :** Define un servicio de tipo NodePort, encargado de conectar el Ingress con los pods que posean el label app: devsu-demo-devops. Además, se especifica que este servicio escuche en el puerto 80 y redirija el tráfico al puerto 8000 del contenedor. Finalmente, se habilita un Network Endpoint Group para que el Load Balancer funcione correctamente con el Ingress.

- **backend-config.yaml :** Define la configuración para el health check utilizado por el Load Balancer para verificar el estado de salud de los pods.

- **configmap.yaml :** Define un ConfigMap que contiene información básica del proyecto, como el nombre de la aplicación, la versión y una breve descripción.

Una vez ejecutados estos manifiestos, se espera un máximo de 5 minutos a que los pods se desplieguen correctamente. En caso de no completarse existosamente, el job fallara y se detiene el pipeline.

## 6. URL Publicas:
Pueden consultar las siguientes URL para verificar el funcionamiento del despliegue:
- [http://107.178.242.9/api/swagger-ui/index.html#/user-controller/list](http://107.178.242.9/api/swagger-ui/index.html#/user-controller/list)
- [http://107.178.242.9/api/users](http://107.178.242.9/api/users)
- [http://107.178.242.9/api/actuator/health](http://107.178.242.9/api/actuator/health)
