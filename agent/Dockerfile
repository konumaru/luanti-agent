FROM python:3.13-slim

WORKDIR /app

COPY requirements.server.txt /app/requirements.server.txt
RUN pip install --no-cache-dir -r /app/requirements.server.txt

COPY . /app

EXPOSE 8000

CMD ["uvicorn", "bot_server_fastapi:app", "--host", "0.0.0.0", "--port", "8000"]
