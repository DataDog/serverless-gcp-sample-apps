from flask import Flask

app = Flask(__name__)

@app.route('/')
def hello_world():
    print("nhulston test")

    return 'Hello World!', 200

if __name__ == '__main__':
    print("starting server on port 8080")
    app.run(host='0.0.0.0', port=8080)
