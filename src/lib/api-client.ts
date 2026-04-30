import { treaty } from "@elysiajs/eden";

import type { App } from "@/server/api";

const baseURL =
  typeof window === "undefined"
    ? (process.env.BETTER_AUTH_URL ?? "http://localhost:3000")
    : window.location.origin;

export const api = treaty<App>(baseURL);
