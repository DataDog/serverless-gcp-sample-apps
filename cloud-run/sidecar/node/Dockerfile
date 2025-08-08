FROM node:22-slim

WORKDIR /app

COPY package.json .
RUN npm install

COPY . .

ENV PORT=8080
EXPOSE 8080

ENV NODE_OPTIONS="--require dd-trace/init"

CMD ["node", "index.js"]
