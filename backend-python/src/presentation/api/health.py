from fastapi import FastAPI
from fastapi.responses import JSONResponse

app = FastAPI()

@app.get("/api/python/health")
def health_check():
    return JSONResponse(content={"status": "ok"}, status_code=200)

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=3050)


@app.get("/health")
def health_root():
    return JSONResponse(content={"status": "ok", "service": "backend-python-api"})
