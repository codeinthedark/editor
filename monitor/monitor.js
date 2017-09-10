const fs = require('fs');
const http = require('http');
const cors = require('cors');
const express = require('express');
const bodyParser = require('body-parser');
const app = express();

app.use(bodyParser.urlencoded({extended: true}));
app.use(bodyParser.json());
app.use(bodyParser.text());
app.use(cors());

const router = express.Router();

const users = {};

function frameContent (documentSrc, username) {
  const encodedSrc = encodeURIComponent(documentSrc);
  const containerMarkup = `
  <html>
    <head>
      <style>
        @font-face {
          font-family: "Press Start 2P";
          src: url(/assets/PressStart2P-Regular.ttf) format("truetype");
        }
      
        * {
          margin: 0;
          padding: 0;
        }
        
        body {
          font-family: "Press Start 2P", sans-serif;
          height: 100vh;
          background-color: black;
          color: white;
          display: flex;
          flex-direction: column;
        }
        
        h1 {
          background-color: #3a9364;
          text-align: center;
          margin: 0 auto;
          padding: 8px 25px;
          font-size: 40px;
        }
        
        iframe {
          border-style: none;
          background-color: white;
          flex: 1;
          margin: 0 30px 30px;
        }
      </style>
    </head>
    
    <body>
      <h1>${username}</h1>
      <script src="/socket.io/socket.io.js"></script>
      <script>
        var iframe = document.createElement('iframe');
        var html = '';
        iframe.setAttribute('sandbox', 'allow-same-origin');
        document.body.appendChild(iframe);
        iframe.contentWindow.document.open();
        iframe.contentWindow.document.write(decodeURIComponent('${encodedSrc}'));
        iframe.contentWindow.document.close();

        var socket = io('/${username}');
        socket.on('newmarkup', function (markupEvent) {
          iframe.contentWindow.document.open();
          iframe.contentWindow.document.write(markupEvent.markup);
          iframe.contentWindow.document.close();
        });
      </script>    
    </body>
  </html>
  `;
    
  return containerMarkup;
}

router.route('/')

  .get((req, res) => {
    let markup = `
    <html>
      <head>
        <style>
        </style>
      </head>
      
      <body>
    `;
    Object.keys(users).forEach((userName) => {
      markup += `<a href='/${userName}'>${userName}</a>`;
    });
    markup += `
      </body>
    </html>
    `;
    res.send(markup);
  })
;

router.route('/assets/:filename')
  .get((req, res) => {
    let file = null;
    try {
      file = fs.readFileSync(`assets/${req.params.filename}`);
      res.send(file);
    } catch (e) {
      res.status(404).send('File not found');
    }
  })
;

router.route('/:username')
  .get((req, res) => {
    const markup = users[req.params.username] ?
      users[req.params.username] :
      '<body style="display: flex;justify-content: center;align-items: center;font-family: sans-serif;"><h1>Waiting for contestant...</h1></body>';
    io.of(`/${req.params.username}`); // Force socket.io to initialize the namespace

    res.send(frameContent(markup, req.params.username));
  })

  .post((req, res) => {
    users[req.params.username] = req.body.markup;
    io.of(`/${req.params.username}`).emit('newmarkup', {markup: req.body.markup});
    res.send();
  })
;

app.use('/', router);

let port = 1337;
if (process.argv.length > 2) {
  port = Number(process.argv[2]);
}

const httpServer = http.createServer(app);
const io = require('socket.io')(httpServer);

httpServer.listen(port);

console.log('Listening on port ' + port);
