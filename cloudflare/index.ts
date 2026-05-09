import { env as workerEnv } from "cloudflare:workers";
import { Container } from "@cloudflare/containers";

const forwardedEnvKeys = [
  "CLI_PROXY_CONFIG_B64",
  "PGSTORE_DSN",
  "PGSTORE_SCHEMA",
  "PGSTORE_LOCAL_PATH",
  "GITSTORE_GIT_URL",
  "GITSTORE_GIT_USERNAME",
  "GITSTORE_GIT_TOKEN",
  "GITSTORE_GIT_BRANCH",
  "GITSTORE_LOCAL_PATH",
  "OBJECTSTORE_ENDPOINT",
  "OBJECTSTORE_ACCESS_KEY",
  "OBJECTSTORE_SECRET_KEY",
  "OBJECTSTORE_BUCKET",
  "OBJECTSTORE_LOCAL_PATH",
] as const;

type RuntimeEnv = Record<string, unknown> & {
  CLI_PROXY_CONTAINER: DurableObjectNamespace<CLIProxyAPIContainer>;
};

function readStringEnv(source: Record<string, unknown>, key: string): string {
  const value = source[key];
  return typeof value === "string" ? value : "";
}

function parsePort(value: string): number {
  const parsed = Number.parseInt(value, 10);
  return Number.isFinite(parsed) && parsed > 0 ? parsed : 8317;
}

function collectContainerEnv(source: Record<string, unknown>): Record<string, string> {
  const envVars: Record<string, string> = {
    DEPLOY: readStringEnv(source, "DEPLOY") || "cloud",
    PORT: readStringEnv(source, "PORT") || "8317",
  };

  for (const key of forwardedEnvKeys) {
    const value = readStringEnv(source, key);
    if (value !== "") {
      envVars[key] = value;
    }
  }

  return envVars;
}

const containerEnv = collectContainerEnv(workerEnv as Record<string, unknown>);

export class CLIProxyAPIContainer extends Container {
  defaultPort = parsePort(containerEnv.PORT);
  pingEndpoint = "localhost/healthz";
  sleepAfter = readStringEnv(workerEnv as Record<string, unknown>, "CONTAINER_SLEEP_AFTER") || "10m";
  envVars = containerEnv;

  override onError(error: unknown): never {
    console.error("CLIProxyAPI container failed to start", error);
    throw error;
  }
}

export default {
  async fetch(request: Request, env: RuntimeEnv): Promise<Response> {
    const containerId = env.CLI_PROXY_CONTAINER.idFromName("primary");
    return env.CLI_PROXY_CONTAINER.get(containerId).fetch(request);
  },
};
