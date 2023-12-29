# load FastApi
try:
    from app.sub_app import main as user_main
    app = user_main.app
except Exception as e:
    print(f'ERROR:\t  {e}. Running Default main.py')
    from fastapi import FastAPI
    app = FastAPI()
    @app.get("/")
    def read_root():
        return {"message": "Hello, World!"}
finally:
    @app.get("/health")
    def read_root():
        return {"status": "ready"}