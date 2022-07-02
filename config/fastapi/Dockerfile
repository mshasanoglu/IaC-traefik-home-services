FROM python:3.9

# 
WORKDIR /code

# 
COPY ./requirements.txt /code/requirements.txt

# 
RUN pip3 install --upgrade pip

# 
RUN pip3 install --no-cache-dir --upgrade -r /code/requirements.txt

#
EXPOSE 80

# 
CMD ["uvicorn", "app.main:app", "--reload", "--proxy-headers", "--host", "0.0.0.0", "--port", "80"]