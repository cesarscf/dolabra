import { betterAuth } from "better-auth";
import { drizzleAdapter } from "better-auth/adapters/drizzle";
import { organization } from "better-auth/plugins/organization";

import { db } from "@/db";
import { env } from "@/env/server";

const sendEmailStub = async (
  kind: string,
  payload: Record<string, unknown>,
) => {
  console.log(`[auth/email:${kind}]`, payload);
};

export const auth = betterAuth({
  appName: "Dolabra",
  baseURL: env.BETTER_AUTH_URL,
  secret: env.BETTER_AUTH_SECRET,

  database: drizzleAdapter(db, { provider: "pg",usePlural:true }),

  emailAndPassword: {
    enabled: true,
    minPasswordLength: 8,
    requireEmailVerification: false,
    sendResetPassword: async ({ user, url }) => {
      await sendEmailStub("reset-password", { to: user.email, url });
    },
  },

  emailVerification: {
    sendVerificationEmail: async ({ user, url }) => {
      await sendEmailStub("verify-email", { to: user.email, url });
    },
  },

  plugins: [
    organization({
      allowUserToCreateOrganization: true,
      sendInvitationEmail: async ({ email, organization, inviter, invitation }) => {
        await sendEmailStub("org-invitation", {
          to: email,
          org: organization.name,
          inviter: inviter.user.email,
          invitationId: invitation.id,
        });
      },
    }),
  ],

  trustedOrigins: [env.BETTER_AUTH_URL],
});

export type Auth = typeof auth;
export type Session = typeof auth.$Infer.Session;
