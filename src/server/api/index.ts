import { Elysia } from "elysia";
import { healthModule } from "./modules/health";
import { betterAuthPlugin } from "./plugins/better-auth";

export const app = new Elysia()
  .use(betterAuthPlugin)
  .group("/api", (api) => api.use(healthModule));

export type App = typeof app;
