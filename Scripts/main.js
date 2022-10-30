let langserver = null;

exports.activate = () => {
  console.log("Activating Zig Extension");
  langserver = new ZigLanguageServer();
}

exports.deactivate = () => {
  console.log("Deactivating Zig Extension");
  langserver.deactivate();
  langserver = null;
}

class ZigLanguageServer {
  constructor() {
    this.identifier = "org.flyx.zig.zls.server";
    this.config = "org.flyx.zig.zls.path";

    // Observe the configuration setting for the server's location, and restart the server on change
    nova.config.onDidChange(this.config, function(path) {
      this.start();
    }, this);
    nova.config.onDidChange(this.config + ".default", function(path) {
      this.start();
    }, this);
    this.start();
  }
    
  deactivate() {
    this.stop();
  }
    
  start() {
    this.stop();
    let path = nova.config.get(this.config);
    if (!path) {
      path = nova.config.get(this.config + ".default");
    }
    
    const proc = new Process("/usr/bin/which", {
      args: [path]
    });
    let abs_path = null;
    proc.onStdout((line) => {
      abs_path = line.trim();
    });
    proc.onDidExit((status) => {
      if (status == 0) {
        var serverOptions = {
          path: abs_path,
          args: [],
        };
        var clientOptions = {
          // The set of document syntaxes for which the server is valid
          syntaxes: ["zig"]
        };
        var client = new LanguageClient(
          `org.flyx.zig.zls`,
          path,
          serverOptions,
          clientOptions
        );
        
        try {
          client.start();
          if (nova.inDevMode()) console.log(`started language server: zig`);
          
          // Add the client to the subscriptions to be cleaned up
          nova.subscriptions.add(client);
          this.languageClient = client;
        } catch (err) {
          console.error(`while trying to start ${abs_path}:`, err)
        }
      } else {
        console.warn(`unable to find language server in PATH:`, path);
      }
    });
    proc.start();
  }
    
  stop() {
    if (this.languageClient) {
      this.languageClient.stop();
      nova.subscriptions.remove(this.languageClient);
      this.languageClient = null;
    }
  }
}