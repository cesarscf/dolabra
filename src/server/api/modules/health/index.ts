import { Elysia } from "elysia";

import { betterAuthPlugin } from "@/server/api/plugins/better-auth";

export const healthModule = new Elysia({ prefix: "/health" })
  .get("/", () => ({ status: "ok" }))
  .use(betterAuthPlugin)
  .get("/me", ({ user }) => ({ user }), { auth: true });
