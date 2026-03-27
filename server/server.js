// server.js
import fs from 'fs/promises';
import path from 'path';
import { fileURLToPath } from 'url';

import fastifyFormbody from '@fastify/formbody';
import fastifyStatic from '@fastify/static';
import fastifyWebsocket from '@fastify/websocket';
import { Notebook } from 'crossnote';
import Fastify from 'fastify';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const fastify = Fastify({ logger: false });
const PORT = process.env.MPE_PORT || 3000;

const notebookCache = new Map();

async function getNotebook(absoluteFilePath) {
  const projectDir = path.dirname(absoluteFilePath);
  if (notebookCache.has(projectDir)) {
    return notebookCache.get(projectDir);
  }
  const notebook = await Notebook.init({
    notebookPath: projectDir,
    configPath: path.join(projectDir, '.crossnote'),
    config: {
      breakOnSingleNewLine: true,
      enableScriptExecution: true,
      headingIdPrefix: 'heading-',
      mermaidTheme: process.env.MPE_MERMAID_THEME || 'default',
      plantumlJarPath: process.env.MPE_JAR_PATH
        || path.join(__dirname, 'plantuml.jar'),
      tocEngine: "toc",
    }
  });
  notebookCache.set(projectDir, notebook);
  return notebook;
}

fastify.register(fastifyFormbody);
fastify.register(fastifyStatic, {
  root: process.cwd(),
  serve: false,
});
fastify.register(fastifyWebsocket);

// WS handler: /ws
fastify.register(async function(fastify) {
  fastify.get('/ws', { websocket: true }, (connection, _) => {
    console.log('WS: Connection Established');
    connection.socket.on('message', (message) => {
      try {
        const data = JSON.parse(message);
        if (data.type === 'init') {
          connection.socket.currentFile = data.file;
          console.log(`WS: Client registered for file: ${data.file}`);
        }
      } catch (e) {}
    });
    connection.socket.on('close', () => console.log('WS: Disconnected'));
    connection.socket.on('error', () =>
      console.error('WS Socket Error: ', err));
  });
});

// WS Broadcast
const broadcast = (data) => {
  fastify.websocketServer.clients.forEach(client => {
    if (client.readyState === 1) {
      if (!data.file || client.currentFile === data.file) {
        client.send(JSON.stringify(data));
      }
    }
  });
};

// API handler: /_api/{scroll,reload}
fastify.register(async function (api) {
  api.post('/scroll', async (request) => {
    broadcast({
      type: 'scroll',
      file: request.body.file,
      line: parseInt(request.body.line)
    });
    return { status: 'ok' };
  });

  api.post('/reload', async (request) => {
    broadcast({
      type: 'reload',
      file: request.body.file
    });
    return { status: 'ok' };
  });
}, { prefix: '/_api' });

// main handler: /
fastify.get('/*', async (request, reply) => {
  const targetPath = request.params['*'];
  if (!targetPath) return reply.code(404).send('Not Found');

  const absolutePath = path.join(process.cwd(), targetPath);

  // non markdown
  if (!targetPath.endsWith('.md')) {
    try {
      return reply.sendFile(targetPath);
    } catch (e) {
      return reply.code(404).send('Not Found');
    }
  }

  // markdown
  try {
    const mdContent = await fs.readFile(absolutePath, 'utf8');
    const nb = await getNotebook(absolutePath);
    const engine = nb.getNoteMarkdownEngine(targetPath);

    const { html } = await engine
      .parseMD(mdContent, { isForPreview: true });

    const cwd = process.cwd();
    const cleanHtml = html.split(`file://${cwd}`).join('');

    const template = await fs.readFile(
      path.join(__dirname, 'template.html'), 'utf8');

    const htmlResponse = template
      .replace('{{content}}', cleanHtml)
      .replace('{{filename}}', targetPath)
      .replace('{{mermaid_theme}}',
        process.env.MPE_MERMAID_THEME || 'default');

    reply.type('text/html').send(htmlResponse);
  } catch (err) {
    console.error('Render Error:', err);
    reply.code(500).send('Internal Server Error');
  }
});

fastify.listen({ port: PORT, host: '0.0.0.0' }, (err) => {
  if (err) {
    console.error(err);
    process.exit(1);
  }
  console.log(`MPE Server is listening on port ${PORT}`);
  console.log(`Root: ${process.cwd()}`);
});
