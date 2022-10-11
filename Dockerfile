FROM node:16
WORKDIR /usr/app
COPY . .
RUN npm install
CMD ["node", "index.js"]