import hxp.Haxelib;
import hxp.Log;
import hxp.Path;
import hxp.System;
import lime.tools.ConfigHelper;
import sys.FileSystem;

/**
	Picks the runtime the tool runs on. `haxelib run swf` always starts `run.n` on Neko; its first step
	is to ask here, and when another runtime is wanted the same arguments go to it and its exit code is
	passed on. All three write the same bundles byte for byte:

	- `neko`: `run.n`, the default.
	- `hl`: `run.hl` on HashLink's JIT, several times faster on large SWFs and without Neko's heap limit.
	  HashLink comes from lime: the runtime lime ships for the host in `templates/bin/hl`, with `lime.hdll`
	  from its `ndll` folder put on the library path, or else `hl` on the PATH.
	- `hlc`: `bin/hlc/<platform>/swftool`, the tool compiled from HL/C to a native executable by
	  `haxelib run swf rebuild hlc`; a little faster again, with no JIT start-up.

	The choice, first match wins: `-neko`, `-hl` (or `-hashlink`) or `-hlc` on the command line, the
	SWF_RUNTIME environment variable, `lime config SWF_RUNTIME <name>`, and Neko by default. A runtime
	that is asked for but not built falls back to the next one with a warning.

	`run.hl` and `run.n` come from `haxe rebuild.hxml`; `haxelib run swf rebuild` runs it.
**/
class ToolRuntime
{
	/** The exit code of the tool run on another runtime, or null when it is to run here on Neko. **/
	public static function exitCode(arguments:Array<String>):Null<Int>
	{
		var runtime = wanted(arguments);
		if (runtime == "neko") return null;

		// this runs before the tool reads its flags, which is when it would turn verbose on
		if (arguments.indexOf("-verbose") > -1) Log.verbose = true;

		var toolDirectory = Path.directory(Sys.programPath());

		if (runtime == "hlc")
		{
			var executable = hlcExecutable(toolDirectory);
			if (FileSystem.exists(executable))
			{
				Log.info("", " - \x1b[1mRunning on HL/C:\x1b[0m " + executable);
				addLibraryPath(Path.directory(executable));
				return Sys.command(executable, arguments);
			}
			Log.warn("HL/C was asked for, but " + executable + " is missing (haxelib run swf rebuild hlc builds it); running on HashLink");
		}

		var runHL = Path.combine(toolDirectory, "run.hl");
		if (!FileSystem.exists(runHL))
		{
			Log.warn("HashLink was asked for, but run.hl is missing (haxe rebuild.hxml builds it); running on Neko");
			return null;
		}

		var hl = "hl";
		var limePath = Haxelib.getPath(new Haxelib("lime"), true);
		if (limePath != null)
		{
			var runtimeDir = Path.combine(limePath, "templates/bin/hl/" + platformDirectory());
			var bundled = Path.combine(runtimeDir, System.hostPlatform == WINDOWS ? "hl.exe" : "hl");
			if (FileSystem.exists(bundled))
			{
				hl = bundled;
				addLibraryPath(runtimeDir);
				addLibraryPath(Path.combine(limePath, "ndll/" + platformDirectory()));
			}
		}

		Log.info("", " - \x1b[1mRunning on HashLink:\x1b[0m " + hl);
		return Sys.command(hl, [runHL].concat(arguments));
	}

	/** The swf haxelib's folder, where run.n, run.hl and the templates are, found from the running tool itself. **/
	public static function toolDirectory():String
	{
		var directory = Path.directory(Sys.programPath());
		#if hl
		// the HL/C executable sits three folders down, in bin/hlc/<platform>/ (see hlcExecutable)
		if (!StringTools.endsWith(Sys.programPath(), ".hl")) directory = Path.directory(Path.directory(Path.directory(directory)));
		#end
		return directory;
	}

	/** Where `rebuild hlc` puts the native tool: bin/hlc/<platform>/swftool, with .exe on Windows. **/
	public static function hlcExecutable(toolDirectory:String):String
	{
		return Path.combine(toolDirectory, "bin/hlc/" + platformDirectory() + "/swftool" + (System.hostPlatform == WINDOWS ? ".exe" : ""));
	}

	/** The folder names lime uses for the host's HashLink runtime and libraries. **/
	public static function platformDirectory():String
	{
		return switch (System.hostPlatform)
		{
			case WINDOWS: "Windows64";
			case MAC: "Mac64";
			default: "Linux64";
		}
	}

	private static function wanted(arguments:Array<String>):String
	{
		// the runtimes are rebuilt from the Neko tool, whatever is configured
		if (arguments[0] == "rebuild" || arguments.indexOf("-neko") > -1) return "neko";
		if (arguments.indexOf("-hlc") > -1) return "hlc";
		if (arguments.indexOf("-hl") > -1 || arguments.indexOf("-hashlink") > -1) return "hl";

		var setting = Sys.getEnv("SWF_RUNTIME");
		if (setting == null || setting == "") setting = ConfigHelper.getConfigValue("SWF_RUNTIME");
		if (setting == null) return "neko";
		return switch (setting.toLowerCase())
		{
			case "hl", "hashlink": "hl";
			case "hlc": "hlc";
			default: "neko";
		}
	}

	/** Puts `directory` first on the path the host uses to find shared libraries, for the child process. **/
	private static function addLibraryPath(directory:String):Void
	{
		var name = switch (System.hostPlatform)
		{
			case WINDOWS: "PATH";
			case MAC: "DYLD_LIBRARY_PATH";
			default: "LD_LIBRARY_PATH";
		}
		var current = Sys.getEnv(name);
		var separator = System.hostPlatform == WINDOWS ? ";" : ":";
		Sys.putEnv(name, current != null && current != "" ? directory + separator + current : directory);
	}
}
