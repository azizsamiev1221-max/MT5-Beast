# Используем проверенный образ с предустановленным Wine
FROM ubuntu:20.04

# Установка необходимых компонентов
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y wget gnupg2 software-properties-common winehq-stable || true

# Создаем рабочую директорию
WORKDIR /app

# Копируем твой файл советника
COPY "MT5_Beast_Micro_v8(1).mq5" /app/

# Команда, чтобы контейнер не выключался сразу
CMD ["tail", "-f", "/dev/null"]
