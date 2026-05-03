FROM ghcr.io/mql5-docker/mt5-terminal:latest

# Устанавливаем пароль для доступа к рабочему столу сервера
ENV VNC_PASSWORD=your_password_here

# Копируем твой файл советника в папку MT5
COPY "MT5_Beast_Micro_v8(1).mq5" /root/.wine/drive_c/Program\ Files/MetaTrader\ 5/MQL5/Experts/

EXPOSE 8080
