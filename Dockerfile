# Используем стабильную версию Ubuntu
FROM ubuntu:22.04

# Отключаем интерактивные диалоги при установке
ENV DEBIAN_FRONTEND=noninteractive

# Устанавливаем Wine и необходимые зависимости
RUN apt-get update && apt-get install -y \
    wget \
    gnupg2 \
    software-properties-common \
    wine \
    && apt-get clean

# Создаем рабочую папку
WORKDIR /app

# Копируем твой файл советника в контейнер
COPY "MT5_Beast_Micro_v8(1).mq5" /app/

# Заглушка, чтобы сервер не выключался (tail -f будет работать вечно)
CMD ["tail", "-f", "/dev/null"]
