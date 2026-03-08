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

// ws
fastify.register(async function (instance) {
  instance.get('/ws', { websocket: true }, (connection, req) => {
    console.log('✅ WS: Connected');
    connection.socket.on('close', () => console.log('❌ WS: Disconnected'));
    connection.socket.on('error', (err) => console.error('⚠️ WS Error:', err));
  });
});

// http
const broadcast = (data) => {
  fastify.websocketServer.clients.forEach(client => {
    if (client.readyState === 1) client.send(JSON.stringify(data));
  });
};

fastify.post('/line', async (request) => {
  broadcast({ type: 'scroll', line: parseInt(request.body.line) });
  return { status: 'ok' };
});

fastify.post('/reload', async () => {
  broadcast({ type: 'reload' });
  return { status: 'ok' };
});

fastify.get('/preview/:file', async (request, reply) => {
  const fileName = request.params.file;
  const absolutePath = path.join(process.cwd(), fileName);

  const nb = await initNotebook(path.dirname(absolutePath));
  const engine = nb.getNoteMarkdownEngine(fileName);
  const mdContent = await fs.readFile(absolutePath, 'utf8');

  const result = await engine.parseMD(mdContent, { isForPreview: true });
console.log('Result Keys:', Object.keys(result));
  const { html } = await engine.parseMD(mdContent, {
    isForPreview: true,
  });
  const template = await fs.readFile(
    path.join(__dirname, 'template.html'), 'utf8');
  reply.type('text/html').send(template.replace('{{content}}', html));
});

fastify.listen({ port: PORT, host: '0.0.0.0' }, (err) => {
  if (err) {
    console.error(err);
    process.exit(1);
  }
  console.log(`Server listening on ${PORT}`);
});
