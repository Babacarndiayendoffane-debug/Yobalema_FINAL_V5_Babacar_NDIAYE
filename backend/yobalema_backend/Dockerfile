FROM node:22-alpine
WORKDIR /app
COPY package.json package-lock.json* ./
RUN npm install --omit=dev
COPY prisma ./prisma
RUN npx prisma generate
COPY src ./src
COPY public ./public
COPY tsconfig.json ./tsconfig.json
EXPOSE 4000
CMD ["sh","-c","npx prisma db push && npm run seed && npm run dev"]
