[![MIT License](https://img.shields.io/badge/license-MIT-blue.svg?style=flat)](LICENSE.md) [![Haxelib Version](https://img.shields.io/github/tag/openfl/swf.svg?style=flat&label=haxelib)](http://lib.haxe.org/p/swf)

SWF
===

Provides runtime or compile-time parsing and processing of SWF/SWC assets for use with OpenFL. SWF content can then be used for design or (beta) animation in projects deployed to desktop, web, mobile and console targets in both web and native technologies.

Use of this library for static design content has a track record in production. Use of this library for animation should be considered beta and may not be optimized for performance. Contributions to improve performance are welcome!

There are three primary code paths within the library:

 1. SWF

 Type "swf" provides full parsing of the SWF/SWC format (based upon the original as3swf library by Claus Wahlers). This code is optimized primarily for completeness and accuracy rather than performance. Once a SWF has been fully parsed, it can be exported into a new runtime-optimized format (SWFLite, Animate) or there is a rudimentary implemention available for using the parsed SWF content directly at runtime. Those interested in improving this code path may be interested in looking at https://github.com/openfl/openfl-player as a start to testing and improving runtime SWF loading and playback.

 2. SWFLite

 Type "swflite" is an older exporter format, previously integrated within OpenFL. The code exists in this library primarily for historical reasons. After parsing the SWF content using the "swf" code path, a new format was generated with the help of the Haxe serializer. Despite runtime file-size and performance improvements based on the format, the reliance on Haxe serialization had downsides to backward compatibility.

 3. Animate

 Type "animate" is the latest exporter format, and the default for all targets. It combines the benefits of the "swflite" format while writing to JSON and compressing all assets into a single ZIP file. It can be iteratively improved while maintaining backward compatibility. The Macromedia SWF format also has these benefits, however it is optimized for a runtime different from modern web browsers. For example, images in a Macromedia SWF file may have premultiplied alpha applied to bitmaps already. There is no quick way to render this properly using HTML5 canvas. The Animate library format offers an opportunity for to pre-process SWF content into a flexible format optimized for modern production-use.

 4. Animate, binary

 Type "animate-binary" is the "animate" format with its document stored as `data.bin` instead of `data.json`: the same symbols, written by `AnimateBinaryWriter` and read by `AnimateBinaryReader` straight into the library without a text parse. On native targets, where `Json.parse` is written in Haxe, loading a vector-heavy library is around eight times faster; browsers parse JSON natively, so "animate" stays the better choice for html5. Pick per target with `if` / `unless` on the library tag. Everything else is shared with "animate": the ZIP, the bitmaps, `generate`, `AnimateLibrary` and its API.

This library can be called automatically by the OpenFL/Lime command-line tools to process `<library />` tags, or it can be used on the command-line to process SWF files into Animate ZIP files.


Usage
=====

First, make sure that `<haxelib name="swf" />` has been added to your project.

Then, you can add `<library path="to/your.swf" preload="true" />` to include a SWF library. This will be available at runtime using the file name of the SWF (minus the ".swf") or you can add `id="my-unique-id"` to specify a custom name.

There is a (beta) option for `generate="true"` to generate Haxe classes for each "Export for ActionScript" type in the SWF file. The `preload` is also optional, but is recommended to simplify use.

To load the binary document on native targets and the JSON one on the web, give the same SWF both types:

```xml
<library path="to/your.swf" type="animate" if="html5" />
<library path="to/your.swf" type="animate-binary" unless="html5" />
```

You can create an "Export for ActionScript" clip from a SWF like this:

```haxe
var clip = Assets.getMovieClip("my-swf:MyMovieClipName");
```

If you would prefer to create the whole timeline, use an empty clip name:

```haxe
var timeline = Assets.getMovieClip("my-swf:");
```

If you use the 'generate' option, you would instead create a new instance like this:

```haxe
var clip = new MyMovieClipName();
```

You can also process files from the command-line, and load them later:

```bash
haxelib run swf process
haxelib run swf process path/to/swfs
haxelib run swf process test.swf
haxelib run swf process test.swf path/to/test.zip
haxelib run swf process test.swf output/path
haxelib run swf process -binary test.swf
```

`-binary` writes the "animate-binary" document (`data.bin`) instead of `data.json`; the ZIP loads the same way.


Running the tool on HashLink
============================

The tool runs on Neko by default. It can run on HashLink instead, which is several times faster on large SWFs and has no fixed heap limit, and it writes the same bundles byte for byte. Turn it on for every build with

    lime config SWF_RUNTIME hl

or for one session with the environment variable `SWF_RUNTIME=hl`, or for one command with `haxelib run swf process -hashlink ...`; `-neko` or `SWF_RUNTIME=neko` forces Neko. HashLink itself comes from Lime: the runtime it ships for the host, with `lime.hdll` from its `ndll` folder, or else `hl` on the PATH. When `run.hl` is missing, the tool runs on Neko with a warning.

The tool can also run as a native executable compiled from HL/C, which starts faster than HashLink and is otherwise the same tool. `haxelib run swf rebuild hlc` builds it into `bin/hlc/<platform>/` with the host's C compiler (Visual Studio's C++ tools on Windows, gcc or clang elsewhere); `lime config SWF_RUNTIME hlc`, `SWF_RUNTIME=hlc` or `-hlc` selects it. When it has not been built, the tool runs on HashLink with a warning.

`haxelib run swf rebuild` builds the tool for every runtime, or for one of them (`neko`, `hl` or `hlc`); `haxe rebuild.hxml` builds just `run.n` and `run.hl`.

For example:

```bash
haxelib run swf process test.swf
```

This will generate a "test.zip" file which can be loaded at runtime later:

```haxe
import swf.exporters.animate.AnimateLibrary;
import openfl.utils.Assets;

...

AnimateLibrary.loadFromFile("path/to/test.zip").onComplete(function(library)
{
    var clip = library.getMovieClip("MyMovieClipName");
    // or
    Assets.registerLibrary("my-swf", library);
    var clip = Assets.getMovieClip("my-swf:MyMovieClipName");
});
```


Installation
============

You can easily install SWF using haxelib:

    haxelib install swf

To add it to a Lime or OpenFL project, add this to your project file:

    <haxelib name="swf" />


Development Builds
==================

Clone the SWF repository:

    git clone https://github.com/openfl/swf

Tell haxelib where your development copy of SWF is installed:

    haxelib dev swf swf

Rebuild the SWF library tools:

    ```bash
    openfl rebuild tools
    # or
    cd swf
    haxe rebuild.hxml
    # the HashLink and native builds of the tool as well (see "Running the tool on HashLink")
    haxelib run swf rebuild
    ```

To return to release builds:

    haxelib dev swf
