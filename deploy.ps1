# Variables
$projectName = "my_django_app"
$email = "your-email@example.com"

# Prompt for the domain name
$domainName = Read-Host "Please enter the domain name for the instance"

# Create project directory and navigate into it
New-Item -ItemType Directory -Force -Path $projectName
Set-Location -Path $projectName

docker run --rm -v ${PWD}:/app -w /app python:3.9 bash -c "pip install django && django-admin startproject $projectName ."


# Create a Dockerfile for the Django application
@"
FROM python:3.9-slim

WORKDIR /app

COPY requirements.txt /app/
RUN pip install --no-cache-dir -r requirements.txt

COPY . /app/

CMD ["gunicorn", "$projectName.wsgi:application", "--bind", "0.0.0.0:8000"]
"@ > Dockerfile

# Create requirements.txt
@"
Django>=3.2,<4.0
gunicorn
"@ > requirements.txt

# Create docker-compose.yml
@"
services:
  web:
    build: .
    command: gunicorn $projectName.wsgi:application --bind 0.0.0.0:8000
    volumes:
      - .:/app
    expose:
      - "8000"

  nginx:
    image: nginx:latest
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf
    ports:
      - "80:80"
    depends_on:
      - web

"@ > docker-compose.yml

# Create Nginx configuration file
@"
server {
    listen 80;
    server_name $domainName;

    location / {
        proxy_pass http://web:8000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
"@ > nginx.conf

# Run Docker Compose to start the services
docker-compose up -d

# Reload Nginx to apply the SSL certificate
docker-compose exec nginx nginx -s reload
