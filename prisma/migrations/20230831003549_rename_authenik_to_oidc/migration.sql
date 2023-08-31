/*
  Warnings:

  - The values [AUTHENTIK] on the enum `OauthProviders` will be removed. If these variants are still used in the database, this will fail.

*/

CREATE TYPE "OauthProviders_new" AS ENUM ('DISCORD', 'GITHUB', 'GOOGLE', 'AUTHENTIK', 'OIDC');
ALTER TABLE "OAuth"
  ALTER COLUMN "provider" TYPE "OauthProviders_new"
  USING "provider"::text::"OauthProviders_new";

DROP TYPE IF EXISTS "OauthProviders" CASCADE;
ALTER TYPE "OauthProviders_new" RENAME TO "OauthProviders";

-- Replace all occurrences of AUTHENTIK with OIDC
UPDATE "OAuth" SET "provider" = 'OIDC' WHERE "provider" = 'AUTHENTIK';
