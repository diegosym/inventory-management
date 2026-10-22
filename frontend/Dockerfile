# Frontend dev server image (D-P13): node:22 runs `npm run dev` (Vite) as the
# runtime; the compose service bind-mounts ./frontend for HMR. Deps are
# installed at build time; the guard covers the very first build, which has no
# lockfile yet (the lockfile is generated in the container and committed).
FROM node:22
WORKDIR /app
COPY package*.json ./
RUN if [ -f package-lock.json ]; then npm ci; else npm install; fi
COPY . .
CMD ["npm", "run", "dev"]
