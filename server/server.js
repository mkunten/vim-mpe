const fastify = require('fastify')({ logger: false });
const path = require('path');
const fs = require('fs').promises;
const { Notebook } = require('crossnote');

const PORT = process.env.MPE_PORT || 3000;
const JAR_PATH = process.env.MPE_JAR_PATH
  || path.join(__dirname, 'plantuml.jar');

let notebook;

async function initNotebook(notebookPath) {
  if (notebook) return notebook;
  notebook = await Notebook.init({
    notebookPath: notebookPath,
    configPath: path.join(__dirname, '.crossnote'),
    config: {
      breakOnSingleNewLine: false,
      plantumlJarPath: JAR_PATH,
      enableScriptExecution: true,
      tocEngine: "toc",
      headingIdPrefix: 'heading-',
    }
  });
  return notebook;
}

fastify.register(require('@fastify/websocket'), {
  options: {
    clientTracking: true,
    verifyClient: (info, next) => { next(true); }
  }
});
fastify.register(require('@fastify/formbody'));

fastify.register(require('@fastify/static'), {
  root: process.cwd(),
  serve: false,
});

// WS handler: /ws
fastify.register(async function (instance) {
  instance.get('/ws', { websocket: true }, (connection) => {
    console.log('✅ WS: Connected');
    connection.socket.on('close', () => console.log('❌ WS: Disconnected'));
    connection.socket.on('error', (err) => console.error('⚠️ WS Error:', err));
  });
});

const broadcast = (data) => {
  fastify.websocketServer.clients.forEach(client => {
    if (client.readyState === 1) client.send(JSON.stringify(data));
  });
};

// API handler: /_api
fastify.register(async function (api) {
  api.post('/line', async (request) => {
    broadcast({ type: 'scroll', line: parseInt(request.body.line) });
    return { status: 'ok' };
  });

  api.post('/reload', async () => {
    broadcast({ type: 'reload' });
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
    const nb = await initNotebook(path.dirname(absolutePath));
    const engine = nb.getNoteMarkdownEngine(targetPath);

    const { html } = await engine.parseMD(mdContent, { isForPreview: true });

    const cwd = process.cwd();
    const cleanHtml = html.split(`file://${cwd}`).join('');

    const template = await fs.readFile(
      path.join(__dirname, 'template.html'), 'utf8');

    reply.type('text/html').send(template.replace('{{content}}', cleanHtml));
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
  console.log(`🚀 Markdown Server listening on ${PORT}`);
  console.log(`📂 Root: ${process.cwd()}`);
});
