import compression from 'compression';
import express from 'express';
const expressServer = express();
import PuppeteerAPIServer from './PuppeteerAPIServer';

// Docs serving
(function(expressServer){
    expressServer.use('/docs/api', express.static('/app/docs/api'));

    expressServer.use('/docs/source', express.static('/app/docs/source'));
})(expressServer);

var apiServer = new PuppeteerAPIServer(expressServer);

// Utilize gzip compression
// @see https://expressjs.com/en/advanced/best-practice-performance.html
expressServer.use(compression());

export default expressServer;