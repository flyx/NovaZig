const LanguageServer = require("language-server.js").LanguageServer;
const Config = require("config.js").Config;
const Formatter = require("formatter.js").Formatter;

let config = null;
let taskprovider = null;

exports.activate = () => {
  if (nova.inDevMode()) console.log("Activating Zig Extension");
  config = new Config();
  nova.subscriptions.add(new LanguageServer(
    "org.flyx.zig.client", {
      syntaxes: ["zig"]
    }, config.langServer.path
  ));
  nova.subscriptions.add(new Formatter(
    "org.flyx.zig.command.fmt",
    config.compiler.path, [ "fmt", "--stdin" ],
    [ "zig" ],
    config.compiler.formatOnSave
  ));
  taskprovider = new ZigTaskProvider();
}

exports.deactivate = () => {
  if (nova.inDevMode()) console.log("Deactivating Zig Extension");
}

class ZigTaskProvider {
  static identifier = "org.flyx.zig.tasks";
  
  static zigBuild(...options) {
    return new TaskProcessAction("/usr/bin/env", {
      args: [
        config.compiler.path.value(),
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
    config.compiler.path.onDidChange(() => this.reload());
    this.reload();
  }
  
  reload() {
    let tasks = [];
    const buildZig = ZigTaskProvider.findBuildZig();
    const zigPath = config.compiler.path.value();
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
        console.error(`[reading build.zig] ${line}`);
      });
      query.onDidExit((status) => {
        if (status != 0) {
          console.log("`[reading build.zig] zig build -h` exited with non-zero status!");
        }
        this.tasks = tasks;
        nova.workspace.reloadTasks(ZigTaskProvider.identifier);
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