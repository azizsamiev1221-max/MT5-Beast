FROM ghcr.io/alloveras/mt5-terminal:latest

# Копируем твой советник в папку экспертов терминала
COPY "MT5_Beast_Micro_v8(1).mq5" /root/.wine/drive_c/Program\ Files/MetaTrader\ 5/MQL5/Experts/

# Настройка для работы без монитора
ENV DISPLAY=:0
