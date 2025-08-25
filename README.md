# Serverless Google Cloud Sample Apps

This repository contains sample apps for various serverless Google Cloud
environments. These samples can be used in conjunction with our official
documentation to correctly set up Datadog instrumentation for your serverless
applications.

- [Google Cloud Run](./cloud-run/)
    - [Sidecar instrumentation](./cloud-run/sidecar/)
        - [Python](./cloud-run/sidecar/python)
    - [In-Container instrumentation](./cloud-run/in-container/)
        - [Python](./cloud-run/in-container/python/)
        - [Node.js](./cloud-run/in-container/node/)
        - [Go](./cloud-run/in-container/go/)
        - [Java](./cloud-run/in-container/java/)
        - [.NET](./cloud-run/in-container/dotnet/)
        - [Ruby](./cloud-run/in-container/ruby/)
        - [PHP](./cloud-run/in-container/php/)

To update licenses, run the `./update-licenses.sh` script. View the comments in the README to see what dependencies need to be installed first.
