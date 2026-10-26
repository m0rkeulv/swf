import hxp.Haxelib;
import hxp.Log;
import hxp.Path;
import hxp.System;
import sys.FileSystem;
import sys.io.File;

/**
	`haxelib run swf rebuild [neko|hl|hlc|all]`: builds the tool's runtimes (see ToolRuntime).

	`neko` and `hl` run `haxe rebuild.hxml`, which writes `run.n` and `run.hl`. `hlc` runs
	`haxe rebuild-hlc.hxml` for the HL/C sources, then compiles them to `bin/hlc/<platform>/swftool`
	with the host's C compiler, the way lime builds its own `hlc` target: Visual Studio's `cl` found
	through `vswhere` on Windows, `gcc` or `clang` elsewhere, against the HashLink headers and
	libraries lime ships, with lime's list of Windows macros undefined, as they clash with generated
	field names. The runtime libraries are copied next to the executable. Without a C compiler the
	`hlc` build fails and the other two are unaffected.
**/
class Rebuild
{
	// the macros lime undefines for its hlc target (HashlinkHelper): Windows headers define them, and
	// Haxe fields of the same names become C struct members
	private static var UNDEFINED_MACROS = [
		"BIG_ENDIAN", "LITTLE_ENDIAN", "TRUE", "FALSE", "BOOLEAN", "ERROR", "NO_ERROR", "DELETE", "OPTIONS", "IN", "OUT", "ALTERNATE", "OPTIONAL",
		"DOUBLE_CLICK", "DIFFERENCE", "POINT", "RECT", "OVERFLOW", "UNDERFLOW", "DOMAIN", "TRANSPARENT", "CONST", "CopyFile", "COLOR_HIGHLIGHT", "__valid",
		"WAIT_FAILED"
	];

	public static function run(what:String, toolDirectory:String):Void
	{
		if (what == null) what = "all";
		switch (what)
		{
			case "neko", "hl":
				bytecode(toolDirectory);
			case "hlc":
				native(toolDirectory);
			case "all":
				bytecode(toolDirectory);
				native(toolDirectory);
			default:
				Log.error("Unknown runtime \"" + what + "\": use neko, hl, hlc or all");
		}
	}

	/** run.n and run.hl, from rebuild.hxml. **/
	private static function bytecode(toolDirectory:String):Void
	{
		Log.info("", " - \x1b[1mBuilding:\x1b[0m run.n and run.hl");
		System.runCommand(toolDirectory, "haxe", ["rebuild.hxml"]);
	}

	/** The native tool, from rebuild-hlc.hxml and the host's C compiler. **/
	private static function native(toolDirectory:String):Void
	{
		var objDirectory = Path.combine(toolDirectory, "obj/hlc");
		var source = Path.combine(objDirectory, "tool.c");
		var executable = ToolRuntime.hlcExecutable(toolDirectory);
		var binDirectory = Path.directory(executable);

		var limePath = Haxelib.getPath(new Haxelib("lime"), true);
		if (limePath == null) Log.error("lime is needed: it ships the HashLink headers and libraries");
		var platform = ToolRuntime.platformDirectory();
		var includeDirectory = Path.combine(limePath, "templates/bin/hl/include");
		var runtimeDirectory = Path.combine(limePath, "templates/bin/hl/" + platform);
		var ndllDirectory = Path.combine(limePath, "ndll/" + platform);

		Log.info("", " - \x1b[1mGenerating:\x1b[0m " + source);
		System.runCommand(toolDirectory, "haxe", ["rebuild-hlc.hxml"]);

		var text = File.getContent(source);
		var index = text.indexOf("#ifndef HL_MAKE");
		if (index < 0) Log.error("Unexpected HL/C output: no HL_MAKE section in " + source);
		var undefines = "// Windows macros that clash with generated field names (the list lime uses for its hlc target)\n";
		for (name in UNDEFINED_MACROS)
			undefines += "#undef " + name + "\n";
		File.saveContent(source, text.substr(0, index) + undefines + text.substr(index));

		System.mkdir(binDirectory);
		Log.info("", " - \x1b[1mCompiling:\x1b[0m " + executable);
		if (System.hostPlatform == WINDOWS)
		{
			compileWithVisualStudio(source, executable, includeDirectory, objDirectory, [
				Path.combine(runtimeDirectory, "libhl.lib"),
				Path.combine(runtimeDirectory, "fmt.lib"),
				Path.combine(ndllDirectory, "lime.lib")
			]);
		}
		else
		{
			// the executable finds libhl and the hdlls next to itself, as lime's hlc applications do
			var rpath = System.hostPlatform == MAC ? "-Wl,-rpath,@executable_path" : "-Wl,-rpath,$ORIGIN";
			var args = ["-O3", "-std=c11", "-o", executable, rpath, "-I", includeDirectory, "-I", objDirectory, source, "-L", runtimeDirectory, "-L", ndllDirectory, "-lhl"];
			for (library in ["fmt.hdll", "lime.hdll"])
				args.push(System.hostPlatform == MAC ? Path.combine(library == "lime.hdll" ? ndllDirectory : runtimeDirectory, library) : "-l:" + library);
			args.push("-lm");
			// gcc 14 and clang 22 made incompatible-pointer-types an error, but assignment to Dynamic needs it
			args.push("-Wno-error=incompatible-pointer-types");
			System.runCommand("", System.hostPlatform == MAC ? "clang" : "gcc", args);
		}

		// the HashLink runtime and the libraries the tool uses, next to the executable
		for (file in FileSystem.readDirectory(runtimeDirectory))
		{
			switch (Path.extension(file))
			{
				case "dll", "so", "dylib", "hdll":
					System.copyFile(Path.combine(runtimeDirectory, file), Path.combine(binDirectory, file));
				default:
			}
		}
		var lime = "lime.hdll";
		System.copyFile(Path.combine(ndllDirectory, lime), Path.combine(binDirectory, lime));
		Log.info("", " - \x1b[1mBuilt:\x1b[0m " + executable);
	}

	/** cl from the newest Visual Studio with the C++ tools, through vcvarsall, as lime does for its hlc target. **/
	private static function compileWithVisualStudio(source:String, executable:String, includeDirectory:String, objDirectory:String,
			libraries:Array<String>):Void
	{
		var vswhere = Sys.getEnv("ProgramFiles(x86)") + "\\Microsoft Visual Studio\\Installer\\vswhere.exe";
		if (!FileSystem.exists(vswhere)) Log.error("Visual Studio with the C++ tools is needed to build the HL/C tool (vswhere.exe not found)");
		var visualStudio = StringTools.trim(System.runProcess("", vswhere, [
			"-latest", "-products", "*", "-requires", "Microsoft.VisualStudio.Component.VC.Tools.x86.x64", "-property", "installationPath"
		]));
		if (visualStudio == "") Log.error("Visual Studio with the C++ tools is needed to build the HL/C tool (none found by vswhere)");
		var vcvarsall = visualStudio + "\\VC\\Auxiliary\\Build\\vcvarsall.bat";

		// vcvarsall sets up the environment cl needs; both run in one cmd so it carries over
		var escape = function(arg:String):String return ~/([&|\(\)<>\^ ])/g.replace(arg, "^$1");
		var vcvarsallCommand = [vcvarsall, "x64"].map(escape);
		var clCommand = ["cl.exe", "/nologo", "/Ox", "/MD", "/Fe:" + executable, "/I", includeDirectory, "/I", objDirectory, source].concat(libraries);
		clCommand = clCommand.concat(["/link", "/subsystem:console"]).map(escape);
		System.runCommand(objDirectory, "cmd.exe", ["/s", "/c", vcvarsallCommand.join(" ") + " && " + clCommand.join(" ")]);
	}
}
