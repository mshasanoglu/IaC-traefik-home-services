FROM python:3.9-alpine

WORKDIR /code
COPY ./requirements.txt /code/
COPY ./main.py /code/app/
 
RUN pip3 install --upgrade pip
RUN pip3 install --no-cache-dir --upgrade -r /code/requirements.txt

EXPOSE 80
CMD ["uvicorn", "app.main:app", "--reload", "--reload-include", "*.py", "--proxy-headers", "--host", "0.0.0.0", "--port", "80"]