import { isAbsolute, relative, resolve, sep } from 'node:path';
import { fileURLToPath } from 'node:url';
import { defineConfig, loadEnv } from 'vite';

const frontendDir = fileURLToPath(new URL('.', import.meta.url));
const projectDir = resolve(frontendDir, '..');

function trimSlashes(value) {
  return value.replace(/^\/+|\/+$/g, '');
}

function urlPathFromRelativePath(value) {
  return value
    .split(sep)
    .filter(Boolean)
    .map(encodeURIComponent)
    .join('/');
}

function resolveApiProxyPath(env) {
  if (env.VITE_API_PROXY_PATH?.trim()) {
    return `/${trimSlashes(env.VITE_API_PROXY_PATH.trim())}`;
  }

  const defaultDocumentRoot = process.platform === 'win32'
    ? 'C:\\xampp\\htdocs'
    : '/opt/lampp/htdocs';
  const documentRoot = resolve(
    env.VITE_APACHE_DOCUMENT_ROOT?.trim() || defaultDocumentRoot,
  );
  const projectWebPath = relative(documentRoot, projectDir);

  if (!projectWebPath || projectWebPath.startsWith('..') || isAbsolute(projectWebPath)) {
    throw new Error(
      `Project directory "${projectDir}" is not below Apache document root "${documentRoot}". ` +
      'Set VITE_APACHE_DOCUMENT_ROOT or VITE_API_PROXY_PATH.',
    );
  }

  return `/${urlPathFromRelativePath(projectWebPath)}/backend/api`;
}

export default defineConfig(({ mode }) => {
  const env = loadEnv(mode, frontendDir, '');
  const target = env.VITE_API_PROXY_TARGET?.trim() || 'http://localhost';
  const apiProxyPath = resolveApiProxyPath(env);

  return {
    server: {
      proxy: {
        '/api': {
          target,
          changeOrigin: true,
          secure: false,
          rewrite: requestPath =>
            `${apiProxyPath}${requestPath.slice('/api'.length)}`,
        },
      },
    },
  };
});
