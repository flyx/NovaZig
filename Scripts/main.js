let langserver = null;
let taskprovider = null;

exports.activate = () => {
  console.log("Activating Zig Extension");
  langserver = new ZigLanguageServer();
  taskprovider = new ZigTaskProvider();
  nova.commands.register(
    ZigFormatter.identifier, ZigFormatter.formatDocument
  );
  nova.workspace.onDidAddTextEditor((editor) => {
    editor.onWillSave(async (textEditor) => {
      if (getConfig("org.flyx.zig.fmt")) {
        await nova.commands.invoke(ZigFormatter.identifier, textEditor);
      }
    });
  });
}

exports.deactivate = () => {
  console.log("Deactivating Zig Extension");
  langserver.deactivate();
  langserver = null;
}

function getConfig(id) {
  let res = nova.workspace.config.get(id);
  if (res == null) res = nova.config.get(id + ".default");
  return res;
}

class ZigFormatter {
  static identifier = "org.flyx.zig.command.fmt";
  
  static formatDocument(a, b) {
    const editor = b ? b : a;
    const doc = editor.document;
    if (doc.syntax == "zig") {
      console.log("attempting formatting");
      
      const formatter = new Process("/usr/bin/env", {
        cwd: nova.workspace.path,
        stdio: "pipe",
        args: [
          getConfig("org.flyx.zig.path"),
          "fmt",
          "--stdin"
        ],
      });
      formatter.onStderr((line) => console.error(`[zig fmt] ${line}`));
      
      const all = new Range(0, doc.length);
      
      return new Promise((resolve, reject) => {
        let result = "";
        formatter.onStdout((line) => result += line);
        formatter.onDidExit((status) => {
          if (status == 0) {
            editor.edit((edit) => {
              edit.replace(all, result);
            }).then(() => resolve());
          } else (reject());
        });
        
        const writer = formatter.stdin.getWriter();
        writer.ready.then(() => {
          writer.write(doc.getTextInRange(all));
          console.log("finished writing");
          writer.close();
        });
        
        console.log("starting formatting");
        formatter.start();
      });
    }
  }
}

class ZigTaskProvider {
  static identifier = "org.flyx.zig.tasks";
  static config     = "org.flyx.zig.path";
  
  static zigBuild(...options) {
    return new TaskProcessAction("/usr/bin/env", {
      args: [
        getConfig("org.flyx.zig.path"),
        "build",
        ...options
      ]
    });
  }
  
  static findBuildZig() {
    let path = nova.path.join(nova.workspace.path, "build.zig");
    let stat = nova.fs.stat(path);
    if (stat != null) {
      if (!stat.isFile()) {
        console.error("build.zig in workspace is not a file!");
        return null;
      }
      return path;
    }
    return null;
  }
  
  constructor() {
    this.tasks = [];
    nova.assistants.registerTaskAssistant(this, {
      identifier: ZigTaskProvider.identifier,
      name: "Zig Build",
    });
    nova.fs.watch("build.zig", () => this.reload());
    nova.workspace.config.onDidChange(ZigTaskProvider.config, () => this.reload());
    nova.config.onDidChange(ZigTaskProvider.config + ".default", () => this.reload());
    this.reload();
  }
  
  reload() {
    let tasks = [];
    const buildZig = ZigTaskProvider.findBuildZig();
    const zigPath = getConfig("org.flyx.zig.path");
    if (buildZig != null && zigPath != null) {
      const query = new Process("/usr/bin/env", {
        cwd: nova.workspace.path,
        args: [
          zigPath,
          "build",
          "-h"
        ],
      });
      let state = 0;
      query.onStdout((line) => {
        switch (state) {
          case 0: if (line == "Steps:\n") state = 1; break;
          case 1: if (line == "General Options:\n") state = 2; else {
            const content = line.trim().split(/[ \t]+/);
            if (content.length > 1) {
              let task = new Task(content[0]);
              task.setAction(Task.Build, ZigTaskProvider.zigBuild(content[0]));
              tasks.push(task);
            }
          } break;
          case 2: break;
        }
      });
      query.onStderr((line) => {
        console.error(`[zig build -h] ${line}`);
      });
      query.onDidExit((status) => {
        if (status == 0) {
          this.tasks = tasks;
          nova.workspace.reloadTasks(ZigTaskProvider.identifier);
        } else {
          console.log("`zig build -h` exited with non-zero status!");
        }
      });
      query.start();
    } else {
      if (buildZig == null) console.log("no build.zig in workspace");
      else if (zigPath == "") console.error("failed to find zig executable (please set in settings)!");
      this.tasks = tasks;
      nova.workspace.reloadTasks(ZigTaskProvider.identifier);
    }
  }
  
  provideTasks() {
    return this.tasks;
  }
}

class ZigLanguageServer {
  static identifier = "org.flyx.zig.zls.server";
  static config     = "org.flyx.zig.zls.path";
  
  constructor() {
    // Observe the configuration setting for the server's location, and restart the server on change
    nova.config.onDidChange(ZigLanguageServer.config, function(path) {
      this.start();
    }, this);
    nova.config.onDidChange(ZigLanguageServer.config + ".default", function(path) {
      this.start();
    }, this);
    this.start();
  }
    
  deactivate() {
    this.stop();
  }
    
  start() {
    this.stop();
    const path = getConfig(ZigLanguageServer.config);
    
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